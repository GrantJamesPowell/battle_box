defmodule BattleBox.Games.RobotGame.DamageIntegrationTest do
  use ExUnit.Case, async: true
  alias BattleBox.Games.RobotGame.{Game, Logic}

  @terrain %{
    {0, 0} => :normal,
    {0, 1} => :normal,
    {1, 1} => :normal,
    {1, 0} => :normal
  }

  setup do
    %{
      game:
        Game.new(
          terrain: @terrain,
          spawn?: false,
          attack_damage: 1,
          robot_hp: 10,
          suicide_damage: 5
        )
    }
  end

  test "If you attack a square a robot is in it takes damage", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}},
      %{id: "B", player_id: "B", location: {0, 1}}
    ]

    moves = [
      %{type: :noop, robot_id: "A"},
      %{type: :attack, target: {0, 0}, robot_id: "B"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert %{
             location: {0, 0},
             hp: 9
           } = Game.get_robot(after_turn, "A")
  end

  test "If you attack a robot that moves out of a square it takes not damage", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}},
      %{id: "B", player_id: "B", location: {0, 1}}
    ]

    moves = [
      %{type: :move, target: {1, 0}, robot_id: "A"},
      %{type: :attack, target: {0, 0}, robot_id: "B"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert %{
             location: {1, 0},
             hp: 10
           } = Game.get_robot(after_turn, "A")
  end

  test "If you move into a square being attacked you take damage", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}},
      %{id: "B", player_id: "B", location: {1, 1}}
    ]

    moves = [
      %{type: :attack, target: {1, 0}, robot_id: "B"},
      %{type: :move, target: {1, 0}, robot_id: "A"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert %{
             location: {1, 0},
             hp: 9
           } = Game.get_robot(after_turn, "A")
  end

  test "A robot can suffer multiple attacks", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}},
      %{id: "B", player_id: "B", location: {1, 0}},
      %{id: "C", player_id: "C", location: {0, 1}}
    ]

    moves = [
      %{type: :attack, target: {0, 0}, robot_id: "B"},
      %{type: :attack, target: {0, 0}, robot_id: "C"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert %{hp: 8} = Game.get_robot(after_turn, "A")
  end

  test "Trying to attack a non adjacent square does not work", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}},
      %{id: "B", player_id: "B", location: {1, 1}}
    ]

    moves = [
      %{type: :attack, target: {0, 0}, robot_id: "B"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert %{hp: 10} = Game.get_robot(after_turn, "A")
  end

  test "you can attack yourself I guess? ¯\_(ツ)_/¯", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}}
    ]

    moves = [
      %{type: :attack, target: {0, 0}, robot_id: "A"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert %{hp: 10} = Game.get_robot(after_turn, "A")
  end

  test "suicide removes the robot and damages adjacent squares", %{game: game} do
    robots = [
      %{id: "A", player_id: "A", location: {0, 0}},
      %{id: "B", player_id: "B", location: {1, 0}},
      %{id: "C", player_id: "C", location: {0, 1}},
      %{id: "D", player_id: "D", location: {1, 1}}
    ]

    moves = [
      %{type: :suicide, robot_id: "A"}
    ]

    inital_game = Game.add_robots(game, robots)
    after_turn = Logic.calculate_turn(inital_game, moves)

    assert nil == Game.get_robot(after_turn, "A")
    assert %{hp: 5} = Game.get_robot(after_turn, "B")
    assert %{hp: 5} = Game.get_robot(after_turn, "C")
    assert %{hp: 10} = Game.get_robot(after_turn, "D")
  end
end
