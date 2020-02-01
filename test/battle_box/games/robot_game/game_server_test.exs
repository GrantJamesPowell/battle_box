defmodule BattleBox.Games.RobotGame.GameServerTest do
  alias BattleBox.Games.RobotGame.{Game, GameServer}
  use BattleBox.DataCase

  @player_1 Ecto.UUID.generate()
  @player_2 Ecto.UUID.generate()

  test "you can start the game server" do
    {:ok, pid} =
      GameServer.start_link(%{
        player_1: self(),
        player_2: self(),
        game: Game.new(player_1: @player_1, player_2: @player_2)
      })

    assert Process.alive?(pid)
  end

  test "the starting of the game server will send init messages to p1 & p2" do
    game = Game.new(player_1: @player_1, player_2: @player_2)

    {:ok, pid} =
      GameServer.start_link(%{
        player_1: named_proxy(:player_1),
        player_2: named_proxy(:player_2),
        game: game
      })

    expected = %{
      game_server: pid,
      game_id: game.id,
      settings: %{
        spawn_every: game.spawn_every,
        spawn_per_player: game.spawn_per_player,
        robot_hp: game.robot_hp,
        attack_damage: game.attack_damage,
        collision_damage: game.collision_damage,
        terrain: game.terrain,
        game_acceptance_timeout_ms: game.game_acceptance_timeout_ms,
        move_timeout_ms: game.move_timeout_ms
      }
    }

    expected_p1 = {:player_1, {:game_request, Map.put(expected, :player, :player_1)}}
    expected_p2 = {:player_2, {:game_request, Map.put(expected, :player, :player_2)}}

    assert_receive ^expected_p1
    assert_receive ^expected_p2
  end

  describe "failure to accept game" do
    test "if a player rejects the game both get a cancelled message" do
      game = Game.new(player_1: @player_1, player_2: @player_2)

      {:ok, pid} =
        GameServer.start_link(%{
          player_1: named_proxy(:player_1),
          player_2: named_proxy(:player_2),
          game: game
        })

      ref = Process.monitor(pid)

      assert :ok = GameServer.accept_game(pid, :player_1)
      assert :ok = GameServer.reject_game(pid, :player_2)

      game_id = game.id

      assert_receive {:player_1, {:game_cancelled, ^game_id}}
      assert_receive {:player_2, {:game_cancelled, ^game_id}}
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end

  test "When you accept a game it asks you for moves" do
    game = Game.new(player_1: @player_1, player_2: @player_2)
    game_id = game.id

    {:ok, pid} =
      GameServer.start_link(%{
        player_1: named_proxy(:player_1),
        player_2: named_proxy(:player_2),
        game: game
      })

    :ok = GameServer.accept_game(pid, :player_1)
    :ok = GameServer.accept_game(pid, :player_2)

    assert_receive {:player_1,
                    {:moves_request, %{game_id: ^game_id, turn: 0, robots: [], player: :player_1}}}

    assert_receive {:player_2,
                    {:moves_request, %{game_id: ^game_id, turn: 0, robots: [], player: :player_2}}}
  end

  test "if you forefit, you get a game over message and the other player is set as the winner" do
    game = Game.new(player_1: @player_1, player_2: @player_2)

    {:ok, pid} =
      GameServer.start_link(%{
        player_1: named_proxy(:player_1),
        player_2: named_proxy(:player_2),
        game: game
      })

    :ok = GameServer.accept_game(pid, :player_1)
    :ok = GameServer.accept_game(pid, :player_2)
    :ok = GameServer.forfeit_game(pid, :player_1)

    assert_receive {:player_1, {:game_over, %{game: %{winner: @player_2}}}}
    assert_receive {:player_2, {:game_over, %{game: %{winner: @player_2}}}}
  end

  test "you can play a game! (and it persists it to the db when you're done)" do
    game = Game.new(player_1: @player_1, player_2: @player_2, max_turns: 10)

    {:ok, pid} =
      GameServer.start_link(%{
        player_1: named_proxy(:player_1),
        player_2: named_proxy(:player_2),
        game: game
      })

    ref = Process.monitor(pid)

    assert_receive {:player_1, {:game_request, %{game_server: ^pid, player: :player_1}}}
    assert_receive {:player_2, {:game_request, %{game_server: ^pid, player: :player_2}}}

    assert :ok = GameServer.accept_game(pid, :player_1)
    assert :ok = GameServer.accept_game(pid, :player_2)

    Enum.each(0..9, fn turn ->
      receive do:
                ({:player_1, {:moves_request, %{turn: ^turn}}} ->
                   GameServer.submit_moves(pid, :player_1, turn, []))

      receive do:
                ({:player_2, {:moves_request, %{turn: ^turn}}} ->
                   GameServer.submit_moves(pid, :player_2, turn, []))
    end)

    assert_receive {:player_1, {:game_over, %{game: game}}}
    assert_receive {:player_2, {:game_over, %{game: ^game}}}
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    loaded_game = Game.get_by_id(game.id)
    assert Enum.map(loaded_game.events, & &1.effects) == Enum.map(game.events, & &1.effects)
  end

  defp named_proxy(name) do
    me = self()

    spawn_link(fn ->
      Stream.repeatedly(fn -> nil end)
      |> Enum.each(fn _ ->
        receive do
          x -> send(me, {name, x})
        end
      end)
    end)
  end
end