defmodule Marshall.Compute.InceptionTest do
  use Marshall.DataCase, async: false
  import Marshall.ComputeFixtures
  alias Marshall.Compute

  alias Marshall.Compute.{
    Host,
    HostReports,
    Ledger,
    NetworkAddress,
    Operation,
    Outcomes,
    Profiles,
    Reservation,
    VirtualMachine
  }

  @gib 1_073_741_824

  setup do
    previous = Application.get_env(:marshall, :inception_image_id)
    Application.put_env(:marshall, :inception_image_id, image_id())
    on_exit(fn -> Application.put_env(:marshall, :inception_image_id, previous) end)
    fixture = host_fixture()
    # Synthetic admission evidence only. Native nested execution is a separate
    # machine check; this fixture cannot boot any VM.
    report = %{
      fixture.report
      | sequence: 2,
        effective_cores: 64,
        effective_memory_bytes: 128 * @gib,
        capacity: capacity(64, 128 * @gib),
        inventory:
          Map.merge(fixture.report.inventory, %{
            "logical_cores" => 64,
            "inception_image_id" => image_id()
          }),
        pools: [
          %{
            hd(fixture.report.pools)
            | total_bytes: 1024 * @gib,
              free_bytes: 1024 * @gib,
              storage: storage_observation(fixture.pool, 1024 * @gib, 1024 * @gib)
          }
        ]
    }

    {:ok, :ok} = HostReports.ingest(fixture.host.id, fixture.epoch, report)
    Map.merge(fixture, %{actor: user(), report: report})
  end

  defp inception(overrides \\ %{}) do
    request(
      Map.merge(
        %{profile: :inception, vcpu: 16, memory_bytes: 32 * @gib, disk_bytes: 64 * @gib},
        overrides
      )
    )
  end

  test "ordinary VM creators can each reserve Inception with distinct addresses and both disks",
       c do
    for actor <- [c.actor, user()] do
      assert {:ok, vm} = Compute.provision(inception(), actor: actor)
      assert vm.profile == :inception
      assert [hold] = Ledger.read!(Reservation, vm_id: vm.id)
      assert hold.disk_bytes == 321 * @gib
      assert hold.memory_bytes == 32 * @gib + 67_108_864
    end

    assert Enum.map(Ledger.read!(NetworkAddress), &{&1.profile, &1.slot}) |> Enum.sort() ==
             [{:inception, 2}, {:inception, 3}]
  end

  test "environment identity is audited, immutable and never re-enabled by initialization", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)
    alias Marshall.Ingress.{Endpoint, Endpoints, Environment}
    assert [environment] = Ledger.read!(Environment, vm_id: vm.id)
    assert [endpoint] = Ledger.read!(Endpoint, vm_id: vm.id)
    assert environment.label == endpoint.label

    assert {:ok, %{profile: :inception, label: profile_label}} =
             Marshall.Ingress.get_ssh_endpoint(%{vm_id: vm.id}, actor: c.actor)

    assert profile_label == environment.label
    assert [_] = Ledger.read!(Environment.Version, version_source_id: environment.id)

    assert {:error, _} =
             environment
             |> Ash.Changeset.for_update(:change_policy, %{enabled: false, generation: 2},
               actor: c.actor
             )
             |> Ash.update()

    assert {:ok, :ok} =
             Ledger.transaction(fn ->
               locked = Ledger.lock!(VirtualMachine, vm.id)
               Ledger.update!(environment, :change_policy, %{enabled: false, generation: 2})
               Endpoints.ensure!(%{locked | name: "renamed"})
               :ok
             end)

    assert [%{id: id, label: label, enabled: false, generation: 2}] =
             Ledger.read!(Environment, vm_id: vm.id)

    assert id == environment.id and label == environment.label
    assert length(Ledger.read!(Environment.Version, version_source_id: id)) == 2
  end

  test "publication offers bind execution and cannot be replayed or refreshed after expiry", c do
    previous_public = Application.get_env(:marshall, :inception_public)
    old_url = :persistent_term.get({Phoenix.Endpoint, MarshallWeb.Endpoint})

    :persistent_term.put({Phoenix.Endpoint, MarshallWeb.Endpoint}, %{
      old_url
      | url: "https://parent.example"
    })

    on_exit(fn -> :persistent_term.put({Phoenix.Endpoint, MarshallWeb.Endpoint}, old_url) end)

    settings = %{
      "issuer" => "https://ca.example/directory",
      "accept_terms" => true,
      "nameservers" => [
        %{"name" => "ns1.example", "address" => "192.0.2.53", "port" => 53},
        %{"name" => "ns2.example", "address" => "198.51.100.53", "port" => 53}
      ],
      "mailbox" => "hostmaster.example",
      "issuer_ca_pem" => nil,
      "trust_pem" => nil
    }

    Application.put_env(:marshall, :inception_public, settings)
    on_exit(fn -> Application.put_env(:marshall, :inception_public, previous_public) end)
    alias Marshall.Compute.{Credentials, ProvisionerControl}
    alias Marshall.Ingress.{Environment, EnvironmentPublication, EnvironmentPublications}
    previous = Application.get_env(:marshall, :ingress_zone)
    Application.put_env(:marshall, :ingress_zone, "apps.example")
    on_exit(fn -> Application.put_env(:marshall, :ingress_zone, previous) end)
    {:ok, credential} = Credentials.rotate(c.host.id, 3600)
    session = Ash.UUID.generate()

    {:ok, opened} =
      ProvisionerControl.open_execution(
        credential.token,
        %{session_id: session, machine_id: c.host.machine_id}
      )

    {:ok, :ok} = HostReports.ingest(c.host.id, opened["epoch"], c.report)
    {:ok, vm} = Compute.provision(inception(), actor: c.actor)

    message = %{
      session_id: session,
      epoch: opened["epoch"],
      vm_id: vm.id,
      placement_id: vm.current_placement_id,
      execution_epoch: vm.execution_epoch,
      generation: vm.generation,
      result: nil
    }

    tls = Path.expand("../../fixtures/tls", __DIR__)

    server =
      start_supervised!(
        {Bandit,
         plug: MarshallWeb.FleetEndpoint,
         scheme: :https,
         ip: {127, 0, 0, 1},
         port: 0,
         startup_log: false,
         certfile: Path.join(tls, "localhost.pem"),
         keyfile: Path.join(tls, "localhost.key")}
      )

    {:ok, {_, port}} = ThousandIsland.listener_info(server)

    {:ok, client} =
      Lilly.Control.Client.new("https://127.0.0.1:#{port}", c.host.id, credential.token,
        machine_id: c.host.machine_id,
        cacertfile: Path.join(tls, "ca.pem")
      )

    client = Marshall.LillyControl.connect(client)

    assert {:ok, client_offer} =
             Lilly.Control.Client.exchange_inception(
               client,
               %{session_id: session, epoch: opened["epoch"]},
               message,
               nil
             )

    assert client_offer.public == settings
    assert client_offer.parent["origin"] == "https://parent.example"
    assert client_offer.deadline > System.monotonic_time(:millisecond)
    offer = Map.new(client_offer, fn {key, value} -> {Atom.to_string(key), value} end)
    [before] = Ledger.read!(EnvironmentPublication, vm_id: vm.id)

    publication = %{
      "version" => 1,
      "binding" => %{
        "placement_id" => vm.current_placement_id,
        "execution_epoch" => vm.execution_epoch,
        "boot_challenge" => String.duplicate("a", 64)
      },
      "request_id" => Ash.UUID.generate(),
      "generation" => offer["environment_generation"],
      "ttl_ms" => 4500,
      "porsche_host_key" => nil,
      "audi_host_key" => nil,
      "records" => [
        %{
          "label" => "control",
          "ready" => false,
          "proofs" => [Base.url_encode64(<<0::256>>, padding: false)]
        }
      ]
    }

    result = %{offer_id: offer["offer_id"], publication: publication}

    assert {:ok, next_offer} =
             Lilly.Control.Client.exchange_inception(
               client,
               %{session_id: session, epoch: opened["epoch"]},
               message,
               %{"offer_id" => result.offer_id, "publication" => result.publication}
             )

    next = Map.new(next_offer, fn {key, value} -> {Atom.to_string(key), value} end)

    [accepted] = Ledger.read!(EnvironmentPublication, vm_id: vm.id)
    assert accepted.payload == publication
    assert accepted.expires_at == DateTime.add(before.offer_expires_at, -500, :millisecond)

    # A second child poll may become ready after the parent replicas have
    # answered the first proof. The refreshed offer must commit that final
    # publication instead of leaving Marshall with the bootstrap payload.
    final_publication = put_in(publication, ["records", Access.at(0), "ready"], true)
    vm_id = vm.id
    :ok = Marshall.Control.Hints.subscribe(:dns_snapshot, vm_id)

    assert {:ok, final_offer} =
             Lilly.Control.Client.exchange_inception(
               client,
               %{session_id: session, epoch: opened["epoch"]},
               message,
               %{"offer_id" => next["offer_id"], "publication" => final_publication}
             )

    final = Map.new(final_offer, fn {key, value} -> {Atom.to_string(key), value} end)
    assert_receive {:control_hint, :dns_snapshot, ^vm_id}, 5_000

    [accepted] = Ledger.read!(EnvironmentPublication, vm_id: vm.id)
    assert accepted.payload == final_publication
    assert DateTime.compare(accepted.expires_at, DateTime.utc_now()) == :gt

    # The public snapshot uses parent-owned addresses and admits bootstrap proofs
    # before the outer provision operation has completed.
    alias Marshall.Ingress
    actor = Marshall.Authorization.SystemActor.compute()
    {dns_token, _} = Ingress.Token.issue()
    {gateway_token, _} = Ingress.Token.issue()

    {:ok, _} =
      Ingress.configure_service(%{name: "nested-dns", role: :dns, token: dns_token}, actor: actor)

    {:ok, _} =
      Ingress.configure_service(
        %{
          name: "nested-gateway",
          role: :gateway,
          host_id: c.host.id,
          addresses: ["192.0.2.37"],
          token: gateway_token
        },
        actor: actor
      )

    {public, _} = :crypto.generate_key(:eddsa, :ed25519)
    key = "ssh-ed25519 " <> Base.encode64(<<11::32, "ssh-ed25519", 32::32, public::binary>>)
    {:ok, _} = Ingress.publish_host_key(%{token: gateway_token, public_key: key}, actor: actor)

    snapshot = fn ->
      Ingress.dns_snapshot(%{token: dns_token, zone: "apps.example"}, actor: actor)
    end

    label = "control.#{offer["label"]}.inception"
    assert {:ok, %{routes: [], proofs: [%{label: ^label}]}} = snapshot.()

    apex = "apps.#{offer["label"]}.inception"

    wildcard_record = %{
      "label" => "",
      "ready" => false,
      "proofs" => [Base.url_encode64(<<1::256>>, padding: false)]
    }

    wildcard_payload = update_in(publication, ["records"], &(&1 ++ [wildcard_record]))
    assert {:ok, _} = OverallsProtocol.InceptionExchange.encode(wildcard_payload)
    accepted = Ledger.update!(accepted, :advance, %{payload: wildcard_payload})
    assert {:ok, %{routes: [], proofs: proofs}} = snapshot.()
    assert Enum.any?(proofs, &(&1.label == apex))
    started = System.monotonic_time(:millisecond)
    assert {:ok, projected} = snapshot.()

    assert {:ok, decoded} =
             projected
             |> JSON.encode!()
             |> JSON.decode!()
             |> Audi.DNS.Snapshot.decode("apps.example", started)

    assert %{challenges: [_]} =
             decoded.entries["_acme-challenge." <> apex <> ".apps.example"]

    refute Map.has_key?(decoded.entries, apex <> ".apps.example")
    accepted = Ledger.update!(accepted, :advance, %{payload: publication})

    ready_payload = put_in(publication, ["records", Access.at(0), "ready"], true)
    accepted = Ledger.update!(accepted, :advance, %{payload: ready_payload})
    assert {:ok, %{routes: [], proofs: [_]}} = snapshot.()
    [operation] = Ledger.read!(Operation, vm_id: vm.id)
    assert {:ok, _} = ingest(vm, operation, 1, :running)

    assert {:ok, %{routes: [%{label: ^label, addresses: ["192.0.2.37"]}], proofs: [_]}} =
             snapshot.()

    authority_binding = %{
      vm_id: vm.id,
      placement_id: vm.current_placement_id,
      execution_epoch: vm.execution_epoch,
      generation: vm.generation,
      label: offer["label"],
      environment_generation: offer["environment_generation"]
    }

    authority = fn kind ->
      Ledger.transaction(fn ->
        service = Ingress.Services.authenticate!(gateway_token, :exclusive)
        binding = Map.put(authority_binding, :service_generation, service.generation)
        Ingress.EnvironmentAuthority.current!(service, binding, kind)
      end)
    end

    assert {:ok, %{ttl: ttl, host_key: nil, host_session_id: ^session}} =
             authority.(:control_https)

    assert ttl in 1..5000
    assert {:error, _} = authority.(:audi_https)
    assert {:error, _} = authority.(:porsche_ssh)
    assert {:error, _} = authority.(:audi_ssh)

    keys_payload =
      ready_payload |> Map.put("porsche_host_key", key) |> Map.put("audi_host_key", key)

    Ledger.update!(accepted, :advance, %{payload: keys_payload})

    for kind <- [:porsche_ssh, :audi_ssh] do
      assert {:ok, %{host_key: ^key}} = authority.(kind)
      ssh_request = %{service_token: gateway_token, label: offer["label"], nested_service: kind}
      assert {:error, _} = Ingress.open_nested(ssh_request, actor: actor)

      assert {:ok, ssh_grant} =
               Ingress.open_nested(Map.put(ssh_request, :public_key, key), actor: actor)

      assert ssh_grant.host_key == key
      assert OverallsProtocol.IngressConnect.valid?(ssh_grant.binding)

      assert {:ok, %{closed: true}} =
               Ingress.close_nested(
                 %{service_token: gateway_token, stream_token: ssh_grant.ticket},
                 actor: actor
               )
    end

    Ledger.update!(accepted, :advance, %{payload: publication})
    assert {:error, _} = authority.(:control_https)
    Ledger.update!(accepted, :advance, %{payload: ready_payload})

    nested_server =
      start_supervised!(
        {Bandit,
         plug: Marshall.AudiControl.FleetPlug,
         scheme: :https,
         ip: {127, 0, 0, 1},
         port: 0,
         startup_log: false,
         certfile: Path.join(tls, "localhost.pem"),
         keyfile: Path.join(tls, "localhost.key")},
        id: :nested_api
      )

    {:ok, {_, nested_port}} = ThousandIsland.listener_info(nested_server)

    {:ok, gateway_client} =
      Audi.Control.Client.new("https://127.0.0.1:#{nested_port}", gateway_token, :gateway,
        host_id: c.host.id,
        cacertfile: Path.join(tls, "ca.pem")
      )

    gateway_client = Marshall.AudiControl.connect(gateway_client)

    Ledger.update!(accepted, :advance, %{payload: keys_payload})
    discovery_request = %{label: offer["label"], nested_service: :audi_ssh}
    assert {:error, _} = Ingress.current_nested_ssh(discovery_request, actor: c.actor)

    assert {:ok, %{host_key: ^key, gateway_keys: [^key]}} =
             Ingress.current_nested_ssh(discovery_request, actor: actor)

    for service <- ["porsche", "audi"], layer <- ["gateway", "inner"] do
      response =
        Req.get!(
          "https://127.0.0.1:#{nested_port}/api/audi/v1/inception-known-hosts/#{offer["label"]}/#{service}/#{layer}",
          retry: false,
          connect_options: [
            transport_opts: [verify: :verify_peer, cacertfile: Path.join(tls, "ca.pem")]
          ]
        )

      host =
        if(layer == "gateway", do: "gateway", else: service) <>
          "." <> offer["label"] <> ".inception.apps.example"

      assert response.status == 200
      assert response.body == host <> " " <> key <> "\n"
      assert response.headers["cache-control"] == ["no-store"]
    end

    {:ok, proved_key} = OverallsProtocol.SSHKey.parse(key)

    for service <- [:porsche_ssh, :audi_ssh] do
      selector = {:nested, offer["label"], service}
      backend = %{client: gateway_client}
      assert {:ok, ssh_grant} = Audi.SSH.ControlBackend.authorize(backend, proved_key, selector)
      assert Audi.SSH.Request.grant?(ssh_grant, selector, c.host.id)
      assert {:nested, token, ^key} = ssh_grant.ticket

      assert {:ok, renewal} =
               Audi.SSH.ControlBackend.renew(backend, ssh_grant.ticket, ssh_grant.binding)

      assert Audi.SSH.Request.authority_binding(renewal) ==
               Audi.SSH.Request.authority_binding(ssh_grant)

      Ledger.update!(accepted, :advance, %{payload: ready_payload})

      assert {:error, _} =
               Audi.SSH.ControlBackend.renew(backend, ssh_grant.ticket, ssh_grant.binding)

      assert {:ok, %{closed: true}} = Audi.Control.Client.close_nested(gateway_client, token)
      Ledger.update!(accepted, :advance, %{payload: keys_payload})
    end

    Ledger.update!(accepted, :advance, %{payload: ready_payload})

    assert {:ok, remote_grant} =
             Audi.Control.Client.open_nested(gateway_client, offer["label"], :control_https)

    assert remote_grant.expires_at > System.monotonic_time(:millisecond)

    assert {:ok, remote_renewal} =
             Audi.Control.Client.renew_nested(gateway_client, remote_grant.ticket, remote_grant)

    assert remote_renewal.binding == remote_grant.binding

    assert {:ok, %{closed: true}} =
             Audi.Control.Client.close_nested(gateway_client, remote_grant.ticket)

    assert {:error, _} =
             Audi.Control.Client.renew_nested(gateway_client, remote_grant.ticket, remote_grant)

    stream_request = %{
      service_token: gateway_token,
      label: offer["label"],
      nested_service: :control_https
    }

    assert {:error, _} = Ingress.open_nested(stream_request, actor: c.actor)

    assert {:error, _} =
             Ingress.open_nested(Map.put(stream_request, :public_key, key), actor: actor)

    assert {:ok, grant} = Ingress.open_nested(stream_request, actor: actor)
    assert OverallsProtocol.IngressConnect.valid_for_profile?(grant.binding, :inception)
    assert grant.ttl in 1..5000
    renew_request = %{service_token: gateway_token, stream_token: grant.ticket}
    assert {:ok, renewed} = Ingress.renew_nested(renew_request, actor: actor)
    assert renewed.binding == grant.binding
    assert {:error, _} = Ingress.renew_web(renew_request, actor: actor)
    assert {:ok, %{closed: true}} = Ingress.close_nested(renew_request, actor: actor)
    assert {:error, _} = Ingress.renew_nested(renew_request, actor: actor)
    assert {:ok, expired_grant} = Ingress.open_nested(stream_request, actor: actor)
    [expired_row] = Ledger.read!(Ingress.EnvironmentStream, id: expired_grant.binding.session_id)
    Ledger.update!(expired_row, :renew, %{expires_at: DateTime.add(Ledger.now(), -1)})

    assert {:error, _} =
             Ingress.renew_nested(%{renew_request | stream_token: expired_grant.ticket},
               actor: actor
             )

    assert {:ok, live_grant} = Ingress.open_nested(stream_request, actor: actor)
    live_request = %{renew_request | stream_token: live_grant.ticket}

    [audit] =
      Ledger.read!(Ingress.EnvironmentStream.Version,
        version_source_id: live_grant.binding.session_id
      )

    refute inspect(audit.changes) =~ "token_hash"

    started = System.monotonic_time(:millisecond)
    assert {:ok, publication_snapshot} = snapshot.()
    wire = publication_snapshot |> JSON.encode!() |> JSON.decode!()
    assert {:ok, decoded} = Audi.DNS.Snapshot.decode(wire, "apps.example", started)
    assert %{addresses: [{192, 0, 2, 37}]} = decoded.entries[label <> ".apps.example"]
    assert %{challenges: [_]} = decoded.entries["_acme-challenge." <> label <> ".apps.example"]

    Ledger.update!(accepted, :advance, %{payload: keys_payload})
    assert {:ok, _} = Ingress.current_nested_ssh(discovery_request, actor: actor)

    for {field, invalid} <- [
          host_id: Ash.UUID.generate(),
          placement_id: Ash.UUID.generate(),
          session_id: Ash.UUID.generate(),
          execution_epoch: accepted.execution_epoch + 1,
          vm_generation: accepted.vm_generation + 1,
          host_epoch: accepted.host_epoch + 1,
          environment_generation: accepted.environment_generation + 1,
          expires_at: DateTime.add(Ledger.now(), -1)
        ] do
      Ledger.update!(accepted, :advance, %{field => invalid})
      assert {:ok, %{routes: [], proofs: []}} = snapshot.()
      assert {:error, _} = authority.(:control_https)
      assert {:error, _} = Ingress.current_nested_ssh(discovery_request, actor: actor)
      assert {:error, _} = Ingress.renew_nested(live_request, actor: actor)
      Ledger.update!(accepted, :advance, %{field => Map.fetch!(accepted, field)})
    end

    assert {:error, _} =
             EnvironmentPublications.exchange(credential.token, %{message | result: result})

    # A positive child TTL cannot restart lifetime at receipt. This offer began
    # one second ago; a 500ms child remainder measured from that start is stale.
    Ledger.update!(accepted, :advance, %{
      offer_expires_at: DateTime.add(Ledger.now(), 4, :second)
    })

    assert {:error, _} =
             EnvironmentPublications.exchange(credential.token, %{
               message
               | result: %{
                   offer_id: final["offer_id"],
                   publication: Map.put(publication, "ttl_ms", 500)
                 }
             })

    Ledger.update!(accepted, :advance, %{
      offer_expires_at: DateTime.add(Ledger.now(), -1, :second)
    })

    assert {:error, _} =
             EnvironmentPublications.exchange(
               credential.token,
               %{message | result: %{result | offer_id: final["offer_id"]}}
             )

    assert {:error, _} =
             EnvironmentPublications.exchange(
               credential.token,
               %{message | execution_epoch: vm.execution_epoch + 1}
             )

    assert {:error, _} =
             EnvironmentPublications.exchange(
               credential.token,
               %{message | session_id: Ash.UUID.generate()}
             )

    [environment] = Ledger.read!(Environment, vm_id: vm.id)
    Ledger.update!(environment, :change_policy, %{enabled: false, generation: 2})
    assert {:error, _} = EnvironmentPublications.exchange(credential.token, message)
    assert {:error, _} = authority.(:control_https)
    assert {:error, _} = Ingress.renew_nested(live_request, actor: actor)
    assert {:error, _} = Ingress.current_nested_ssh(discovery_request, actor: actor)
  end

  test "multi-disk cloning queues the two-disk workload without host effects", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)

    assert {:ok, request} =
             Compute.clone(%{vm_id: vm.id, idempotency_key: "inception-clone"}, actor: c.actor)

    assert {:ok, replay} =
             Compute.clone(%{vm_id: vm.id, idempotency_key: "inception-clone"}, actor: c.actor)

    assert replay.id == request.id
    assert request.source_vm_id == vm.id
    assert request.phase == :queued
    assert [stored] = Ledger.read!(Marshall.Compute.CloneRequest)
    assert stored.source_vm_id == vm.id and stored.destination_vm_id == request.destination_vm_id

    # Queue admission reserves no capacity and interrupts nothing; activation
    # later holds the full two-disk footprint.
    assert Ledger.read!(Marshall.Compute.TransferSlot) == []
    assert [%{kind: :provision}] = Ledger.read!(Operation, vm_id: vm.id)
    assert [%{temporary_disk_bytes: 0}] = Ledger.read!(Reservation, vm_id: vm.id)
  end

  test "ordinary execution readiness and image availability do not establish nesting", c do
    for capability <- [nil, "sha256:" <> String.duplicate("b", 64), true] do
      Ledger.update!(c.host, :report, %{
        inventory: Map.put(c.report.inventory, "inception_image_id", capability)
      })

      assert {:error, error} = Compute.provision(inception(), actor: c.actor)
      assert Exception.message(error) =~ "insufficient_capacity"
    end

    assert Ledger.read!(Reservation) == []
    assert Ledger.read!(NetworkAddress) == []
    assert Ledger.read!(Operation) == []
  end

  test "missing configuration, mismatched images and undersized service budgets fail atomically",
       c do
    Application.delete_env(:marshall, :inception_image_id)
    assert {:error, error} = Compute.provision(inception(), actor: c.actor)
    assert Exception.message(error) =~ "inception_unavailable"
    Application.put_env(:marshall, :inception_image_id, image_id())

    for params <- [request(), inception(%{image_id: "sha256:" <> String.duplicate("b", 64)})] do
      assert {:error, error} = Compute.provision(params, actor: c.actor)
      assert Exception.message(error) =~ "profile_image_mismatch"
    end

    for changes <- [%{vcpu: 15}, %{memory_bytes: 31 * @gib}, %{disk_bytes: 63 * @gib}] do
      assert {:error, error} = Compute.provision(inception(changes), actor: c.actor)
      assert Exception.message(error) =~ "image_requirements_not_met"
    end

    assert Ledger.read!(Reservation) == []
    assert Ledger.read!(NetworkAddress) == []
  end

  test "root growth retains the fixed data reservation", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)
    [provision] = Ledger.read!(Operation, vm_id: vm.id)
    assert {:ok, _} = ingest(vm, provision, 1, :running)

    args = %{
      vm_id: vm.id,
      expected_generation: 1,
      idempotency_key: "grow-root",
      vcpu: 16,
      memory_bytes: 32 * @gib,
      disk_bytes: 65 * @gib
    }

    assert {:error, error} = Compute.resize(%{args | vcpu: 15}, actor: c.actor)
    assert Exception.message(error) =~ "image_requirements_not_met"
    assert {:ok, resize} = Compute.resize(args, actor: c.actor)
    [hold] = Ledger.read!(Reservation, vm_id: vm.id)
    assert hold.disk_bytes == 321 * @gib
    assert hold.pending_disk_bytes == @gib
    stop = operation(vm)
    assert {:ok, _} = ingest(vm, stop, 2, :stopped)
    apply = operation(vm)
    assert apply.kind == :resize
    assert {:ok, _} = ingest(vm, apply, 3, :stopped, %{applied_sizes: resize.target_sizes})
    [hold] = Ledger.read!(Reservation, vm_id: vm.id)
    assert hold.disk_bytes == 322 * @gib
    assert hold.pending_disk_bytes == 0
  end

  test "relocation admits a running two-disk workload and holds the full footprint", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)
    [provision] = Ledger.read!(Operation, vm_id: vm.id)
    assert {:ok, _} = ingest(vm, provision, 1, :running)

    destination = destination_host()

    assert {:ok, relocation} =
             Compute.relocate(%{vm_id: vm.id, idempotency_key: "move-inception"}, actor: c.actor)

    assert relocation.destination_host_id == destination.host.id

    # The destination holds both drives (64 + 256 GiB) and the portable 1 GiB
    # boot bundle, not the root alone; the stopped copy needs no temporary hold.
    holds = Ledger.read!(Reservation, vm_id: vm.id)
    assert length(holds) == 2

    for reservation <- holds do
      assert reservation.disk_bytes == 321 * @gib
      assert reservation.temporary_disk_bytes == 0
      assert reservation.disk_held
    end

    assert length(Ledger.read!(Marshall.Compute.WorkloadPlacement, vm_id: vm.id)) == 2
    assert length(Ledger.read!(Marshall.Compute.TransferSlot)) == 2
  end

  test "a two-disk workload needs exactly one full footprint at the destination", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)
    [provision] = Ledger.read!(Operation, vm_id: vm.id)
    assert {:ok, _} = ingest(vm, provision, 1, :running)

    destination = destination_host()

    # One byte short of the 321 GiB portable footprint refuses the move ...
    Ledger.update!(destination.pool, :report, %{
      free_bytes: destination.pool.overhead_bytes + 321 * @gib - 1,
      reported_at: Ledger.now()
    })

    assert {:error, error} =
             Compute.relocate(%{vm_id: vm.id, idempotency_key: "move-short"}, actor: c.actor)

    assert Exception.message(error) =~ "insufficient_capacity"

    # ... while exactly one complete copy fits (no second-copy headroom, ADR-0155).
    Ledger.update!(destination.pool, :report, %{
      free_bytes: destination.pool.overhead_bytes + 321 * @gib,
      reported_at: Ledger.now()
    })

    assert {:ok, relocation} =
             Compute.relocate(%{vm_id: vm.id, idempotency_key: "move-stopped"}, actor: c.actor)

    assert relocation.destination_host_id == destination.host.id

    assert Enum.all?(
             Ledger.read!(Reservation, vm_id: vm.id),
             &(&1.temporary_disk_bytes == 0 and &1.disk_held)
           )
  end

  test "relocation destination requires the native inception proof", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)
    [provision] = Ledger.read!(Operation, vm_id: vm.id)
    assert {:ok, _} = ingest(vm, provision, 1, :running)

    destination = destination_host()

    Ledger.update!(destination.host, :report, %{
      inventory: Map.delete(destination.report.inventory, "inception_image_id")
    })

    assert {:error, error} =
             Compute.relocate(%{vm_id: vm.id, idempotency_key: "no-proof"}, actor: c.actor)

    assert Exception.message(error) =~ "insufficient_capacity"
    assert Ledger.read!(Marshall.Compute.Relocation, vm_id: vm.id) == []
    assert Ledger.read!(Marshall.Compute.TransferSlot) == []
  end

  test "evacuation schedules a two-disk workload like any other", c do
    assert {:ok, vm} = Compute.provision(inception(), actor: c.actor)
    [provision] = Ledger.read!(Operation, vm_id: vm.id)
    assert {:ok, _} = ingest(vm, provision, 1, :running)

    destination = destination_host()

    admin =
      Ledger.update!(user(), :assign_administrator, %{administrator: true})
      |> Marshall.PasskeyFixture.verified_session()

    {:ok, campaign} =
      Compute.request_evacuation(
        %{host_id: c.host.id, request_id: Ash.UUID.generate()},
        actor: admin
      )

    # Running guests need explicit downtime approval before any move is reserved.
    assert {:ok, :blocked} = Marshall.Compute.Evacuations.advance(campaign.id)

    for item <- Ledger.read!(Marshall.Compute.EvacuationItem, evacuation_id: campaign.id) do
      assert {:ok, _} =
               Compute.approve_evacuation_downtime(
                 %{id: campaign.id, item_id: item.id, expected_key: item.request_key},
                 actor: admin
               )
    end

    assert {:ok, :scheduled} = Marshall.Compute.Evacuations.advance(campaign.id)

    [relocation] = Ledger.read!(Marshall.Compute.Relocation, evacuation_id: campaign.id)
    assert relocation.destination_host_id == destination.host.id

    for reservation <- Ledger.read!(Reservation, vm_id: vm.id) do
      assert reservation.temporary_disk_bytes == 0
    end
  end

  test "defaults cover the embedded services and a larger image's requirements" do
    assert Profiles.default_shape(:inception, image_fixture()) ==
             %{vcpu: 16, memory_bytes: 32 * @gib, disk_bytes: 64 * @gib}

    assert Profiles.default_shape("inception", %{
             minimum_memory_bytes: 40 * @gib,
             minimum_disk_bytes: 80 * @gib
           }) ==
             %{vcpu: 16, memory_bytes: 40 * @gib, disk_bytes: 80 * @gib}
  end

  defp destination_host do
    destination = host_fixture()

    report = %{
      destination.report
      | sequence: 2,
        effective_cores: 64,
        effective_memory_bytes: 128 * @gib,
        capacity: capacity(64, 128 * @gib),
        inventory:
          Map.merge(destination.report.inventory, %{
            "logical_cores" => 64,
            "inception_image_id" => image_id()
          }),
        pools: [
          %{
            hd(destination.report.pools)
            | total_bytes: 1024 * @gib,
              free_bytes: 1024 * @gib,
              storage: storage_observation(destination.pool, 1024 * @gib, 1024 * @gib)
          }
        ]
    }

    {:ok, :ok} = HostReports.ingest(destination.host.id, destination.epoch, report)
    destination
  end

  defp operation(vm) do
    [current] = Ledger.read!(VirtualMachine, id: vm.id)
    hd(Ledger.read!(Operation, vm_id: vm.id, generation: current.generation))
  end

  defp ingest(vm, operation, sequence, state, extra \\ %{}) do
    event =
      Map.merge(
        %{
          id: Ash.UUID.generate(),
          vm_id: vm.id,
          placement_id: operation.placement_id,
          execution_epoch: operation.execution_epoch,
          operation_id: operation.id,
          generation: operation.generation,
          sequence: sequence,
          state: state,
          compute_empty: state != :running,
          disk_present: true,
          cleanup_complete: false,
          reason: :none
        },
        extra
      )

    {:ok, event} =
      OverallsProtocol.Execution.outcome(OverallsProtocol.Execution.encode_outcome(event))

    Ledger.transaction(fn ->
      Ledger.lock!(Host, vm.host_id)
      Outcomes.ingest_locked!(vm.host_id, [event])
    end)
  end
end
