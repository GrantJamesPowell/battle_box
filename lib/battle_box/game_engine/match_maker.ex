defmodule BattleBox.GameEngine.MatchMaker do
  use Supervisor
  alias BattleBox.{Arena, Bot, Game, GameEngine, GameEngine.MatchMakerServer}
  alias BattleBox.Games.AiOpponent

  @typep maybe_list(t) :: t | [t, ...]

  @spec human_vs_ai(atom(), %Arena{}, %Bot{}, opponents :: maybe_list(atom())) ::
          {:ok, %{human_server_id: Ecto.UUID.t(), game_id: Ecto.UUID.t()}}
  def human_vs_ai(game_engine, %Arena{} = arena, %Bot{} = human_bot, ai_mods) do
    [human_player | ai_players] = Enum.shuffle(Arena.players(arena))

    {:ok, human_player_pid, %{human_server_id: human_server_id}} =
      GameEngine.start_human(game_engine, %{})

    combatants =
      create_ai_servers(game_engine, ai_players, ai_mods)
      |> Map.put(human_player, %{bot: human_bot, pid: human_player_pid})

    game = start_game(game_engine, arena, combatants)
    {:ok, %{game_id: game.id, human_server_id: human_server_id}}
  end

  @spec practice_match(atom(), %Arena{}, %Bot{}, opponent :: AiOpponent.t(), pid :: pid()) ::
          {:ok, %{game_id: Ecto.UUID.t()}} | {:error, :no_opponent_matching}
  def practice_match(game_engine, %Arena{} = arena, %Bot{} = bot, opponent, pid \\ self()) do
    [bot_player | ai_players] = Enum.shuffle(Arena.players(arena))

    case AiOpponent.opponent_modules(arena.game_type, opponent) do
      {:ok, []} ->
        {:error, :no_opponent_matching}

      {:ok, ai_mods} ->
        combatants =
          create_ai_servers(game_engine, ai_players, ai_mods)
          |> Map.put(bot_player, %{bot: bot, pid: pid})

        game = start_game(game_engine, arena, combatants)
        {:ok, %{game_id: game.id}}
    end
  end

  @spec join_queue(atom(), String.t(), String.t(), pid()) :: :ok
  def join_queue(game_engine, arena_id, bot_id, pid \\ self())
      when is_atom(game_engine) do
    {:ok, _registry} =
      Registry.register(match_maker_registry_name(game_engine), arena_id, %{
        bot: bot_id,
        pid: pid
      })

    :ok
  end

  @spec queue_for_arena(atom(), String.t()) :: [%{enqueuer_pid: pid(), pid: pid(), bot: %Bot{}}]
  def queue_for_arena(game_engine, arena_id) do
    for {enqueuer_pid, match_details} <-
          Registry.lookup(match_maker_registry_name(game_engine), arena_id),
        do: Map.put(match_details, :enqueuer_pid, enqueuer_pid)
  end

  @spec arenas_with_queued_players(atom()) :: [Ecto.UUID.t()]
  def arenas_with_queued_players(game_engine) do
    Registry.select(match_maker_registry_name(game_engine), [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.uniq()
  end

  @spec dequeue_self(atom()) :: :ok
  def dequeue_self(game_engine) when is_atom(game_engine) do
    registry = match_maker_registry_name(game_engine)

    for key <- Registry.keys(registry, self()) do
      :ok = Registry.unregister(registry, key)
    end

    :ok
  end

  @spec dequeue_self(atom(), Ecto.UUID.t()) :: :ok
  def dequeue_self(game_engine, arena_id) when is_atom(game_engine) do
    :ok = Registry.unregister(match_maker_registry_name(game_engine), arena_id)
  end

  def start_link(%{names: names} = opts) do
    Supervisor.start_link(__MODULE__, opts, name: names.match_maker)
  end

  def init(%{names: names}) do
    children = [
      {MatchMakerServer, %{names: names}},
      {Registry, keys: :duplicate, name: names.match_maker_registry}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp create_ai_servers(game_engine, ai_players, ai_mods) when ai_mods != [] do
    for player <- ai_players, into: %{} do
      opponent_module = Enum.random(ai_mods)
      {:ok, bot} = Bot.system_bot(opponent_module.name)
      {:ok, ai_server} = GameEngine.start_ai(game_engine, %{logic: opponent_module})
      {player, %{bot: bot, pid: ai_server}}
    end
  end

  defp match_maker_registry_name(game_engine) do
    GameEngine.names(game_engine).match_maker_registry
  end

  defp start_game(game_engine, arena, combatants) do
    player_bot_mapping = Map.new(combatants, fn {player, %{bot: bot}} -> {player, bot} end)
    player_pid_mapping = Map.new(combatants, fn {player, %{pid: pid}} -> {player, pid} end)

    game = Game.build(arena, player_bot_mapping)
    {:ok, _pid} = GameEngine.start_game(game_engine, %{players: player_pid_mapping, game: game})

    game
  end
end
