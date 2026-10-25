defmodule Audi.PrivateIssuer do
  @moduledoc "Restricted Unix-socket boundary for the private issuer role."

  use GenServer

  @type options :: [
          socket: Path.t(),
          python: Path.t(),
          issuer_key: Path.t(),
          issuer_certificate: Path.t()
        ]
  @type state :: %{listener: :gen_tcp.socket(), socket: Path.t()}

  # @cc [owner:ghuntley,label:security] audi-private-issuer-socket
  # The private issuer MUST bind only its validated Unix socket, accept no
  # network families, and keep its listener supervised by Audi. Credentials
  # remain in systemd's service-owned paths; this boundary never logs requests.
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)

  @impl GenServer
  @spec init(options()) :: {:ok, state()} | {:stop, :invalid_socket}
  def init(options) do
    socket = Keyword.fetch!(options, :socket)
    File.rm(socket)

    case :gen_tcp.listen(0, [
           :binary,
           {:active, false},
           {:packet, :line},
           {:ifaddr, {:local, socket}}
         ]) do
      {:ok, listener} ->
        send(self(), :accept)
        {:ok, %{listener: listener, socket: socket}}

      {:error, _reason} ->
        {:stop, :invalid_socket}
    end
  end

  @impl GenServer
  def handle_info(:accept, %{listener: listener} = state) do
    case :gen_tcp.accept(listener, 1_000) do
      {:ok, client} ->
        :gen_tcp.close(client)
        send(self(), :accept)
        {:noreply, state}

      {:error, :timeout} ->
        send(self(), :accept)
        {:noreply, state}

      {:error, _reason} ->
        {:stop, :listener_failed, state}
    end
  end

  @impl GenServer
  def terminate(_reason, %{listener: listener, socket: socket}) do
    :gen_tcp.close(listener)
    File.rm(socket)
    :ok
  end
end
