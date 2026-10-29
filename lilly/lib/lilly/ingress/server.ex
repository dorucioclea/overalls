defmodule Lilly.Ingress.Server do
  @moduledoc "Bounded local ingress handoff. No listener or guest backend is enabled by default."
  use GenServer
  import Bitwise
  alias Lilly.Ingress.Bridges
  require Lilly.Events
  alias OverallsProtocol.IngressConnect

  # Live detached bridges are listed this often, so a keeper learns that its
  # bridge ended and a bridge nobody keeps is ended (ADR-0187).
  @sweep 2000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    path = Keyword.fetch!(options, :path)
    uid = Keyword.fetch!(options, :audi_uid)
    host = Keyword.fetch!(options, :host_id)
    maximum = Keyword.get(options, :max_connections, 128)

    with true <-
           is_binary(path) and byte_size(path) in 1..107 and
             Path.type(path) == :absolute and Path.expand(path) == path and
             not String.contains?(path, <<0>>),
         true <- is_integer(uid) and uid in 0..4_294_967_294,
         true <- OverallsProtocol.uuid?(host),
         true <- is_integer(maximum) and maximum in 1..128,
         {:ok, %{uid: service_uid}} <- Lilly.Host.Privilege.stat("/proc/self"),
         true <- trusted_directory?(Path.dirname(path), service_uid),
         {:ok, lock} <- Lilly.Ingress.SocketCustody.acquire(path),
         {:ok, socket} <-
           :gen_tcp.listen(0, [
             :binary,
             ifaddr: {:local, path},
             active: false,
             packet: 4,
             packet_size: IngressConnect.maximum(),
             backlog: 128,
             send_timeout: 1000,
             send_timeout_close: true
           ]) do
      case File.chmod(path, 0o660) do
        :ok ->
          {:ok, stat} = File.lstat(path)
          parent = self()
          acceptor = spawn_link(fn -> accept(socket, parent) end)

          backend = Keyword.get(options, :backend)
          detached = detached?(backend)

          state = %{
            socket: socket,
            lock: lock,
            path: path,
            inode: stat.inode,
            uid: uid,
            host: host,
            maximum: maximum,
            backend: backend,
            acceptor: acceptor,
            workers: %{},
            server: self(),
            detached: detached,
            directory: Bridges.directory(path),
            bridge_host: Keyword.get(options, :bridge_host, {Bridges, nil}),
            bridges: %{},
            keepers: %{},
            adopted: false
          }

          if detached,
            do: {:ok, state, {:continue, :adopt}},
            else: {:ok, state}

        _ ->
          :gen_tcp.close(socket)
          {:stop, :connector_unavailable}
      end
    else
      _ -> {:stop, :connector_unavailable}
    end
  end

  # @cc [owner:ghuntley,label:security] lilly-connector-owned-socket-directory
  # Binding and chmod MUST occur only beneath real directories owned by this
  # service or root, without group/other write access except root-owned sticky
  # directories. Existing paths MUST pass exclusive claimed-socket recovery;
  # unknown files or unclaimed sockets MUST NOT be removed or adopted.
  defp trusted_directory?(path, uid) do
    case Lilly.Host.Privilege.lstat(path) do
      {:ok, %{type: :directory, uid: owner, mode: mode}} when owner == 0 or owner == uid ->
        (band(mode, 0o022) == 0 or (owner == 0 and band(mode, 0o1000) != 0)) and
          (path == "/" or trusted_directory?(Path.dirname(path), uid))

      _ ->
        false
    end
  end

  # @cc [owner:ghuntley,label:security] lilly-connector-bounded-local-admission
  # Each accepted socket MUST authenticate the configured Audi UID using Linux
  # peer credentials before reading the bounded request. Requests MUST bind this
  # host and a validated SSH/web/nested execution identity. At most 128 workers may exist;
  # setup, send operations and buffers MUST be bounded. Missing backend denies.
  @impl true
  # A lost hostd session ends this lease (ADR-0176 decision 4).
  def handle_info({:DOWN, ref, :process, _, _}, %{lock: %Lilly.Host.Lease{monitor: ref}} = state),
    do: {:stop, :connector_unavailable, state}

  def handle_info({:accepted, pid}, %{acceptor: pid} = state) do
    if map_size(state.workers) + map_size(state.bridges) < state.maximum do
      options = Map.take(state, [:uid, :host, :backend, :server, :detached, :directory])

      {worker, ref} =
        :erlang.spawn_opt(
          fn ->
            receive do
              {:socket, socket} -> serve(socket, options)
            after
              2000 -> :ok
            end
          end,
          [:link, :monitor]
        )

      send(pid, {:handoff, worker})
      {:noreply, %{state | workers: Map.put(state.workers, ref, worker)}}
    else
      send(pid, :reject)
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) when is_map_key(state.keepers, ref) do
    {key, keepers} = Map.pop(state.keepers, ref)
    {:noreply, %{state | keepers: keepers, bridges: Map.delete(state.bridges, key)}}
  end

  # A worker that dies holding a reservation may or may not have started its
  # bridge: a keeper decides, and the sweep tells it if the bridge never ran.
  def handle_info({:DOWN, ref, :process, pid, _}, state) do
    state = %{state | workers: Map.delete(state.workers, ref)}

    orphans =
      for {key, {:pending, binding, ^pid}} <- state.bridges, do: {key, binding}

    {:noreply,
     Enum.reduce(orphans, state, fn {key, binding}, state ->
       keeper(state, key, binding, :handoff)
     end)}
  end

  def handle_info(:sweep, state) do
    Process.send_after(self(), :sweep, @sweep)
    {:noreply, sweep(state)}
  end

  def handle_info(:adopt, state), do: handle_continue(:adopt, state)

  def handle_info({:EXIT, pid, _}, %{acceptor: pid} = state),
    do: {:stop, :connector_unavailable, state}

  def handle_info(_, state), do: {:noreply, state}

  # @cc [owner:ghuntley,label:security;recovery] ingress-bridges-readopted
  # On start, a connector whose backend bridges detached MUST give every live
  # bridge with a readable record a keeper with the 30 s adoption grace, end
  # every live bridge without one, and drop records of bridges no longer
  # live. Until hostd answers it retries every second. Afterwards it sweeps
  # every 2 s: a kept bridge that is gone stops its keeper, and a live bridge
  # nobody reserved or keeps is ended.
  @impl true
  def handle_continue(:adopt, state) do
    {module, context} = state.bridge_host

    case safe_live(module, context) do
      {:ok, live} ->
        records = Bridges.records(state.directory)
        live = MapSet.new(live)

        forgotten =
          for {key, _} <- records, not MapSet.member?(live, key) do
            Bridges.forget(state.directory, key)
          end

        state =
          Enum.reduce(live, state, fn key, state ->
            if Map.has_key?(state.bridges, key),
              do: state,
              else: keeper(state, key, Map.get(records, key, :unknown), :adopt)
          end)

        unknown = Enum.count(live, &(Map.get(records, &1, :unknown) == :unknown))

        Lilly.Events.emit("lilly.ingress_bridges_adopted",
          adopting: MapSet.size(live) - unknown,
          ended: unknown,
          forgotten: length(forgotten)
        )

        Process.send_after(self(), :sweep, @sweep)
        {:noreply, %{state | adopted: true}}

      _ ->
        Process.send_after(self(), :adopt, 1000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:reserve, key, binding}, {pid, _}, state) do
    cond do
      Map.has_key?(state.bridges, key) ->
        {:reply, :error, state}

      map_size(state.bridges) >= state.maximum ->
        {:reply, :error, state}

      true ->
        {:reply, :ok, put_in(state.bridges[key], {:pending, binding, pid})}
    end
  end

  def handle_call({:handoff, key}, {pid, _}, state) do
    case state.bridges do
      %{^key => {:pending, binding, ^pid}} -> {:reply, :ok, keeper(state, key, binding, :handoff)}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:release, key}, {pid, _}, state) do
    case state.bridges do
      %{^key => {:pending, _, ^pid}} ->
        {:reply, :ok, %{state | bridges: Map.delete(state.bridges, key)}}

      _ ->
        {:reply, :ok, state}
    end
  end

  defp keeper(state, key, binding, mode) do
    keeper =
      Bridges.start_keeper(state.backend, state.bridge_host, state.directory, key, binding, mode)

    ref = Process.monitor(keeper)

    %{
      state
      | bridges: Map.put(state.bridges, key, {:kept, keeper}),
        keepers: Map.put(state.keepers, ref, key)
    }
  end

  defp sweep(%{adopted: true} = state) do
    {module, context} = state.bridge_host

    case safe_live(module, context) do
      {:ok, live} ->
        live = MapSet.new(live)

        for {key, {:kept, keeper}} <- state.bridges,
            not MapSet.member?(live, key),
            do: send(keeper, :ended)

        Enum.reduce(live, state, fn key, state ->
          if Map.has_key?(state.bridges, key),
            do: state,
            else: keeper(state, key, :unknown, :adopt)
        end)

      _ ->
        state
    end
  end

  defp sweep(state), do: state

  defp safe_live(module, context) do
    module.live(context)
  rescue
    _ -> {:error, :hostd_unavailable}
  catch
    _, _ -> {:error, :hostd_unavailable}
  end

  defp detached?({module, _}) when is_atom(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :bridge, 5)

  defp detached?(_), do: false

  @impl true
  def terminate(reason, state) do
    Lilly.SupervisedStop.emit(:ingress, reason)
    :gen_tcp.close(state.socket)
    Process.exit(state.acceptor, :kill)
    Enum.each(state.workers, fn {_, pid} -> Process.exit(pid, :kill) end)
    # Keepers die without ending their bridges: a restarted connector adopts
    # them again (ingress-bridges-readopted).
    Enum.each(state.bridges, fn
      {_, {:kept, pid}} -> Process.exit(pid, :kill)
      _ -> :ok
    end)

    if Lilly.Host.Lock.held?(state.lock) do
      case File.lstat(state.path) do
        {:ok, %{inode: inode, type: :other}} when inode == state.inode -> File.rm(state.path)
        _ -> :ok
      end
    end

    Lilly.Host.Lock.release(state.lock)

    :ok
  end

  @impl true
  def format_status(status), do: Lilly.DiagnosticStatus.redact(status)

  defp accept(listener, parent) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        send(parent, {:accepted, self()})

        receive do
          {:handoff, worker} ->
            case :gen_tcp.controlling_process(socket, worker) do
              :ok -> send(worker, {:socket, socket})
              _ -> :gen_tcp.close(socket)
            end

          :reject ->
            :gen_tcp.close(socket)
        after
          2000 -> :gen_tcp.close(socket)
        end

        accept(listener, parent)

      _ ->
        :ok
    end
  end

  defp serve(socket, options) do
    # The timer service kills this owner even if a backend blocks during setup.
    {:ok, timer} = :timer.exit_after(2000, self(), :kill)

    try do
      with :ok <- peer(socket, options.uid),
           {:ok, bytes} <- :gen_tcp.recv(socket, 0, 1000),
           {:ok, %{host_id: host} = binding} when host == options.host <-
             IngressConnect.decode(bytes) do
        :timer.cancel(timer)
        serve_bound(socket, options, binding)
      end
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    after
      :timer.cancel(timer)
      :gen_tcp.close(socket)
    end
  end

  # @cc [owner:ghuntley,label:security;recovery] editor-bounded-cold-start
  # Only a validated editor binding may receive the bounded cold-start budget.
  # Its independent execution guardian MUST exist before worker preparation;
  # successful readiness MUST remove the setup timer before opaque relay.
  # On a detached backend the budget also covers hostd's bounded wait for the
  # guest's ready frame, and the worker ends once the bridge is kept.
  defp serve_bound(socket, options, binding) do
    {:ok, timer} = :timer.exit_after(setup_budget(options, binding), self(), :kill)

    try do
      with {:ok, guest, guardian} when is_pid(guardian) <-
             open_or_bridge(options, socket, binding) do
        try do
          ref = Process.monitor(guardian)

          with true <- Process.alive?(guardian),
               :ok <-
                 :inet.setopts(guest,
                   active: false,
                   packet: 0,
                   send_timeout: 1000,
                   send_timeout_close: true
                 ),
               :ok <- :gen_tcp.send(socket, IngressConnect.ready()),
               :ok <- :inet.setopts(socket, packet: 0, packet_size: 0) do
            :timer.cancel(timer)
            relay(socket, guest, ref)
          end
        after
          :gen_tcp.close(guest)
        end
      end
    after
      :timer.cancel(timer)
    end
  end

  defp peer(socket, uid) do
    case :inet.getopts(socket, [{:raw, 1, 17, 12}]) do
      {:ok,
       [
         {:raw, 1, 17,
          <<_pid::native-signed-32, ^uid::native-unsigned-32, _gid::native-unsigned-32>>}
       ]} ->
        :ok

      _ ->
        :error
    end
  end

  # @cc [owner:ghuntley,label:assumption;security] lilly-connector-backend-fence
  # The operator-owned backend MUST resolve only current local durable execution
  # identity, return a passive guest socket owned by this worker or, for a
  # detached bridge, hand Audi's connection to hostd, and supply a guardian
  # that dies when that execution loses authority. It MUST NOT derive
  # addresses or paths from unvalidated peer data. Production has no default backend.
  defp open({module, context}, binding), do: module.open(context, binding)
  defp open(_, _), do: {:error, :connector_unavailable}

  # A detached start adds a durable record, the namespace dial and a scope
  # start to the 2 s guardian and connect budget; a detached editor also
  # waits up to 20 s in hostd for the guest's ready frame (ADR-0192), within
  # hostd's call bound of dial + ready + 10 s.
  defp setup_budget(%{detached: true}, %{service: :editor}), do: 32_000
  defp setup_budget(_, %{service: :editor}), do: 22_000

  defp setup_budget(%{detached: true}, binding),
    do: if(Lilly.Network.Ingress.detachable?(binding), do: 8000, else: 2000)

  defp setup_budget(_, _), do: 2000

  # @cc [owner:ghuntley,label:security;recovery] ingress-detached-handoff
  # A detachable binding on a backend that bridges detached MUST reserve a
  # fresh key with the connector (within its connection bound), record the
  # binding, and only then ask the backend to bridge Audi's connection. When
  # hostd bridged it (the greeting already written), the worker MUST hand the
  # key to a keeper and close only its own copy of the connection; on a
  # fallback socket or any failure it releases the key and drops the record.
  defp open_or_bridge(%{detached: true} = options, socket, binding) do
    if Lilly.Network.Ingress.detachable?(binding),
      do: bridge(options, socket, binding),
      else: open(options.backend, binding)
  end

  defp open_or_bridge(options, _socket, binding), do: open(options.backend, binding)

  defp bridge(%{backend: {module, context}} = options, socket, binding) do
    key = Bridges.new_key()
    greeting = IngressConnect.ready()

    with :ok <- GenServer.call(options.server, {:reserve, key, binding}),
         :ok <- record_or_release(options, key, binding) do
      case module.bridge(
             context,
             binding,
             socket,
             key,
             <<byte_size(greeting)::32, greeting::binary>>
           ) do
        {:bridged, _guardian} ->
          GenServer.call(options.server, {:handoff, key})
          {:error, :bridged}

        other ->
          Bridges.forget(options.directory, key)
          GenServer.call(options.server, {:release, key})

          case other do
            {:socket, guest, guardian} -> {:ok, guest, guardian}
            _ -> {:error, :connector_unavailable}
          end
      end
    else
      _ -> {:error, :connector_unavailable}
    end
  end

  defp record_or_release(options, key, binding) do
    case Bridges.record(options.directory, key, binding) do
      :ok ->
        :ok

      error ->
        GenServer.call(options.server, {:release, key})
        error
    end
  end

  defp relay(client, guest, ref) do
    with :ok <- :inet.setopts(client, active: :once, buffer: 65_536),
         :ok <- :inet.setopts(guest, active: :once, buffer: 65_536) do
      pump(client, guest, ref)
    end
  end

  defp pump(client, guest, ref) do
    receive do
      {:tcp, socket, bytes} when socket == client or socket == guest ->
        target = if socket == client, do: guest, else: client

        with :ok <- :gen_tcp.send(target, bytes),
             :ok <- :inet.setopts(socket, active: :once),
             do: pump(client, guest, ref)

      {:DOWN, ^ref, :process, _, _} ->
        :ok

      {:tcp_closed, _} ->
        :ok

      {:tcp_error, _, _} ->
        :ok
    end
  end
end
