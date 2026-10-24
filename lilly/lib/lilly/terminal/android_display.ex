defmodule Lilly.Terminal.AndroidDisplay do
  @moduledoc "Owns one namespace-bound Android RFB socket for a terminal stream."
  use GenServer

  # @cc [owner:ghuntley,label:security;recovery] android-display-socket-custody
  # The display process MUST own only the namespace-bound socket for its exact
  # generation, forward opaque bounded bytes, and close on either endpoint loss.

  alias Lilly.Network.{Config, Guest, Ingress}

  @type binding :: %{
          android_display: true,
          generation: pos_integer(),
          ticket: String.t(),
          mode: :viewer | :controller
        }

  @spec start_link(pid(), Config.t(), Guest.t(), binding(), pos_integer(), pos_integer()) ::
          GenServer.on_start()
  def start_link(owner, config, guest, binding, generation, channel) do
    GenServer.start_link(__MODULE__, {owner, config, guest, binding, generation, channel})
  end

  @spec input(GenServer.server(), binary()) :: :ok
  def input(server, bytes), do: GenServer.cast(server, {:input, bytes})

  @spec stop(GenServer.server()) :: :ok
  def stop(server), do: GenServer.stop(server, :normal)

  @impl true
  def init({owner, config, guest, binding, generation, channel}) do
    Process.flag(:trap_exit, true)

    case Ingress.connect_android_display(config, guest, binding, generation) do
      {:ok, socket} ->
        :ok = :inet.setopts(socket, [{:active, :once}])
        {:ok, %{owner: owner, socket: socket, generation: generation, channel: channel}}

      {:error, _reason} ->
        {:stop, :display_unavailable}
    end
  end

  @impl true
  def handle_cast({:input, bytes}, state) when is_binary(bytes) and byte_size(bytes) in 1..4096 do
    case :gen_tcp.send(state.socket, bytes) do
      :ok -> {:noreply, state}
      {:error, _reason} -> {:stop, :normal, state}
    end
  end

  def handle_cast(_, state), do: {:noreply, state}

  @impl true
  def handle_info({:tcp, socket, bytes}, %{socket: socket} = state) do
    send(state.owner, {:android_display_frame, state.channel, state.generation, bytes})
    :ok = :inet.setopts(socket, [{:active, :once}])
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state), do: {:stop, :normal, state}

  def handle_info({:tcp_error, socket, _reason}, %{socket: socket} = state),
    do: {:stop, :normal, state}

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{socket: socket}), do: :gen_tcp.close(socket)
  def terminate(_, _), do: :ok
end
