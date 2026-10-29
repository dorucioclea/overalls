defmodule Lilly.Private.Server do
  @moduledoc "Audi-authenticated pre-NAT peer lookup, never a guest-controlled identity."
  use GenServer
  import Bitwise

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    path = Keyword.fetch!(options, :path)
    uid = Keyword.fetch!(options, :audi_uid)
    host = Keyword.fetch!(options, :host_id)
    maximum = Keyword.get(options, :max_connections, 1024)

    with true <-
           is_binary(path) and byte_size(path) in 1..107 and
             Path.type(path) == :absolute and Path.expand(path) == path and
             not String.contains?(path, <<0>>),
         true <- is_integer(uid) and uid in 0..4_294_967_294,
         true <- OverallsProtocol.uuid?(host),
         true <- is_integer(maximum) and maximum in 1..1024,
         {:ok, %{uid: service_uid}} <- Lilly.Host.Privilege.stat("/proc/self"),
         true <- trusted_directory?(Path.dirname(path), service_uid),
         {:ok, lock} <- Lilly.Ingress.SocketCustody.acquire(path),
         {:ok, socket} <-
           :gen_tcp.listen(0, [
             :binary,
             ifaddr: {:local, path},
             active: false,
             packet: 4,
             packet_size: 1024,
             backlog: 128,
             send_timeout: 1000,
             send_timeout_close: true
           ]) do
      case File.chmod(path, 0o660) do
        :ok ->
          {:ok, stat} = File.lstat(path)
          parent = self()
          acceptor = spawn_link(fn -> accept(socket, parent) end)

          {:ok,
           %{
             socket: socket,
             lock: lock,
             path: path,
             inode: stat.inode,
             uid: uid,
             host: host,
             maximum: maximum,
             view: Keyword.get(options, :view, Lilly.Execution.view()),
             acceptor: acceptor,
             workers: %{}
           }}

        _ ->
          :gen_tcp.close(socket)
          {:stop, :connector_unavailable}
      end
    else
      _ -> {:stop, :connector_unavailable}
    end
  end

  # @cc [owner:ghuntley,label:security] lilly-private-connector-owned-socket-directory
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

  # @cc [owner:ghuntley,label:security] lilly-private-connector-bounded-local-admission
  # Each accepted socket MUST authenticate the configured Audi UID using Linux
  # peer credentials before reading one bounded v3 request: a canonical pre-NAT
  # guest IPv4 address and a purpose from the fixed table; no guest identity
  # fields. Admission until the grant is bounded to two seconds. A granted
  # subscription lives only while the binding stays identical and Audi keeps
  # the connection open. At most 1024 workers may exist; send operations and
  # buffers MUST be bounded. Missing view rows deny.
  @impl true
  # A lost hostd session ends this lease (ADR-0176 decision 4).
  def handle_info({:DOWN, ref, :process, _, _}, %{lock: %Lilly.Host.Lease{monitor: ref}} = state),
    do: {:stop, :connector_unavailable, state}

  def handle_info({:accepted, pid}, %{acceptor: pid} = state) do
    if map_size(state.workers) < state.maximum do
      options = Map.take(state, [:uid, :host, :view])

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

  def handle_info({:DOWN, ref, :process, _, _}, state),
    do: {:noreply, %{state | workers: Map.delete(state.workers, ref)}}

  def handle_info({:EXIT, pid, _}, %{acceptor: pid} = state),
    do: {:stop, :connector_unavailable, state}

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(reason, state) do
    Lilly.SupervisedStop.emit(:private, reason)
    :gen_tcp.close(state.socket)
    Process.exit(state.acceptor, :kill)
    Enum.each(state.workers, fn {_, pid} -> Process.exit(pid, :kill) end)

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
    {:ok, timer} = :timer.exit_after(2000, self(), :kill)

    try do
      with :ok <- peer(socket, options.uid),
           {:ok, bytes} <- :gen_tcp.recv(socket, 0, 1000),
           {:ok, input} <- JSON.decode(bytes),
           {:ok, address, purpose} <- OverallsProtocol.PrivateServices.decode_watch_request(input),
           {:ok, binding, watch} <- grant(options, address, purpose),
           :ok <- OverallsProtocol.View.subscribe(options.view, watch.keys),
           # Re-resolve after subscribing: no change can fall between the two.
           {:ok, ^binding, watch} <- grant(options, address, purpose),
           :ok <-
             send_frame(socket, OverallsProtocol.PrivateServices.grant(purpose, wire(binding))) do
        :timer.cancel(timer)
        hold(socket, options, address, purpose, binding, arm(watch))
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

  # @cc [owner:ghuntley,label:security;recovery] private-subscription-revocation
  # A held subscription MUST re-resolve on every change to its watched rows and
  # at the proof deadline, and MUST send the revocation frame and close as soon
  # as the binding is absent or different. Audi closing the connection, or any
  # inbound data, ends the subscription.
  defp hold(socket, options, address, purpose, binding, deadline) do
    :ok = :inet.setopts(socket, active: :once)

    receive do
      {:view_changed, _view, _key} ->
        recheck(socket, options, address, purpose, binding, deadline)

      {:deadline, ref} when ref == elem(deadline, 0) ->
        recheck(socket, options, address, purpose, binding, deadline)

      {:tcp, ^socket, _data} ->
        :ok

      {:tcp_closed, ^socket} ->
        :ok

      {:tcp_error, ^socket, _reason} ->
        :ok
    end
  end

  defp recheck(socket, options, address, purpose, binding, deadline) do
    case grant(options, address, purpose) do
      {:ok, ^binding, watch} ->
        Process.cancel_timer(elem(deadline, 1))
        hold(socket, options, address, purpose, binding, arm(watch))

      _ ->
        _ = send_frame(socket, OverallsProtocol.PrivateServices.revocation())
        :ok
    end
  end

  defp arm(watch) do
    delay = max(watch.valid_until - System.monotonic_time(:millisecond), 0)
    ref = make_ref()
    {ref, Process.send_after(self(), {:deadline, ref}, delay)}
  end

  defp grant(options, address, purpose) do
    case Lilly.Control.Runtime.private_grant(options.view, address, purpose) do
      {:ok, binding, watch} ->
        if binding.host_id == options.host, do: {:ok, binding, watch}, else: :error

      _ ->
        :error
    end
  end

  defp send_frame(socket, frame), do: :gen_tcp.send(socket, JSON.encode!(frame))

  defp wire(binding), do: Map.new(binding, fn {key, value} -> {Atom.to_string(key), value} end)

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
end
