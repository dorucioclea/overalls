defmodule Audi.Application do
  @moduledoc "Supervision boundary for Audi's independently deployable roles."
  use Application

  # @cc [owner:ghuntley,label:verification] antithesis-bootstrap-reachable
  # Only a harness-built release emits this literal after successful supervision.
  # The production module has no SDK call or runtime switch.
  if System.get_env("ANTITHESIS_HARNESS") == "1" do
    Code.eval_quoted(
      quote location: :keep do
        require OverallsAntithesis.SDK

        @spec harness_started(GenServer.on_start()) :: GenServer.on_start()
        defp harness_started(result) do
          if match?({:ok, _pid}, result) and
               OverallsAntithesis.SDK.declare_catalog([__MODULE__]) == :written do
            OverallsAntithesis.SDK.reachable("Overalls Audi application started")
          end

          result
        end
      end,
      [],
      __ENV__
    )
  else
    @spec harness_started(GenServer.on_start()) :: GenServer.on_start()
    defp harness_started(result), do: result
  end

  require Audi.Events

  @impl true
  def start(_type, _args) do
    :ok = Audi.OTPReports.install()
    :ok = Audi.Privacy.install()

    case listener_children(System.get_env("AUDI_CONFIG_FILE")) do
      {:ok, listeners} ->
        children =
          Overalls.RequestAccounting.Producer.children(Audi.RequestRecorder) ++
            [
              {Registry, keys: :unique, name: Audi.SSH.Proofs},
              {Registry, keys: :duplicate, name: Audi.Control.Hints},
              {Audi.Wake.Waiters, []}
            ] ++ slo_children() ++ listeners

        harness_started(
          Supervisor.start_link(children, strategy: :rest_for_one, name: Audi.Supervisor)
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp slo_children do
    case System.get_env("AUDI_SLO_SNAPSHOT") do
      nil ->
        []

      path ->
        [{Audi.SLO, path: path, service: System.get_env("AUDI_SLO_SERVICE", "audi_private")}]
    end
  end

  # @cc [owner:ghuntley,label:security] audi-configured-startup-fails-closed
  # A configured gateway MUST start only from validated operator configuration
  # using the real authority and local connector. Invalid configuration MUST
  # fail startup without echoing its path, contents or credentials. Loss of the
  # proof registry MUST restart the listener and close its existing connections.
  @spec listener_children(nil | binary()) ::
          {:ok, [Supervisor.child_spec() | {module(), keyword()}]}
          | {:error, :invalid_runtime_configuration}
  def listener_children(nil), do: {:ok, []}

  def listener_children(path) do
    with {:ok, options} <- Audi.Config.load(path) do
      {path, options} = Keyword.pop(options, :status_socket)

      with {:ok, children} <- role_children(options) do
        {:ok, children ++ status_children(path, options)}
      end
    else
      {:error, reason} = error when is_atom(reason) ->
        Audi.Events.emit("audi.startup_configuration_rejected", reason: reason)
        error
    end
  end

  defp status_children(nil, _), do: []

  defp status_children(path, [{:role, :dns} | options]),
    do: [{Audi.StatusServer, path: path, client: options[:client], role: :dns}]

  defp status_children(path, options) do
    {_, %{client: client}} = options[:backend]
    tls = options[:tls]
    peer = probe_address(options[:bind])
    ports = if tls, do: [{peer, tls[:http_port]}, {peer, tls[:https_port]}], else: []
    [{Audi.StatusServer, path: path, client: client, role: :gateway, ports: ports}]
  end

  defp role_children([{:role, :private} | options]) do
    {:ok,
     [
       {Audi.DNS.Server,
        name: Audi.Private.DNS.Server,
        authority_module: Audi.Private.DNS,
        authority: nil,
        ip: {169, 254, 254, 1},
        port: 53},
       {Audi.Private.Listener, options},
       {Audi.StatusServer,
        path: options[:private_status],
        client: nil,
        role: :private,
        health: fn -> Audi.Private.Health.ready?(options[:roots]) end}
     ]}
  end

  defp role_children([{:role, :private_issuer} | options]) do
    {:ok, [{Audi.PrivateIssuer, options}]}
  end

  defp role_children([{:role, :dns} | options]) do
    authority =
      struct!(
        Audi.DNS.Authority,
        Keyword.take(options, [:zone, :nameservers, :mailbox]) ++ [directory: Audi.DNS.Directory]
      )

    {:ok,
     [{Audi.Control.Link, options[:client]}] ++
       Audi.DNS.Directory.children(name: Audi.DNS.Directory, zone: Enum.join(options[:zone], ".")) ++
       [
         {Audi.DNS.Server, authority: authority, ip: options[:bind], port: options[:port]},
         {Audi.DNS.Replica,
          client: options[:client],
          directory: Audi.DNS.Directory,
          zone: Enum.join(options[:zone], ".")}
       ]}
  end

  defp role_children(options) do
    {tls, options} = Keyword.pop(options, :tls)
    {relay, options} = Keyword.pop(options, :relay)

    {Audi.SSH.ControlBackend, %{client: client, connector: connector}} =
      Keyword.fetch!(options, :backend)

    {:ok,
     [
       {Audi.Control.Link, client},
       {Audi.SSH.Listener, options},
       {Audi.SSH.KeyPublisher,
        client: client, host_key_dir: Keyword.fetch!(options, :host_key_dir)}
     ] ++
       relay_children(relay, client, connector) ++
       tls_children(tls, client, options[:bind], connector)}
  end

  @spec relay_children(map() | nil, Audi.Control.Client.t(), tuple()) :: [
          Supervisor.child_spec() | {module(), keyword()}
        ]
  defp relay_children(nil, _, _), do: []

  defp relay_children(relay, client, connector),
    do: [{Audi.Relay.Server, Map.to_list(relay) ++ [client: client, connector: connector]}]

  # @cc [owner:ghuntley,label:verification] audi-probe-listener-address
  # Readiness MUST probe the configured listener address. Only a wildcard
  # listener may substitute loopback; explicit public binds must probe that IP.
  defp probe_address({0, 0, 0, 0}), do: {127, 0, 0, 1}
  defp probe_address(address), do: address

  defp tls_children(nil, _, _, _), do: []

  defp tls_children(tls, client, bind, connector) do
    store = Audi.TLS.Store
    peer = probe_address(bind)

    worker =
      Keyword.merge(tls,
        client: client,
        store: store,
        tasks: Audi.TLS.Tasks,
        probe_peer: {peer, tls[:https_port]}
      )

    Audi.TLS.Store.children(name: store, trust_pem: tls[:trust_pem]) ++
      [
        Supervisor.child_spec(
          {Audi.HTTP.Listener,
           scheme: :http,
           store: store,
           zone: tls[:zone],
           ip: bind,
           port: tls[:http_port],
           https_port: tls[:https_port]},
          id: :audi_http
        ),
        Supervisor.child_spec(
          {Audi.HTTP.Listener,
           scheme: :https,
           client: client,
           connector: connector,
           zone: tls[:zone],
           browser_origin: tls[:browser_origin],
           editor_assets: tls[:editor_assets],
           trusted_proxy_peer: tls[:trusted_proxy_peer],
           store: store,
           ip: bind,
           port: tls[:https_port],
           https_port: tls[:https_port]},
          id: :audi_https
        ),
        {Task.Supervisor, name: Audi.TLS.Tasks, max_children: 20},
        {Audi.TLS.FleetWorker, worker}
      ] ++
      Enum.map(tls[:editor_assets], fn {target, assets} ->
        Supervisor.child_spec(
          {Audi.HTTP.EditorAssetsPublisher,
           client: client,
           assets: assets,
           probe_peer: {peer, tls[:https_port]},
           zone: tls[:zone],
           trust_pem: tls[:trust_pem]},
          id: {Audi.HTTP.EditorAssetsPublisher, target}
        )
      end)
  end
end
