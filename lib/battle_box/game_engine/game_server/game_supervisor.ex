defmodule BattleBox.GameEngine.GameServer.GameSupervisor do
  use DynamicSupervisor
  alias BattleBox.GameEngine.GameServer

  @select_all [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]

  def start_link(%{names: names} = opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: names.game_supervisor)
  end

  def init(opts) do
    init_arg = Map.take(opts, [:names])
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [init_arg])
  end

  def start_game(game_supervisor, %{players: _, game: _} = opts) do
    DynamicSupervisor.start_child(game_supervisor, {GameServer, opts})
  end

  def get_live_games(game_registry) do
    Registry.select(game_registry, @select_all)
    |> Enum.map(fn {game_id, pid, attrs} ->
      Map.merge(attrs, %{game_id: game_id, pid: pid})
    end)
  end
end