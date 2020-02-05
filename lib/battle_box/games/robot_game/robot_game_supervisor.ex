defmodule BattleBox.Games.RobotGame.RobotGameSupervisor do
  alias BattleBox.Games.RobotGame.GameSupervisor, as: GameSup
  alias BattleBox.Games.RobotGame.PlayerSupervisor, as: PlayerSup
  alias BattleBox.Games.RobotGame.GameServer
  use Supervisor

  @default_name RobotGame

  def start_link(opts) do
    name = opts[:name] || @default_name
    Supervisor.start_link(__MODULE__, %{name: name}, name: name)
  end

  def init(%{name: name}) do
    children = [
      {PlayerSup, name: player_supervisor_name(name)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_game_server(%{player_1: _, player_2: _, game: _} = opts, name \\ @default_name) do
    DynamicSupervisor.start_child(game_supervisor_name(name), {GameServer, opts})
  end

  def game_supervisor_name(name \\ @default_name), do: Module.concat(name, GameSupervisor)
  def player_supervisor_name(name \\ @default_name), do: Module.concat(name, PlayerSupervisor)
  def matchmaker_name(name \\ @default_name), do: Module.concat(name, MatchMaker)
end
