defmodule Marshall.Inference.Credentials do
  @moduledoc "Trusted deployment enrollment/rotation and fresh inference-only request authority."
  alias Marshall.Compute.Ledger
  alias Marshall.Compute.Host
  alias Marshall.Inference.{Credential, IssuedCredential}
  require Marshall.Events
  @maximum_lifetime 5 * 365 * 86_400

  # @cc [owner:ghuntley,label:security] ziggy-credential-domain-isolation
  # Rotation MUST serialize on the inference host, revoke prior inference credentials
  # and issue one random 256-bit secret. Persist only its digest and omit it from
  # audit. It MUST NOT touch compute credentials, sessions, reports or reservations.
  @spec rotate(String.t(), pos_integer()) :: {:ok, IssuedCredential.t()} | {:error, term()}
  def rotate(host_id, ttl) when is_integer(ttl) and ttl > 0 and ttl <= @maximum_lifetime do
    Ledger.transaction(
      fn ->
        host = Ledger.fence_host!(host_id) || Ledger.rollback(:unknown_inference_host)
        unless host.enabled, do: Ledger.rollback(:inference_disabled)
        revoke_locked!(host.id)
        secret = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        expiry = DateTime.add(Ledger.now(), ttl)

        credential =
          Ledger.create!(Credential, :issue, %{
            host_id: host.id,
            secret_hash: :crypto.hash(:sha256, secret),
            expires_at: expiry
          })

        %IssuedCredential{id: credential.id, host_id: host.id, secret: secret, expires_at: expiry}
      end,
      :operator
    )
    |> case do
      {:ok, credential} ->
        unless Marshall.Repo.in_transaction?(),
          do:
            Marshall.Events.emit("inference.credential_rotated",
              host_id: credential.host_id,
              credential_id: credential.id
            )

        {:ok, credential}

      error ->
        error
    end
  end

  def rotate(_, _), do: {:error, :invalid_lifetime}

  # @cc [owner:ghuntley,label:security;recovery] ziggy-bootstrap-preserves-authority
  # Trusted bootstrap MUST persist its random token before calling ensure/3.
  # Under the host lock, an exact active credential MUST retain its original
  # expiry. Missing local custody, another credential, disabled hosts, expiry
  # and revocation MUST NOT cause rotation or resurrection. Only a host without
  # any inference credential history may acquire new bootstrap authority.
  # This coordinator MUST NOT be exposed as a remote or ordinary-user action.
  @spec ensure(String.t(), String.t(), pos_integer()) :: {:ok, map()} | {:error, term()}
  def ensure(host_id, token, ttl) when is_integer(ttl) and ttl > 0 and ttl <= @maximum_lifetime do
    with true <- OverallsProtocol.uuid?(host_id),
         {:ok, id, secret} <- parse(token) do
      Ledger.transaction(
        fn ->
          host = Ledger.fence_host!(host_id) || Ledger.rollback(:unknown_inference_host)
          unless host.enabled, do: Ledger.rollback(:inference_disabled)
          now = Ledger.now()
          digest = :crypto.hash(:sha256, secret)

          credential =
            case Ledger.read!(Credential, id: id) do
              [existing] ->
                unless existing.host_id == host.id and active?(existing, host, now) and
                         Plug.Crypto.secure_compare(existing.secret_hash, digest),
                       do: Ledger.rollback(:inference_bootstrap_conflict)

                existing

              [] ->
                unless Ledger.read!(Credential, host_id: host.id) == [],
                  do: Ledger.rollback(:inference_bootstrap_conflict)

                Ledger.create!(Credential, :ensure, %{
                  id: id,
                  host_id: host.id,
                  secret_hash: digest,
                  expires_at: DateTime.add(now, ttl)
                })
            end

          %{credential_id: credential.id, host_id: host.id, expires_at: credential.expires_at}
        end,
        :operator
      )
    else
      _ -> {:error, :invalid_inference_bootstrap}
    end
  end

  def ensure(_, _, _), do: {:error, :invalid_inference_bootstrap}

  @spec revoke(String.t()) :: {:ok, :ok} | {:error, term()}
  def revoke(host_id) do
    Ledger.transaction(
      fn ->
        host = Ledger.fence_host!(host_id) || Ledger.rollback(:unknown_inference_host)
        revoke_locked!(host.id)
      end,
      :operator
    )
    |> case do
      {:ok, revoked} ->
        unless Marshall.Repo.in_transaction?(),
          do:
            Enum.each(revoked, fn credential ->
              Marshall.Events.emit("inference.credential_revoked",
                host_id: host_id,
                credential_id: credential.id
              )
            end)

        {:ok, :ok}

      error ->
        error
    end
  end

  # @cc [owner:ghuntley,label:security] ziggy-current-credential-check
  # Authentication MUST check database-clock expiry, enabled physical host and
  # current revocation after locking that host. Return only host/credential IDs
  # and database time, never a secret or digest. Persistence MUST recheck the
  # credential under the same host lock before committing queued observations.
  @spec authenticate(term()) :: {:ok, map()} | {:error, term()}
  def authenticate(token) do
    with {:ok, id, secret} <- parse(token) do
      Ledger.transaction(fn -> authenticate_locked!(id, secret) |> Map.drop([:host]) end)
    else
      _ ->
        Marshall.Events.emit("inference.auth_rejected", reason: :invalid_token)
        {:error, :unauthorized}
    end
  end

  @doc "Trusted coordinator helper; caller MUST keep its transaction open."
  @spec authenticate_locked!(binary()) :: map()
  def authenticate_locked!(token) do
    case parse(token) do
      {:ok, id, secret} -> authenticate_locked!(id, secret)
      _ -> reject!(:invalid_token)
    end
  end

  defp authenticate_locked!(id, secret) do
    candidate = fetch!(id)
    host = shared_host!(candidate.host_id)
    credential = fetch!(id)
    now = Ledger.now()

    unless active?(credential, host, now) and
             Plug.Crypto.secure_compare(credential.secret_hash, :crypto.hash(:sha256, secret)),
           do: reject!(:credential_inactive)

    %{host_id: host.id, credential_id: credential.id, now: now, host: host}
  end

  defp shared_host!(id), do: Ledger.share_host!(id) || reject!(:host_unavailable)

  @doc "Caller holds the inference host lock throughout persistence."
  @spec current?(String.t(), Host.t(), DateTime.t()) :: boolean()
  def current?(id, host, now) do
    case Ledger.read!(Credential, id: id) do
      [credential] -> credential.host_id == host.id and active?(credential, host, now)
      _ -> false
    end
  end

  defp active?(credential, host, now),
    do:
      host.enabled and is_nil(credential.revoked_at) and
        DateTime.compare(credential.expires_at, now) == :gt

  defp fetch!(id) do
    case Ledger.read!(Credential, id: id) do
      [credential] -> credential
      _ -> reject!(:unknown_credential)
    end
  end

  defp revoke_locked!(host_id) do
    now = Ledger.now()

    Ledger.read!(Credential, host_id: host_id, revoked_at: [is_nil: true])
    |> Enum.map(fn credential ->
      Ledger.update!(credential, :revoke, %{revoked_at: now})
    end)
  end

  defp reject!(reason) do
    Marshall.Events.emit("inference.auth_rejected", reason: reason)
    Ledger.rollback(:unauthorized)
  end

  defp parse(token) when is_binary(token) and byte_size(token) == 80 do
    case String.split(token, ".", parts: 2) do
      [id, secret] ->
        if OverallsProtocol.uuid?(id) and Regex.match?(~r/\A[A-Za-z0-9_-]{43}\z/, secret),
          do: {:ok, id, secret},
          else: {:error, :unauthorized}

      _ ->
        {:error, :unauthorized}
    end
  end

  defp parse(_), do: {:error, :unauthorized}
end
