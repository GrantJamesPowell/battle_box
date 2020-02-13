defmodule BattleBox.TcpConnectionServer.ConnectionHandler do
  use GenStateMachine, callback_mode: [:handle_event_function], restart: :temporary
  alias BattleBox.{GameEngine, PlayerServer}
  import BattleBox.TcpConnectionServer.Message
  @behaviour :ranch_protocol

  def start_link(ref, _socket, transport, data) do
    data =
      Map.merge(data, %{
        connection_id: Ecto.UUID.generate(),
        ranch_ref: ref,
        transport: transport
      })

    GenStateMachine.start_link(__MODULE__, data)
  end

  def init(data) do
    {:ok, :unauthed, data, {:next_event, :internal, :initialize}}
  end

  def handle_event(:internal, :initialize, :unauthed, data) do
    Registry.register(data.names.connection_registry, data.connection_id, %{connection_type: :tcp})

    {:ok, socket} = :ranch.handshake(data.ranch_ref)
    :ok = data.transport.setopts(socket, active: :once)
    :ok = data.transport.send(socket, initial_msg(data.connection_id))

    data = Map.put(data, :socket, socket)

    {:keep_state, data}
  end

  def handle_event(:info, {:tcp_closed, _socket}, _state, _data), do: {:stop, :normal}
  def handle_event(:info, {:tcp_error, _socket, _reason}, _state, _data), do: {:stop, :normal}

  def handle_event(:info, {:tcp, socket, bytes}, _state, %{socket: socket} = data) do
    :ok = data.transport.setopts(socket, active: :once)

    case Jason.decode(bytes) do
      {:ok, msg} ->
        {:keep_state_and_data, {:next_event, :internal, msg}}

      {:error, %Jason.DecodeError{}} ->
        :ok = data.transport.send(socket, encode_error("invalid_json"))
        :keep_state_and_data
    end
  end

  def handle_event(
        :internal,
        %{"bot_id" => bot_id, "bot_token" => _, "lobby_name" => lobby_name},
        :unauthed,
        data
      ) do
    GameEngine.start_player(data.names.game_engine, %{
      connection_id: data.connection_id,
      connection: self(),
      player_id: bot_id,
      lobby_name: lobby_name
    })
    |> case do
      {:ok, player_server} ->
        Process.monitor(player_server)

        data =
          Map.merge(data, %{
            player_id: bot_id,
            player_server: player_server,
            lobby_name: lobby_name,
            status: :idle
          })

        :ok = data.transport.send(data.socket, status_msg(data))
        {:next_state, :idle, data}

      {:error, :lobby_not_found} ->
        :ok = data.transport.send(data.socket, encode_error("lobby_not_found"))
        :keep_state_and_data
    end
  end

  def handle_event(:internal, %{"action" => "start_match_making"}, :idle, data) do
    :ok = PlayerServer.match_make(data.player_server)
    data = Map.put(data, :status, :match_making)
    :ok = data.transport.send(data.socket, status_msg(data))
    {:next_state, :match_making, data}
  end

  def handle_event(:info, {:game_request, game_info}, :match_making, data) do
    :ok = data.transport.send(data.socket, game_request(game_info))
    data = Map.put(data, :game_info, game_info)
    {:next_state, :game_acceptance, data}
  end

  def handle_event(
        :internal,
        %{"action" => action, "game_id" => id},
        :game_acceptance,
        %{game_info: %{game_id: id}} = data
      )
      when action in ["accept_game", "reject_game"] do
    case action do
      "accept_game" ->
        :ok = PlayerServer.accept_game(data.player_server, id)
        {:next_state, :playing, data}

      "reject_game" ->
        :ok = PlayerServer.reject_game(data.player_server, id)
        {:next_state, :idle, data}
    end
  end

  def handle_event(:info, {:moves_request, request}, :playing, data) do
    :ok = data.transport.send(data.socket, moves_request(request))
    data = Map.put(data, :moves_request, request)
    {:keep_state, data}
  end

  def handle_event(:info, {:game_cancelled, id}, _state, %{game_info: %{game_id: id}} = data) do
    {:ok, data} = teardown_game(data, id)
    {:next_state, :idle, data}
  end

  def handle_event(:info, {:DOWN, _, _, pid, _}, _state, %{player_server: pid} = data) do
    :ok = data.transport.send(data.socket, encode_error("bot_instance_failure"))
    :ok = data.transport.close(data.socket)
    {:stop, :normal}
  end

  def handle_event(:internal, _msg, _state, data) do
    :ok = data.transport.send(data.socket, encode_error("invalid_msg_sent"))
    :keep_state_and_data
  end

  defp teardown_game(data, game_id) do
    :ok = data.transport.send(data.socket, game_cancelled(game_id))
    {:ok, Map.drop(data, [:game_info])}
  end

  defp moves_request(request) do
    encode(%{"request_type" => "moves_request", "moves_request" => request})
  end

  defp game_request(game_info) do
    game_info = Map.take(game_info, [:acceptance_time, :game_id, :player])
    encode(%{"game_info" => game_info, "request_type" => "game_request"})
  end

  defp game_cancelled(game_id),
    do: encode(%{info: "game_cancelled", game_id: game_id})

  defp status_msg(data),
    do: encode(%{bot_id: data.player_id, lobby_name: data.lobby_name, status: data.status})

  defp initial_msg(connection_id), do: encode(%{connection_id: connection_id})
end