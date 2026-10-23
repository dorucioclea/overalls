defmodule Marshall.Peach.Credentials do
  @moduledoc "Trusted deployment enrollment/rotation and fresh Peach-only request authority."
  alias Marshall.Compute.Ledger
  alias Marshall.Peach.{Credential, IssuedCredential}
  require Marshall.Events
  @maximum_lifetime 5 * 365 * 86_400

  # @cc [owner:ghuntley,label:security] peach-credential-domain-isolation
  # Rotation MUST serialize on the host, revoke prior Peach credentials and
  # issue one random 256-bit secret. Persist only its digest and omit it from
  # audit. It MUST NOT touch compute credentials, sessions, reports or reservations.
  @spec rotate(String.t(), pos_integer()) :: {:ok, IssuedCredential.t()} | {:error, term()}
  def rotate(host_id, ttl) when is_integer(ttl) and ttl > 0 and ttl <= @maximum_lifetime do
    Ledger.transaction(
      fn ->
        host = Ledger.fence_host!(host_id) || Ledger.rollback(:unknown_peach_host)
        unless host.enabled, do: Ledger.rollback(:peach_disabled)
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
            Marshall.Events.emit("peach.credential_rotated",
              host_id: credential.host_id,
              credential_id: credential.id
            )

        {:ok, credential}

      other ->
        other
    end
  end

  def rotate(_, _), do: {:error, :invalid_lifetime}

  @spec revoke(String.t()) :: {:ok, :ok} | {:error, term()}
  def revoke(host_id) do
    Ledger.transaction(
      fn ->
        host = Ledger.fence_host!(host_id) || Ledger.rollback(:unknown_peach_host)
        revoke_locked!(host.id)
      end,
      :operator
    )
    |> case do
      {:ok, :ok} ->
        unless Marshall.Repo.in_transaction?(),
          do: Marshall.Events.emit("peach.credential_revoked", host_id: host_id)

        {:ok, :ok}

      other ->
        other
    end
  end

  # @cc [owner:ghuntley,label:security] peach-current-credential-check
  # Authentication MUST check database-clock expiry, enabled physical host and
  # current revocation after locking that host. Return only host/credential IDs
  # and database time, never a secret or digest.
  @spec authenticate(term()) :: {:ok, map()} | {:error, term()}
  def authenticate(token) do
    with {:ok, id, secret} <- parse(token) do
      Ledger.transaction(fn -> authenticate_locked!(id, secret) |> Map.drop([:host]) end)
    end
  end

  @doc "Trusted coordinator helper; caller MUST keep its transaction open."
  @spec authenticate_locked!(binary()) :: map()
  def authenticate_locked!(token) do
    case parse(token) do
      {:ok, id, secret} -> authenticate_locked!(id, secret)
      _ -> Ledger.rollback(:unauthorized)
    end
  end

  defp authenticate_locked!(id, secret) do
    candidate = fetch!(id)
    host = shared_host!(candidate.host_id)
    credential = fetch!(id)
    now = Ledger.now()

    unless active?(credential, host, now) and
             Plug.Crypto.secure_compare(credential.secret_hash, :crypto.hash(:sha256, secret)),
           do: Ledger.rollback(:unauthorized)

    %{host_id: host.id, credential_id: credential.id, now: now, host: host}
  end

  defp shared_host!(id), do: Ledger.share_host!(id) || Ledger.rollback(:unauthorized)

  defp active?(credential, host, now),
    do:
      host.enabled and is_nil(credential.revoked_at) and
        DateTime.compare(credential.expires_at, now) == :gt

  defp fetch!(id) do
    case Ledger.read!(Credential, id: id) do
      [credential] -> credential
      _ -> Ledger.rollback(:unauthorized)
    end
  end

  defp revoke_locked!(host_id) do
    now = Ledger.now()

    Enum.each(
      Ledger.read!(Credential, host_id: host_id, revoked_at: [is_nil: true]),
      &Ledger.update!(&1, :revoke, %{revoked_at: now})
    )

    :ok
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
