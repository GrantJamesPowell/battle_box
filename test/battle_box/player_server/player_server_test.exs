defmodule BattleBox.PlayerServerTest do
  use BattleBox.DataCase, async: false
  alias BattleBox.{GameEngine, MatchMaker, PlayerServer, Repo, Lobby}
  import BattleBox.TestConvenienceHelpers, only: [named_proxy: 1]
  alias BattleBox.Games.RobotGame.Game

  @player_1_id Ecto.UUID.generate()
  @player_2_id Ecto.UUID.generate()

  @player_1_server_id Ecto.UUID.generate()
  @player_2_server_id Ecto.UUID.generate()

  setup %{test: name} do
    {:ok, _} = GameEngine.start_link(name: name)
    {:ok, GameEngine.names(name)}
  end

  setup do
    %{
      init_opts_p1: %{
        player_id: @player_1_id,
        player_server_id: @player_1_server_id,
        connection: named_proxy(:p1_connection)
      },
      init_opts_p2: %{
        player_id: @player_2_id,
        player_server_id: @player_2_server_id,
        connection: named_proxy(:p2_connection)
      }
    }
  end

  setup context do
    {:ok, p1_server} = GameEngine.start_player(context.game_engine, context.init_opts_p1)
    {:ok, p2_server} = GameEngine.start_player(context.game_engine, context.init_opts_p2)
    Process.monitor(p1_server)
    Process.monitor(p2_server)
    %{p1_server: p1_server, p2_server: p2_server}
  end

  setup do
    changeset = Lobby.changeset(%Lobby{}, %{name: "LOBBY NAME", game_type: Game})
    {:ok, lobby} = Repo.insert(changeset)
    %{lobby: lobby}
  end

  test "you can start the player server", context do
    assert Process.alive?(context.p1_server)
    assert Process.alive?(context.p2_server)
  end

  test "The player server dies if the connection dies", %{p1_server: p1} = context do
    Process.flag(:trap_exit, true)
    p1_conn = context.init_opts_p1.connection
    Process.exit(p1_conn, :kill)
    assert_receive {:EXIT, ^p1_conn, :killed}
    assert_receive {:DOWN, _, _, ^p1, :normal}
  end

  test "the player server registers in the player server registry",
       %{p1_server: p1, p2_server: p2} = context do
    assert Registry.count(context.player_registry) == 2

    assert [{^p1, %{player_id: @player_1_id}}] =
             Registry.lookup(context.player_registry, context.init_opts_p1.player_server_id)

    assert [{^p2, %{player_id: @player_2_id}}] =
             Registry.lookup(context.player_registry, context.init_opts_p2.player_server_id)
  end

  describe "Matchmaking in a lobby" do
    test "You can ask the game server to join a matchmaking lobby", %{p1_server: p1} = context do
      assert [] == MatchMaker.queue_for_lobby(context.game_engine, context.lobby.id)

      :ok = PlayerServer.join_lobby(p1, context.lobby.name)
      :ok = PlayerServer.match_make(context.p1_server)

      assert [%{player_id: @player_1_id, pid: ^p1}] =
               MatchMaker.queue_for_lobby(context.game_engine, context.lobby.id)
    end

    test "its an error to ask to join a lobby that doesn't exist", context do
      assert {:error, :lobby_not_found} =
               PlayerServer.join_lobby(context.p1_server, "DOES NOT EXIST")
    end

    test "its an error to ask to match_make without being in a lobby", context do
      assert {:error, :not_in_lobby} = PlayerServer.match_make(context.p1_server)
    end

    test "its an error to try to join another lobby while in one", context do
      :ok = PlayerServer.join_lobby(context.p1_server, context.lobby.name)

      assert {:error, :already_in_lobby} =
               PlayerServer.join_lobby(context.p1_server, context.lobby.name)

      assert {:error, :already_in_lobby} = PlayerServer.join_lobby(context.p1_server, "FOO")
    end

    test "When a match is made it forwards the request to the connections", context do
      :ok = PlayerServer.join_lobby(context.p1_server, context.lobby.name)
      :ok = PlayerServer.match_make(context.p1_server)

      :ok = PlayerServer.join_lobby(context.p2_server, context.lobby.name)
      :ok = PlayerServer.match_make(context.p2_server)

      :ok = GameEngine.force_match_make(context.game_engine)
      assert_receive {:p1_connection, {:game_request, %{game_id: game_id}}}
      assert_receive {:p2_connection, {:game_request, %{game_id: ^game_id}}}
    end
  end

  test "players reject game requests they're not expecting", context do
    game_id = Ecto.UUID.generate()
    game_server = named_proxy(:game_server)

    send(
      context.p1_server,
      {:game_request, %{game_id: game_id, game_server: game_server, player: :player_1}}
    )

    assert_receive {:game_server, {:"$gen_cast", {:reject_game, :player_1}}}
  end

  describe "game acceptance" do
    setup context do
      :ok = PlayerServer.join_lobby(context.p1_server, context.lobby.name)
      :ok = PlayerServer.match_make(context.p1_server)

      :ok = PlayerServer.join_lobby(context.p2_server, context.lobby.name)
      :ok = PlayerServer.match_make(context.p2_server)

      :ok = GameEngine.force_match_make(context.game_engine)
    end

    test "if you accept a game and it gets cancelled you go to matchmaking", context do
      assert_receive {:p1_connection, {:game_request, %{game_id: game_id}}}
      :ok = PlayerServer.accept_game(context.p1_server, game_id)
      :ok = PlayerServer.reject_game(context.p2_server, game_id)
      assert_receive {:p1_connection, {:game_cancelled, ^game_id}}
    end

    test "if the other player dies you get a game cancelled", context do
      Process.flag(:trap_exit, true)
      assert_receive {:p1_connection, {:game_request, %{game_id: game_id}}}
      :ok = PlayerServer.accept_game(context.p1_server, game_id)
      Process.exit(context.p2_server, :kill)
      assert_receive {:p1_connection, {:game_cancelled, ^game_id}}
    end

    test "if the game dies you both get a game cancelled", context do
      assert_receive {:p1_connection, {:game_request, %{game_id: game_id}}}
      [{game_server_pid, _}] = Registry.lookup(context.game_registry, game_id)
      Process.exit(game_server_pid, :kill)
      assert_receive {:p1_connection, {:game_cancelled, ^game_id}}
      assert_receive {:p2_connection, {:game_cancelled, ^game_id}}
    end

    # test "you can accept a game", context do
    #  assert_receive {:p1_connection, {:game_request, %{game_id: game_id}}}
    #  assert_receive {:p2_connection, {:game_request, %{game_id: ^game_id}}}
    #  :ok = PlayerServer.accept_game(context.p1_server, game_id)
    #  :ok = PlayerServer.accept_game(context.p2_server, game_id)
    #  assert_receive {:p1_connections, {:input_request, :foo}}
    #  assert_receive {:p2_connections, {:input_request, :foo}}
    # end
  end
end
