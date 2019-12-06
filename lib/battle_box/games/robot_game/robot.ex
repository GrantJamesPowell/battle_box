defmodule BattleBox.Games.RobotGame.Robot do
  defstruct [:hp, :id, :player_id, :location]

  def new(%{hp: hp, player_id: player_id, location: location} = opts) do
    %__MODULE__{
      hp: hp,
      id: opts[:id] || Ecto.UUID.generate(),
      player_id: player_id,
      location: location
    }
  end

  def apply_damage(robot, damage) do
    %__MODULE__{
      robot
      | hp: robot.hp - damage
    }
  end
end