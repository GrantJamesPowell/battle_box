defmodule BattleBox.Games.RobotGame.Ais.StrategyTest do
  use ExUnit.Case, async: true
  import BattleBox.Games.RobotGame.Ais.Strategy.{Utilites, Moves}
  import BattleBox.Games.RobotGame.Settings.Terrain.Helpers

  @terrain ~t/1 1
              1 1/

  describe "towards/2" do
    test "Terrain does the right thing" do
      assert towards([0, 0], [0, 1], @terrain) == [0, 1]
      assert towards([0, 0], [0, 2], @terrain) == [0, 1]
      assert towards([0, 0], [1, 0], @terrain) == [1, 0]
      assert towards([0, 0], [2, 0], @terrain) == [1, 0]
      assert towards([0, 0], [0, 0], @terrain) == [0, 0]
    end
  end

  describe "manhattan_distance/2" do
    test "You can pass robots to it" do
      assert manhattan_distance(%{location: [0, 0]}, %{location: [3, 4]}) == 5.0
    end
  end

  describe "moves" do
    test "generate the correct moves" do
      assert guard(%{id: 1}) == %{"type" => "guard", "robot_id" => 1}
      assert explode(%{id: 1}) == %{"type" => "explode", "robot_id" => 1}
      assert move(%{id: 1}, [1, 2]) == %{"type" => "move", "robot_id" => 1, "target" => [1, 2]}

      assert attack(%{id: 1}, [1, 2]) == %{
               "type" => "attack",
               "robot_id" => 1,
               "target" => [1, 2]
             }

      assert attack(%{id: 1}, %{location: [1, 2]}) == %{
               "type" => "attack",
               "robot_id" => 1,
               "target" => [1, 2]
             }
    end
  end
end
