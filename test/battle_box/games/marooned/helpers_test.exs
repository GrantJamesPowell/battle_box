defmodule BattleBox.Games.Marooned.HelpersTest do
  use ExUnit.Case, async: true
  alias BattleBox.Games.Marooned

  import BattleBox.Games.Marooned.Helpers

  test "it works" do
    assert game_data = ~m/0 1 0
         x 0 x
         0 x 0
         0 2 0/

    assert game_data.rows == 4
    assert game_data.cols == 3
  end

  describe "errors" do
    test "its an error not to have both players on the board" do
      assert_raise(RuntimeError, fn ->
        ~m/0 0 0
         0 0 0
         0 0 0/
      end)
    end

    test "its an error to have non uniform length or height" do
      %{message: message} =
        assert_raise(RuntimeError, fn ->
          ~m/0 1 0 0
           0 0 0
           0 2 0/
        end)

      assert message =~ "Invalid Dimensions"

      %{message: message} =
        assert_raise(RuntimeError, fn ->
          ~m/0 1 0
           0 0 0
           0 2 0
           0 /
        end)

      assert message =~ "Invalid Dimensions"
    end
  end
end
