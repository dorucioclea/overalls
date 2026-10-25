defmodule Audi.Config do
  @moduledoc "Closed, operator-owned startup configuration with a separate private gateway credential."
  import Bitwise
  alias Audi.Control.Client

  @fields ~w(version role public_origin control_plane host_id credential_file host_key_dir bind port cacertfile connector_path connector_uid tls status_socket relay)

  # @cc [owner:ghuntley,label:security] audi-configuration-secret-custody
  # Startup MUST reject unknown fields, inline credentials, non-HTTPS origins,
  # unsafe config/credential paths and invalid listener bounds. Gateway and host
  # private-key files MUST be single-link regular files owned by this service,
  # mode 0400 or 0600, under trusted non-symlink directories. Errors MUST be fixed
  # values without file contents, paths, credentials or parser exceptions.
  @spec load(term()) :: {:ok, keyword()} | {:error, :invalid_runtime_configuration}
  def load(path) do
    with {:ok, encoded} <- read(path, :config, 16_384),
         {:ok, value} <- JSON.decode(encoded) do
      decode(value)
    else
      _ -> {:error, :invalid_runtime_configuration}
    end
  rescue
    _ -> {:error, :invalid_runtime_configuration}
  end

  defp decode(%{"version" => 1, "role" => "private"} = value) do
    expected =
      ~w(version role host_id connector_path connector_uid ziggy_socket galileo_socket certificate_file key_file roots_file status_socket)

    with true <-
           Enum.sort(Map.keys(value) -- ["otel_socket", "peach_socket"]) == Enum.sort(expected),
         true <- OverallsProtocol.uuid?(value["host_id"]),
         true <-
           Enum.all?(
             ~w(connector_path ziggy_socket galileo_socket status_socket),
             &(canonical_path?(value[&1]) and byte_size(value[&1]) <= 107)
           ),
         true <- is_integer(value["connector_uid"]) and value["connector_uid"] in 0..4_294_967_294,
         true <- Enum.all?(~w(otel_socket peach_socket), &optional_socket?(value[&1])),
         {:ok, _} <- read(value["key_file"], :secret, 16_384),
         :ok <- certificate(value["certificate_file"]),
         true <- canonical_path?(value["roots_file"]),
         :ok <- certificate(value["roots_file"]) do
      {:ok,
       [
         role: :private,
         host_id: value["host_id"],
         connector: value["connector_path"],
         connector_uid: value["connector_uid"],
         ziggy_socket: value["ziggy_socket"],
         galileo_socket: value["galileo_socket"],
         peach_socket: value["peach_socket"],
         otel_socket: value["otel_socket"],
         certificate: value["certificate_file"],
         key: value["key_file"],
         roots: value["roots_file"],
         private_status: value["status_socket"]
       ]}
    else
      _ -> {:error, :invalid_runtime_configuration}
    end
  end

  # @cc [owner:ghuntley,label:security] audi-private-issuer-configuration
  # The restricted issuer role MUST accept only its canonical Unix socket and
  # service-owned issuer credentials. It MUST reject TCP endpoints, unknown
  # fields, missing credentials and paths that escape the runtime boundary.
  defp decode(
         %{
           "version" => 1,
           "role" => "private-issuer",
           "socket" => socket,
           "python" => python,
           "issuer_key" => key,
           "issuer_certificate" => certificate
         } = value
       ) do
    with true <- map_size(value) == 6,
         true <-
           canonical_path?(socket) and String.starts_with?(socket, "/run/audi-private-issuer/"),
         true <- canonical_path?(python),
         {:ok, _} <- read(key, :secret, 65_536),
         :ok <- certificate(certificate) do
      {:ok,
       [
         role: :private_issuer,
         socket: socket,
         python: python,
         issuer_key: key,
         issuer_certificate: certificate
       ]}
    else
      _ -> {:error, :invalid_runtime_configuration}
    end
  end

  defp decode(
         %{
           "version" => 1,
           "control_plane" => origin,
           "role" => "gateway",
           "host_id" => host,
           "connector_path" => connector,
           "connector_uid" => connector_uid,
           "credential_file" => credential,
           "host_key_dir" => keys
         } = value
       ) do
    with true <- Map.keys(value) -- @fields == [],
         true <-
           is_nil(value["public_origin"]) or
             OverallsProtocol.SSHOnboarding.public_origin?(value["public_origin"]),
         :ok <- status_socket(value["status_socket"]),
         {:ok, token} <- read(credential, :secret, 256),
         token =
           if(String.ends_with?(token, "\n"),
             do: binary_part(token, 0, byte_size(token) - 1),
             else: token
           ),
         {:ok, client} <-
           Client.new(origin, token, :gateway, host_id: host, cacertfile: value["cacertfile"]),
         true <- canonical_path?(connector) and byte_size(connector) <= 107,
         true <- is_integer(connector_uid) and connector_uid in 0..4_294_967_294,
         :ok <- certificate(value["cacertfile"]),
         true <- canonical_path?(keys),
         {:ok, %File.Stat{type: :directory, uid: owner, mode: mode}} <- File.lstat(keys),
         true <- owner == uid() and band(mode, 0o777) == 0o700,
         {:ok, _} <- read(Path.join(keys, "ssh_host_ed25519_key"), :secret, 16_384),
         port = Map.get(value, "port", 22),
         true <- is_integer(port) and port in 1..65_535,
         bind = Map.get(value, "bind", "0.0.0.0"),
         true <- is_binary(bind) and byte_size(bind) <= 45,
         {:ok, address} <- :inet.parse_ipv4strict_address(String.to_charlist(bind)),
         {:ok, relay} <- relay(value["relay"]),
         {:ok, tls} <- tls(value["tls"], port),
         true <- is_nil(tls) or tls[:browser_origin] != client.origin do
      {:ok,
       [
         host_id: host,
         public_origin: value["public_origin"],
         host_key_dir: keys,
         port: port,
         bind: address,
         backend:
           {Audi.SSH.ControlBackend,
            %{
              client: client,
              connector:
                {Audi.Connector,
                 Map.merge(
                   %{path: connector, uid: connector_uid},
                   if(relay, do: %{relay: relay}, else: %{})
                 )}
            }}
       ] ++
         if(tls, do: [tls: tls], else: []) ++
         if(relay, do: [relay: relay], else: []) ++ status_option(value)}
    else
      _ -> {:error, :invalid_runtime_configuration}
    end
  rescue
    _ -> {:error, :invalid_runtime_configuration}
  end

  # @cc [owner:ghuntley,label:security] audi-dns-role-configuration
  # DNS configuration MUST NOT accept gateway keys, connector paths or injected
  # publication entries. Startup creates an empty replica; only fresh trusted
  # publication may make authoritative routing answers available.
  defp decode(
         %{
           "version" => 1,
           "role" => "dns",
           "control_plane" => origin,
           "credential_file" => credential,
           "zone" => zone,
           "nameservers" => nameservers,
           "mailbox" => mailbox
         } = value
       ) do
    with true <-
           Map.keys(value) --
             ~w(version role zone nameservers mailbox bind port control_plane credential_file cacertfile status_socket) ==
             [],
         :ok <- status_socket(value["status_socket"]),
         {:ok, token} <- read(credential, :secret, 256),
         token = String.trim_trailing(token, "\n"),
         {:ok, client} <- Client.new(origin, token, :dns, cacertfile: value["cacertfile"]),
         :ok <- certificate(value["cacertfile"]),
         true <- dns_name?(zone) and dns_name?(mailbox),
         true <- is_list(nameservers) and length(nameservers) in 2..8,
         true <- Enum.all?(nameservers, &dns_name?/1),
         true <- Enum.uniq(nameservers) == nameservers,
         port = Map.get(value, "port", 53),
         true <- is_integer(port) and port in 1..65_535,
         bind = Map.get(value, "bind", "0.0.0.0"),
         true <- is_binary(bind) and byte_size(bind) <= 45,
         {:ok, address} <- :inet.parse_ipv4strict_address(String.to_charlist(bind)) do
      {:ok,
       [
         role: :dns,
         client: client,
         zone: String.split(zone, "."),
         nameservers: Enum.map(nameservers, &String.split(&1, ".")),
         mailbox: String.split(mailbox, "."),
         bind: address,
         port: port
       ] ++ status_option(value)}
    else
      _ -> {:error, :invalid_runtime_configuration}
    end
  end

  defp decode(_), do: {:error, :invalid_runtime_configuration}

  # @cc [owner:ghuntley,label:security] audi-optional-private-backends
  # An omitted private backend MUST remain disabled. A configured backend MUST
  # name one bounded canonical Unix-socket path, never a TCP origin or inline data.
  @spec optional_socket?(term()) :: boolean()
  defp optional_socket?(nil), do: true

  defp optional_socket?(value),
    do: canonical_path?(value) and byte_size(value) <= 107

  # @cc [owner:ghuntley,label:security] audi-relay-runtime-operator-peers
  # Relay startup MUST require one fleet /32 and a finite distinct list of
  # different fleet peer /32s. Public/wildcard binds and unknown fields refuse.
  @spec relay(term()) :: {:ok, map() | nil} | {:error, :invalid_runtime_configuration}
  defp relay(nil), do: {:ok, nil}

  defp relay(%{"address" => address, "port" => port, "peers" => peers} = value)
       when map_size(value) == 3 do
    if OverallsProtocol.IngressRelay.fleet_address?(address) and is_integer(port) and
         port in 1..65_535 and
         is_list(peers) and length(peers) in 1..254 and Enum.uniq(peers) == peers and
         address not in peers and
         Enum.all?(peers, &OverallsProtocol.IngressRelay.fleet_address?/1),
       do: {:ok, %{address: address, port: port, peers: peers}},
       else: {:error, :invalid_runtime_configuration}
  end

  defp relay(_), do: {:error, :invalid_runtime_configuration}

  # @cc [owner:ghuntley,label:security] audi-status-private-directory
  # Status sockets MUST use canonical absolute paths under trusted nonsymlink
  # ancestors and a service-owned immediate directory of mode 0700, or 0750
  # (optionally setgid) when one dedicated reader group shares it. A directory
  # with any other-user permission or group write MUST be refused.
  @spec status_socket(term()) :: :ok | :error
  def status_socket(nil), do: :ok

  def status_socket(path) do
    with true <- canonical_path?(path) and byte_size(path) <= 107,
         :ok <- parents(Path.dirname(path)),
         {:ok, %File.Stat{type: :directory, uid: owner, mode: mode}} <-
           File.lstat(Path.dirname(path)),
         true <- owner == uid() and band(mode, 0o777) in [0o700, 0o750] do
      :ok
    else
      _ -> :error
    end
  end

  # @cc [owner:ghuntley,label:security] audi-status-socket-mode
  # A status socket MUST be mode 0660 and carry its directory's group only when
  # that validated directory grants its group read and search (the shared 0750
  # layout); otherwise it MUST be 0600 with the service's own group.
  @spec status_socket_access(Path.t()) :: {0o600, nil} | {0o660, non_neg_integer()}
  def status_socket_access(path) do
    case File.lstat(Path.dirname(path)) do
      {:ok, %File.Stat{type: :directory, mode: mode, gid: gid}} when band(mode, 0o777) == 0o750 ->
        {0o660, gid}

      _ ->
        {0o600, nil}
    end
  end

  defp status_option(%{"status_socket" => path}), do: [status_socket: path]
  defp status_option(_), do: []

  # @cc [owner:ghuntley,label:security] audi-tls-runtime-configuration
  # TLS startup MUST use explicit operator trust roots. The public wildcard
  # arrives only through the authenticated control API and remains in memory.
  # Unknown fields, inline keys and colliding listener ports MUST fail startup.
  # An enabled editor package MUST require the shared canonical multi-label
  # editor zone before any listeners or readiness publishers are started.
  defp tls(nil, _), do: {:ok, nil}

  defp tls(
         %{
           "zone" => zone,
           "trust_file" => trust,
           "browser_origin" => browser_origin
         } = value,
         ssh_port
       ) do
    with true <-
           Map.keys(value) --
             ~w(zone trust_file browser_origin http_port https_port trusted_proxy_peer editor_packages) ==
             [],
         true <- dns_name?(zone) and byte_size(zone) <= 189,
         {:ok, browser_origin} <- browser_origin(browser_origin),
         :ok <- certificate(trust),
         {:ok, roots} <- read(trust, :config, 1_048_576),
         http = Map.get(value, "http_port", 80),
         https = Map.get(value, "https_port", 443),
         true <-
           is_integer(http) and http in 1..65_535 and is_integer(https) and https in 1..65_535,
         true <- length(Enum.uniq([ssh_port, http, https])) == 3,
         {:ok, trusted_peer} <- proxy_peer(value["trusted_proxy_peer"]),
         {:ok, assets} <-
           Audi.HTTP.EditorAssets.load_registry(Map.get(value, "editor_packages", %{})),
         true <- map_size(assets) == 0 or OverallsProtocol.EditorConnect.zone?(zone) do
      {:ok,
       [
         zone: zone,
         browser_origin: browser_origin,
         trust_pem: roots,
         http_port: http,
         https_port: https,
         trusted_proxy_peer: trusted_peer,
         editor_assets: assets
       ]}
    else
      _ -> {:error, :invalid_runtime_configuration}
    end
  end

  defp tls(_, _), do: {:error, :invalid_runtime_configuration}

  # @cc [owner:ghuntley,label:security] audi-browser-public-origin
  # Browser approval MUST use a separately configured public HTTPS origin.
  # The private machine API endpoint is never a browser redirect target.
  @spec browser_origin(term()) :: {:ok, binary()} | :error
  defp browser_origin(origin) when is_binary(origin) and byte_size(origin) in 9..512 do
    with {:ok, uri} <- URI.new(origin),
         true <- uri.scheme == "https" and dns_name?(uri.host),
         true <- is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment),
         true <- uri.path in [nil, "/"] and (is_nil(uri.port) or uri.port in 1..65_535) do
      {:ok, String.trim_trailing(origin, "/")}
    else
      _ -> :error
    end
  end

  defp browser_origin(_), do: :error

  defp proxy_peer(nil), do: {:ok, nil}

  defp proxy_peer(address) do
    if OverallsProtocol.ProxyHeader.peer?(%{address: address, port: 1}),
      do: :inet.parse_ipv4strict_address(String.to_charlist(address)),
      else: :error
  end

  defp dns_name?(value) when is_binary(value) and byte_size(value) in 1..253 do
    value
    |> String.split(".")
    |> Enum.all?(fn label ->
      byte_size(label) in 1..63 and Regex.match?(~r/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/, label)
    end)
  end

  defp dns_name?(_), do: false

  defp read(path, kind, maximum) do
    with true <- canonical_path?(path),
         :ok <- parents(Path.dirname(path)),
         {:ok, %File.Stat{type: :regular, size: size} = stat} <- File.lstat(path),
         true <- size in 1..maximum and permissions?(stat, kind),
         {:ok, bytes} when is_binary(bytes) and byte_size(bytes) <= maximum <-
           File.open(path, [:read, :binary], &IO.binread(&1, maximum + 1)) do
      {:ok, bytes}
    else
      _ -> :error
    end
  end

  defp permissions?(stat, :secret),
    do: stat.uid == uid() and stat.links == 1 and band(stat.mode, 0o777) in [0o400, 0o600]

  defp permissions?(stat, :config),
    do: stat.uid in [0, uid()] and band(stat.mode, 0o022) == 0

  defp parents("/"), do: :ok

  defp parents(path) do
    with {:ok, %File.Stat{type: :directory, uid: owner, mode: mode}} <- File.lstat(path),
         true <- owner in [0, uid()],
         true <- band(mode, 0o022) == 0 or (owner == 0 and band(mode, 0o1000) != 0) do
      parents(Path.dirname(path))
    else
      _ -> :error
    end
  end

  defp canonical_path?(path) when is_binary(path) and byte_size(path) in 1..4096,
    do:
      String.valid?(path) and Path.type(path) == :absolute and Path.expand(path) == path and
        not String.contains?(path, [<<0>>, "\n", "\r"])

  defp canonical_path?(_), do: false

  defp certificate(nil), do: :ok

  defp certificate(path) do
    with {:ok, bytes} <- read(path, :config, 1_048_576),
         entries when is_list(entries) and entries != [] <- :public_key.pem_decode(bytes),
         true <-
           Enum.all?(entries, fn
             {:Certificate, der, :not_encrypted} ->
               match?({:OTPCertificate, _, _, _}, :public_key.pkix_decode_cert(der, :otp))

             _ ->
               false
           end) do
      :ok
    else
      _ -> :error
    end
  end

  defp uid do
    {:ok, stat} = File.stat("/proc/self")
    stat.uid
  end
end
