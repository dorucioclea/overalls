defmodule Marshall.Ingress.Publications do
  @moduledoc "Authenticated, ordered complete DNS publication from one database statement snapshot."
  use Ash.Resource.Actions.Implementation
  alias Marshall.Authorization.SystemActor
  alias Marshall.Compute.Ledger
  alias Marshall.Ingress.{Error, Publication, Services}

  # @cc [owner:ghuntley,label:security;concurrency] ingress-complete-publication-order
  # Only a current DNS credential may request the configured zone. Its shared
  # credential lock MUST remain held through publication. A per-zone transaction
  # lock MUST serialize revision allocation and the complete statement snapshot;
  # failed snapshot construction MUST NOT commit a revision. Counters MUST
  # survive restart; a lost response after commit may leave a revision gap.
  # Publication is discovery only and MUST NOT grant guest access or refresh
  # route/proof lifetimes. No network request may create a new configured zone.
  # Historical per-VM issuance rows MUST NOT publish DNS-01 proofs.
  @impl true
  def run(input, _, %{actor: %SystemActor{purpose: :compute}}) do
    Ledger.transaction(fn -> snapshot!(input.arguments) end) |> Error.result()
  rescue
    _ -> {:error, Error.exception(reason: :unavailable)}
  end

  def run(_, _, _), do: {:error, Ash.Error.Forbidden.exception([])}

  defp snapshot!(%{token: token, zone: zone}) do
    service = Services.authenticate!(token)
    unless service.role == :dns, do: Ledger.rollback(:unauthorized)
    unless configured_zone?(zone), do: Ledger.rollback(:unauthorized)

    # Bound database lock waits and statement execution independently of the
    # caller's HTTP deadline. Restore a caller's settings on the success path.
    %{rows: [[statement_timeout, lock_timeout]]} =
      sql!("SELECT current_setting('statement_timeout'), current_setting('lock_timeout')", [])

    sql!(
      "SELECT set_config('statement_timeout', '1500ms', true), set_config('lock_timeout', '1000ms', true)",
      []
    )

    sql!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", ["audi-publication:" <> zone])

    publication =
      case Ledger.read!(Publication, zone: zone) do
        [] -> Ledger.create!(Publication, :initialize, %{zone: zone})
        [existing] -> existing
      end

    if publication.revision >= 9_223_372_036_854_775_807, do: Ledger.rollback(:capacity)
    # DNS keeps a host's records while it holds authority (live or late), so a
    # few seconds of report delay no longer removes them (ADR-0140).
    freshness = Marshall.Compute.HostLiveness.authority_ms()
    releases = Marshall.Editor.Releases.configured() |> Marshall.Editor.Releases.sql_rows()

    %{rows: rows} =
      sql!(statement(), [freshness, zone, releases])

    if length(rows) > 20_000 or MapSet.size(MapSet.new(rows, &hd/1)) > 10_000,
      do: Ledger.rollback(:capacity)

    {routes, proofs} =
      Enum.reduce(rows, {[], []}, fn
        [_label, nil, nil, nil, nil], acc ->
          acc

        [label, kind, addresses, values, ttl], {routes, proofs} ->
          owner =
            if label == "" and kind == "proof",
              do: "_acme-challenge." <> zone,
              else: "_acme-challenge." <> label <> "." <> zone

          unless ((label == "" and kind == "proof") or
                    (kind == "proof" and
                       OverallsProtocol.InceptionName.wildcard_proof_owner?(label)) or
                    OverallsProtocol.InceptionName.publication?(label) or
                    (kind == "route" and
                       (label == "webview" or Regex.match?(~r/\Aeditor-[a-f0-9]{32}\z/, label)))) and
                   byte_size(owner) <= 253,
                 do: Ledger.rollback(:unavailable)

          if ttl < 1 do
            {routes, proofs}
          else
            case kind do
              "route" ->
                unless addresses?(addresses), do: Ledger.rollback(:unavailable)
                {[%{label: label, addresses: addresses, ttl: ttl} | routes], proofs}

              "proof" ->
                unless proofs?(values), do: Ledger.rollback(:unavailable)
                {routes, [%{label: label, proofs: values, ttl: ttl} | proofs]}
            end
          end
      end)

    next = Ledger.update!(publication, :advance, %{revision: publication.revision + 1})

    sql!(
      "SELECT set_config('statement_timeout', $1, true), set_config('lock_timeout', $2, true)",
      [statement_timeout, lock_timeout]
    )

    %{
      version: 1,
      zone: zone,
      revision: next.revision,
      ttl: 5000,
      routes: Enum.reverse(routes),
      proofs: Enum.reverse(proofs)
    }
  end

  # @cc [owner:ghuntley,label:security;recovery] ingress-publication-statement-consistency
  # All inventory, execution, service, readiness and lifetime facts MUST come
  # from one bounded PostgreSQL statement snapshot and one database clock,
  # normalized to the UTC timestamp storage type independently of session zone. The
  # route predicate MUST remain equivalent to the current-route wake projection,
  # including the active wildcard, exact gateway installation receipt, fresh
  # source/current hosts and explicitly enrolled relay for a previous gateway. Historical
  # per-VM issuance rows MUST NOT become candidates for proof publication.
  # Nested proofs require exact current host/session/VM/environment bindings but
  # may precede completed startup; nested addresses additionally require it.
  # Nested addresses MUST come from enabled parent gateway services, never child
  # payloads. At most 10,000 owners may be published; an overflow sentinel
  # MUST reject the entire snapshot, never publish a truncated catalog.
  # The eligibility result MUST be evaluated once per statement, rather than
  # rescanning the full inventory for each endpoint under stale small-table estimates.
  # Editor owners MUST require a content-bound image matching the approved release
  # for its validated target and live asset receipt under the same snapshot.
  # Every published editor and neutral webview gateway MUST have current receipts
  # for the complete configured release set, since webview DNS cannot select a
  # release-specific destination. Neither record grants access.
  defp statement do
    """
    WITH approved_editor AS MATERIALIZED (
      SELECT target, protocol, commit, release FROM jsonb_to_recordset($3::jsonb)
        AS approved(target text, protocol integer, commit text, release text)
    ), clock AS MATERIALIZED (SELECT clock_timestamp() AT TIME ZONE 'UTC' AS now),
    inventory AS MATERIALIZED (
      SELECT v.id, placement.host_id, v.current_placement_id, v.execution_epoch,
             v.generation, v.desired_state, v.observed_state, v.profile, v.image_id, e.label
      FROM compute_virtual_machines v
      JOIN compute_workload_placements placement ON placement.id = v.current_placement_id
        AND placement.vm_id = v.id
      JOIN ingress_endpoints e ON e.vm_id = v.id
      WHERE v.archived_at IS NULL
      ORDER BY v.id LIMIT 10001
    ), candidates AS (
      SELECT r.vm_id, r.host_id, r.placement_id, r.execution_epoch, r.generation,
             r.service_id, r.service_generation, r.certificate_fingerprint,
             r.certificate_expires_at, 'route'::text AS kind,
             NULL::text[] AS proofs, NULL::text AS proof_label,
             LEAST(r.expires_at, r.certificate_expires_at) AS expires_at
      FROM ingress_routes r
    ), current_publications AS MATERIALIZED (
      SELECT v.id AS vm_id, b.kind, s.id AS service_id, h.connection_session_id AS session_id,
             CASE WHEN b.kind = 'route' THEN s.addresses END AS addresses,
             b.proofs,
             LEAST(5000, FLOOR(EXTRACT(EPOCH FROM (b.expires_at - c.now)) * 1000)::bigint) AS ttl
      FROM candidates b
      JOIN inventory v ON v.id = b.vm_id
      JOIN ingress_services s ON s.id = b.service_id
      JOIN compute_hosts h ON h.id = s.host_id
      CROSS JOIN clock c
      JOIN ingress_fleet_certificates cert ON cert.zone = $2 AND cert.status = 'active'
        AND cert.fingerprint = b.certificate_fingerprint
        AND cert.expires_at = b.certificate_expires_at AND cert.expires_at > c.now
      JOIN ingress_fleet_certificate_installations installation
        ON installation.host_id = s.host_id AND installation.generation = cert.generation
        AND installation.service_id = s.id
        AND installation.service_generation = s.generation
        AND installation.fingerprint = cert.fingerprint
      WHERE s.enabled AND s.role = 'gateway' AND s.generation = b.service_generation
        AND cardinality(s.addresses) > 0 AND s.ssh_host_key IS NOT NULL
        AND h.enabled AND h.maintenance_mode <> 'retired' AND h.connection_session_id IS NOT NULL
        AND h.reported_at <= c.now
        AND h.reported_at >= c.now - ($1::bigint * interval '1 millisecond')
        AND b.host_id = h.id
        AND v.desired_state IN ('running', 'paused')
        AND v.observed_state NOT IN ('deleted', 'failed')
        AND b.expires_at > c.now
        AND EXISTS (
          SELECT 1 FROM compute_hosts current_host
          WHERE current_host.id = v.host_id AND current_host.enabled
            AND current_host.maintenance_mode <> 'retired'
            AND current_host.connection_session_id IS NOT NULL
            AND current_host.reported_at <= c.now
            AND current_host.reported_at >= c.now - ($1::bigint * interval '1 millisecond')
        )
        AND (v.host_id = h.id OR (s.relay_address IS NOT NULL AND EXISTS (
          SELECT 1 FROM ingress_services destination
          WHERE destination.host_id = v.host_id AND destination.enabled
            AND destination.role = 'gateway' AND destination.relay_address IS NOT NULL
        )))
    ), asset_gateways AS MATERIALIZED (
      SELECT s.id AS service_id, h.connection_session_id AS session_id, s.addresses,
             approved.target, approved.protocol, approved.commit, approved.release,
             LEAST(5000, FLOOR(EXTRACT(EPOCH FROM (LEAST(cert.expires_at, a.expires_at) - c.now)) * 1000)::bigint) AS ttl
      FROM ingress_services s
      JOIN compute_hosts h ON h.id = s.host_id
      CROSS JOIN clock c
      JOIN ingress_editor_assets_receipts a ON a.service_id = s.id
        AND a.service_generation = s.generation AND a.host_id = h.id
        AND a.session_id = h.connection_session_id
        AND a.expires_at > c.now
      JOIN approved_editor approved ON a.editor_commit = approved.commit
        AND a.editor_release = approved.release AND a.editor_protocol = approved.protocol
      JOIN ingress_fleet_certificates cert ON cert.zone = $2 AND cert.status = 'active'
        AND cert.expires_at > c.now
      JOIN ingress_fleet_certificate_installations i ON i.host_id = h.id
        AND i.service_id = s.id AND i.service_generation = s.generation
        AND i.generation = cert.generation AND i.fingerprint = cert.fingerprint
      WHERE s.enabled AND s.role = 'gateway' AND cardinality(s.addresses) > 0
        AND s.ssh_host_key IS NOT NULL AND h.enabled AND h.maintenance_mode <> 'retired'
        AND h.connection_session_id IS NOT NULL AND h.reported_at <= c.now
        AND h.reported_at >= c.now - ($1::bigint * interval '1 millisecond')
    ), complete_asset_gateways AS MATERIALIZED (
      SELECT service_id, session_id, addresses, MIN(ttl) AS ttl
      FROM asset_gateways
      GROUP BY service_id, session_id, addresses
      HAVING COUNT(*) = (SELECT COUNT(*) FROM approved_editor)
        AND COUNT(*) > 0
    ), editor_publications AS (
      SELECT 'editor-' || replace(v.id::text, '-', '') AS label, p.addresses, LEAST(p.ttl, a.ttl, complete.ttl) AS ttl
      FROM inventory v
      JOIN current_publications p ON p.vm_id = v.id AND p.kind = 'route'
      JOIN asset_gateways a ON a.service_id = p.service_id AND a.session_id = p.session_id
      JOIN complete_asset_gateways complete ON complete.service_id = a.service_id
        AND complete.session_id = a.session_id
      JOIN compute_images image ON image.id = v.image_id
      WHERE v.profile IN ('customer', 'standard', 'oss')
        AND image.manifest->>'architecture' = 'x86_64'
        AND ((a.target = 'linux-x64' AND image.manifest->>'version' = '4')
          OR (a.target = 'win32-x64' AND image.manifest->>'version' = '7'
            AND image.manifest->>'os' = 'windows'
            AND image.manifest->>'guest_agents' = 'windows-editor-v1'))
        AND image.manifest->'editor'->>'commit' = a.commit
        AND image.manifest->'editor'->>'release' = a.release
        AND image.manifest->'editor'->>'protocol' = a.protocol::text
    ), nested AS (
      SELECT CASE WHEN record->>'label' = 'control'
                  THEN 'control.' || e.label || '.inception'
                  WHEN record->>'label' = ''
                  THEN 'apps.' || e.label || '.inception'
                  ELSE (record->>'label') || '.apps.' || e.label || '.inception' END AS label,
             record, gateway.addresses,
             v.observed_state = 'running' AND EXISTS (
               SELECT 1 FROM compute_operations o WHERE o.vm_id = v.id
                 AND o.placement_id = v.current_placement_id AND o.execution_epoch = v.execution_epoch
                 AND o.generation = v.generation AND o.status = 'completed'
                 AND o.kind IN ('provision', 'start')) AS started,
             LEAST(5000, FLOOR(EXTRACT(EPOCH FROM (p.expires_at - c.now)) * 1000)::bigint) AS ttl
      FROM inventory v
      JOIN ingress_environments e ON e.vm_id = v.id AND e.enabled
      JOIN ingress_environment_publications p ON p.vm_id = v.id
      JOIN compute_hosts h ON h.id = p.host_id
      CROSS JOIN clock c
      CROSS JOIN LATERAL jsonb_array_elements(p.payload->'records') record
      LEFT JOIN LATERAL (
        SELECT array_agg(DISTINCT addr) AS addresses FROM ingress_services s,
          LATERAL unnest(s.addresses) addr
        WHERE s.host_id = h.id AND s.enabled AND s.role = 'gateway' AND s.ssh_host_key IS NOT NULL
      ) gateway ON TRUE
      WHERE v.profile = 'inception' AND v.desired_state = 'running'
        AND v.host_id = h.id AND v.current_placement_id = p.placement_id
        AND v.execution_epoch = p.execution_epoch AND v.generation = p.vm_generation
        AND e.generation = p.environment_generation
        AND h.enabled AND h.maintenance_mode <> 'retired'
        AND h.connection_session_id = p.session_id AND h.connection_epoch = p.host_epoch
        AND h.reported_at <= c.now AND h.reported_at >= c.now - ($1::bigint * interval '1 millisecond')
        AND p.expires_at > c.now
        AND NOT EXISTS (SELECT 1 FROM compute_relocations r
          WHERE r.vm_id = v.id AND r.finished_at IS NULL AND r.committed_at IS NOT NULL)
    ), fleet_proof AS (
      SELECT ''::text AS label, 'proof'::text AS kind,
             NULL::text[] AS addresses, ARRAY[f.dns_proof] AS proofs,
             LEAST(5000, FLOOR(EXTRACT(EPOCH FROM (f.proof_expires_at - c.now)) * 1000)::bigint) AS ttl
      FROM ingress_fleet_certificates f CROSS JOIN clock c
      WHERE f.zone = $2 AND f.status = 'challenging'
        AND f.dns_proof IS NOT NULL AND f.proof_expires_at > c.now
    ), all_publications AS (
      SELECT v.label, p.kind, p.addresses, p.proofs, p.ttl
      FROM inventory v LEFT JOIN current_publications p ON p.vm_id = v.id
      UNION ALL
      SELECT n.label, 'route'::text, n.addresses, NULL::text[], n.ttl
      FROM nested n WHERE n.started AND n.record->>'label' <> ''
        AND cardinality(n.addresses) > 0
        AND (n.record->>'ready')::boolean
      UNION ALL
      SELECT n.label, 'proof'::text, NULL::text[],
             ARRAY(SELECT jsonb_array_elements_text(n.record->'proofs')), n.ttl
      FROM nested n WHERE jsonb_array_length(n.record->'proofs') > 0
      UNION ALL
      SELECT label, kind, addresses, proofs, ttl FROM fleet_proof
      UNION ALL
      SELECT label, 'route'::text, addresses, NULL::text[], ttl FROM editor_publications
      UNION ALL
      SELECT 'webview'::text, 'route'::text, ARRAY(SELECT DISTINCT address
        FROM complete_asset_gateways a, LATERAL unnest(a.addresses) address ORDER BY address LIMIT 8),
        NULL::text[], MIN(ttl) FROM complete_asset_gateways HAVING COUNT(*) > 0
    )
    SELECT label, kind, addresses, proofs, ttl FROM all_publications
    ORDER BY label, kind LIMIT 20001
    """
  end

  defp configured_zone?(zone) do
    zone == Application.get_env(:marshall, :ingress_zone) and is_binary(zone) and
      byte_size(zone) in 1..189 and String.valid?(zone) and
      Enum.all?(
        String.split(zone, "."),
        &Regex.match?(~r/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/, &1)
      )
  end

  defp addresses?(values) do
    is_list(values) and length(values) in 1..8 and Enum.uniq(values) == values and
      Enum.all?(values, fn value ->
        with true <- is_binary(value) and String.valid?(value) and byte_size(value) <= 45,
             {:ok, ip} <- :inet.parse_ipv4strict_address(String.to_charlist(value)),
             do: List.to_string(:inet.ntoa(ip)) == value,
             else: (_ -> false)
      end)
  end

  defp proofs?(values) do
    is_list(values) and length(values) in 1..2 and Enum.uniq(values) == values and
      Enum.all?(values, fn value ->
        with true <- is_binary(value) and byte_size(value) == 43,
             {:ok, bytes} when byte_size(bytes) == 32 <- Base.url_decode64(value, padding: false),
             do: Base.url_encode64(bytes, padding: false) == value,
             else: (_ -> false)
      end)
  end

  defp sql!(statement, params),
    do: Ecto.Adapters.SQL.query!(Marshall.Repo, statement, params, log: false)
end
