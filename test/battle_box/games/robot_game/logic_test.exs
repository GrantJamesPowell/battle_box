defmodule BattleBox.Games.RobotGame.LogicTest do
  use ExUnit.Case, async: true
  alias BattleBox.Games.RobotGame.Game
  import BattleBox.Games.RobotGame.Logic

  describe "apply_spawn/1" do
    test "it will create robots" do
      test_terrain = %{
        {0, 0} => :spawn,
        {1, 1} => :spawn
      }

      game = Game.new(terrain: test_terrain, spawn_per_player: 1)

      assert length(Game.robots(game)) == 0
      game = apply_spawn(game)
      assert length(Game.robots(game)) == 2

      assert [{0, 0}, {1, 1}] ==
               Game.robots(game)
               |> Enum.map(&Map.get(&1, :location))
               |> Enum.sort()

      assert game.players == Enum.map(game.robots, &Map.get(&1, :player_id)) |> Enum.sort()
    end

    test "it will destroy an existing robot on a spawn point" do
      test_terrain = %{
        {0, 0} => :spawn,
        {1, 1} => :spawn
      }

      robots = [
        %{player_id: "1", id: "DESTROY_ME_1", location: {0, 0}},
        %{player_id: "2", id: "DESTROY_ME_2", location: {1, 1}}
      ]

      robots =
        Game.new(terrain: test_terrain, spawn_per_player: 1)
        |> Game.add_robots(robots)
        |> apply_spawn()
        |> Game.robots()

      assert length(robots) == 2
      Enum.each(robots, fn robot -> refute robot.id in ["DESTROY_ME_1", "DESTROY_ME_2"] end)
    end
  end

  describe "apply_attack/3" do
    test "An attack on an empty square is a noop" do
      game = Game.new()
      assert ^game = apply_attack(game, {0, 0}, [])
    end

    test "An attack on an unguarded location yields full damage" do
      robot_location = {0, 0}
      robot = %{location: robot_location, player_id: "1", hp: 50, id: "TEST"}

      assert %{hp: 0} =
               Game.new(attack_damage: 50)
               |> Game.add_robot(robot)
               |> apply_attack(robot_location, [])
               |> Game.get_robot("TEST")
    end

    test "An attack on a guarded location yields half damage" do
      robot_location = {0, 0}
      robot = %{location: robot_location, player_id: "1", hp: 50, id: "TEST"}

      assert %{hp: 25} =
               Game.new(attack_damage: 50)
               |> Game.add_robot(robot)
               |> apply_attack(robot_location, [robot_location])
               |> Game.get_robot("TEST")
    end
  end

  describe "apply_suicide" do
    test "suicide inflicts damage on adjacent robots" do
      suicide_robot_location = {1, 1}
      affected_robots = [{2, 1}, {0, 1}, {1, 2}, {1, 0}]
      robot_locations = [suicide_robot_location | affected_robots]

      id = fn {x, y} -> "#{x},#{y}" end

      robots =
        robot_locations
        |> Enum.map(&%{player_id: "1", hp: 50, location: &1, id: id.(&1)})

      affected_robots_after_turn =
        Game.new(suicide_damage: 50)
        |> Game.add_robots(robots)
        |> apply_suicide(id.(suicide_robot_location), [])
        |> Game.robots()

      Enum.each(affected_robots_after_turn, fn robot ->
        assert robot.location in affected_robots
        assert robot.hp == 0
      end)
    end

    test "suicide in guarded locations yields half damage" do
      suicide_robot_location = {1, 1}
      affected_robots = [{2, 1}, {0, 1}, {1, 2}, {1, 0}]
      robot_locations = [suicide_robot_location | affected_robots]

      id = fn {x, y} -> "#{x},#{y}" end

      robots =
        robot_locations
        |> Enum.map(&%{player_id: "1", hp: 50, location: &1, id: id.(&1)})

      affected_robots_after_turn =
        Game.new(suicide_damage: 50)
        |> Game.add_robots(robots)
        |> apply_suicide(id.(suicide_robot_location), affected_robots)
        |> Game.robots()

      Enum.each(affected_robots_after_turn, fn robot ->
        assert robot.location in affected_robots
        assert robot.hp == 25
      end)
    end
  end
end
