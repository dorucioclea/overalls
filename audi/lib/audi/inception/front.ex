defmodule Audi.Inception.Front do
  @moduledoc "Pre-termination nested TLS routing on the original public connection."
  use ThousandIsland.Handler
  alias Audi.Inception.{Authority, ClientHello}
  require Audi.Events
  alias ThousandIsland.Socket

  # @cc [owner:ghuntley,label:security] inception-tls-opaque-routing
  # Nested SNI MUST select a fixed service through current parent authority and
  # the local connector before any byte reaches a guest. Ordinary SNI MUST put
  # all inspected bytes back and upgrade the original socket, preserving peer
  # identity. No child TLS key or plaintext may enter the outer Audi.
  @impl true
  def handle_connection(_socket, %{tls_upgraded: true} = state) do
    :logger.update_process_metadata(%{audi_component: :http, audi_phase: :http_init})
    {_, options} = state.plug
    {address, _port} = Keyword.fetch!(options, :verified_client_peer)

    # This listener explicitly disables HTTP/2. Preserve the peer identity read
    # before TLS so a peer closing immediately after its handshake cannot make
    # Bandit's HTTP initializer re-query the now-closed SSL socket.
    {:continue,
     state
     |> Map.put(:handler_module, Bandit.HTTP1.Handler)
     |> Map.put(:conn_data, {true, address})}
  end

  def handle_connection(socket, state) do
    :logger.update_process_metadata(%{audi_private: true, audi_component: :https})
    started = System.monotonic_time(:millisecond)
    {_, options} = state.plug

    with {:ok, socket_peer} <- Socket.peername(socket),
         {:ok, claimed_peer} <- Audi.Inception.Peer.read(socket, options[:trusted_proxy_peer]),
         {:ok, name, bytes} <- ClientHello.read(socket.socket, started + 5000) do
      peer = claimed_peer || socket_peer
      {plug, _} = state.plug
      state = %{state | plug: {plug, Keyword.put(options, :verified_client_peer, peer)}}

      case OverallsProtocol.InceptionName.route(name, options[:zone]) do
        {:ok, environment, service} ->
          nested(socket, state, options, environment, service, bytes)

        :error ->
          with selected when is_list(selected) <- Audi.TLS.Store.sni(options[:store], name),
               :ok <- :gen_tcp.unrecv(socket.socket, bytes) do
            {:switch_transport,
             {Audi.HTTP.TLSTransport,
              options[:tls_options]
              |> Keyword.merge(selected)
              |> Keyword.put(:audi_deadline, started + 5000)},
             Map.put(state, :tls_upgraded, true), {:continue, :handle_connection}}
          else
            _ -> denied(:unknown_nested_service, state)
          end
      end
    else
      {:error, reason} when reason in [:invalid_client_hello, :invalid_proxy_header] ->
        denied(reason, state)

      _ ->
        denied(:invalid_client_hello, state)
    end
  end

  # @cc [owner:ghuntley,label:security;observability] inception-connection-refusals
  # Every refused nested connection MUST emit its closed refusal reason once
  # per connection before the socket closes; admitted nested traffic stays
  # silent because payloads and names never enter diagnostics.
  defp denied(reason, state) do
    Audi.Events.emit("audi.nested_denied", reason: reason)
    {:close, state}
  end

  defp nested(socket, state, options, environment, service, bytes) do
    with {:ok, {ip, port}} when tuple_size(ip) == 4 <- Socket.peername(socket),
         %Audi.Control.Client{} = client <- options[:client],
         {:ok, grant} <- Audi.Control.Client.open_nested(client, environment, service),
         {:ok, worker} <- Authority.start(client, grant),
         {:ok, guest} <-
           Audi.Connector.open(
             options[:connector],
             Map.put(grant.binding, :client_peer, %{
               address: List.to_string(:inet.ntoa(ip)),
               port: port
             })
           ) do
      case :gen_tcp.send(guest, bytes) do
        :ok ->
          :ok = :inet.setopts(guest, active: :once)
          {:continue, Map.put(state, :nested, %{guest: guest, worker: worker}), 60_000}

        _ ->
          :gen_tcp.close(guest)
          Authority.finish(worker)
          denied(:guest_unreachable, state)
      end
    else
      _ -> denied(:nested_unavailable, state)
    end
  end

  @impl true
  def handle_data(data, _socket, %{nested: nested} = state) do
    case :gen_tcp.send(nested.guest, data) do
      :ok -> {:continue, state, 60_000}
      _ -> {:close, state}
    end
  end

  def handle_data(data, socket, state) do
    :logger.update_process_metadata(%{audi_phase: :http_data})
    Bandit.DelegatingHandler.handle_data(data, socket, state)
  end

  @impl true
  def handle_info({:tcp, guest, data}, {socket, %{nested: %{guest: guest}} = state}) do
    case Socket.send(socket, data) do
      :ok ->
        :ok = :inet.setopts(guest, active: :once)
        {:noreply, {socket, state}}

      _ ->
        {:stop, :normal, {socket, state}}
    end
  end

  def handle_info({:tcp_closed, guest}, {socket, %{nested: %{guest: guest}} = state}),
    do: {:stop, :normal, {socket, state}}

  def handle_info({:tcp_error, guest, _}, {socket, %{nested: %{guest: guest}} = state}),
    do: {:stop, :normal, {socket, state}}

  def handle_info(message, {socket, state}) do
    :logger.update_process_metadata(%{audi_phase: :http_info})
    Bandit.DelegatingHandler.handle_info(message, {socket, state})
  end

  @impl true
  def handle_call(message, from, state),
    do: Bandit.DelegatingHandler.handle_call(message, from, state)

  @impl true
  def handle_cast(message, state), do: Bandit.DelegatingHandler.handle_cast(message, state)

  for callback <- [:handle_close, :handle_error, :handle_shutdown, :handle_timeout] do
    if callback == :handle_error do
      @impl true
      def handle_error(_, socket, %{nested: _} = state), do: cleanup(socket, state)

      def handle_error(reason, socket, state),
        do: Bandit.DelegatingHandler.handle_error(reason, socket, state)
    else
      @impl true
      def unquote(callback)(socket, %{nested: _} = state), do: cleanup(socket, state)

      def unquote(callback)(socket, state),
        do: Bandit.DelegatingHandler.unquote(callback)(socket, state)
    end
  end

  defp cleanup(_socket, %{nested: nested}) do
    :gen_tcp.close(nested.guest)
    Authority.finish(nested.worker)
    :ok
  end
end
