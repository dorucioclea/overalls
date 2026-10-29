defmodule Lilly.Network.AttributionServer do
  @moduledoc "Bounded UID-authenticated local flow attribution; no guest stream handoff."
  use GenServer
  import Bitwise
  alias OverallsProtocol.EgressAttribution, as: Wire

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    path = Keyword.fetch!(options, :path)
    uid = Keyword.fetch!(options, :brady_uid)
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
             packet: 2,
             packet_size: Wire.maximum(),
             backlog: 128,
             send_timeout: 1000,
             send_timeout_close: true
           ]) do
      {:ok, %{gid: gid}} = File.stat(Path.dirname(path))

      case with :ok <- File.chgrp(path, gid), do: File.chmod(path, 0o660) do
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
             lookup: Keyword.get(options, :lookup, fn _ -> {:error, :unresolved} end),
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

  # @cc [owner:ghuntley,label:security] attribution-owned-socket-directory
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

  # @cc [owner:ghuntley,label:security] attribution-bounded-local-admission
  # Each accepted socket MUST authenticate the configured Brady UID using Linux
  # peer credentials before reading the bounded request. Only closed IPv4 tuple requests may reach the resolver, and successful
  # responses MUST bind this host. At most 128 workers may exist; the two-second
  # independent worker deadline MUST also bound a blocked resolver. Missing proof denies.
  @impl true
  # A lost hostd session ends this lease (ADR-0176 decision 4).
  def handle_info({:DOWN, ref, :process, _, _}, %{lock: %Lilly.Host.Lease{monitor: ref}} = state),
    do: {:stop, :connector_unavailable, state}

  def handle_info({:accepted, pid}, %{acceptor: pid} = state) do
    if map_size(state.workers) < state.maximum do
      options = Map.take(state, [:uid, :host, :lookup])

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
    Lilly.SupervisedStop.emit(:attribution, reason)
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
           {:ok, bytes} <- :gen_tcp.recv(socket, 0, 500),
           {:ok, flow} <- Wire.decode_request(bytes) do
        response =
          case options.lookup.(flow) do
            {:ok, %{host_id: host} = identity} when host == options.host ->
              encoded = Wire.response({:ok, identity})

              case Wire.decode_response(encoded) do
                {:ok, ^identity} -> encoded
                _ -> Wire.response({:error, :unresolved})
              end

            _ ->
              Wire.response({:error, :unresolved})
          end

        :gen_tcp.send(socket, response)
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
