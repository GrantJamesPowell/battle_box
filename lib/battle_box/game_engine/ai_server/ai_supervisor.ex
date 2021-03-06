defmodule BattleBox.GameEngine.AiServer.AiSupervisor do
  alias BattleBox.{GameEngine, GameEngine.AiServer}
  use DynamicSupervisor

  def start_link(%{names: names} = opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: names.ai_supervisor)
  end

  def init(opts) do
    init_arg = Map.take(opts, [:names])
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [init_arg])
  end

  def start_ai(game_engine, %{logic: _} = opts) do
    ai_supervisor = GameEngine.names(game_engine).ai_supervisor
    DynamicSupervisor.start_child(ai_supervisor, {AiServer, opts})
  end
end
