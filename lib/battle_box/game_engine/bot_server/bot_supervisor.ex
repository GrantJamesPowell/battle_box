defmodule BattleBox.GameEngine.BotServer.BotSupervisor do
  use DynamicSupervisor
  alias BattleBox.{ApiKey, Bot, Repo, GameEngine, GameEngine.BotServer}

  def start_link(%{names: names} = opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: names.bot_supervisor)
  end

  def init(opts) do
    init_arg = Map.take(opts, [:names])
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [init_arg])
  end

  def start_bot(
        game_engine,
        %{connection: connection, token: token, bot_name: bot_name}
      ) do
    with {:ok, user} <- ApiKey.authenticate(token),
         {:within_connection_limit?, true} <-
           {:within_connection_limit?, within_connection_limit?(game_engine, user)},
         {:bot, {:ok, bot}} <- {:bot, Bot.get_or_create_by_name(user, bot_name)} do
      start_bot(game_engine, %{connection: connection, bot: bot})
    else
      {:within_connection_limit?, false} ->
        {:error, %{user: ["User connection limit exceeded"]}}

      {:bot, {:error, %Ecto.Changeset{} = changeset}} ->
        {:error, %{bot: BattleBox.changeset_errors(changeset)}}

      {:error, errors} ->
        {:error, errors}
    end
  end

  def start_bot(game_engine, %{bot: %Bot{} = bot, connection: _} = opts) do
    bot = Repo.preload(bot, :user)
    bot_supervisor = GameEngine.names(game_engine).bot_supervisor
    opts = Map.put_new(opts, :bot_server_id, Ecto.UUID.generate())
    opts = update_in(opts.bot, fn bot -> Repo.preload(bot, :user) end)
    {:ok, bot_server} = DynamicSupervisor.start_child(bot_supervisor, {BotServer, opts})
    {:ok, bot_server, %{bot: bot, bot_server_id: opts.bot_server_id}}
  end

  def within_connection_limit?(game_engine, user) do
    number_connections =
      game_engine
      |> get_bot_servers_with_user_id(user.id)
      |> length

    number_connections < user.connection_limit
  end

  def get_bot_servers_with_bot_id(game_engine, bot_id) do
    bot_registry = GameEngine.names(game_engine).bot_registry
    get_from_registry(bot_registry, matches_bot_id(bot_id))
  end

  def get_bot_servers_with_user_id(game_engine, user_id) do
    bot_registry = GameEngine.names(game_engine).bot_registry
    get_from_registry(bot_registry, matches_user_id(user_id))
  end

  defp get_from_registry(registry, match_spec) do
    Registry.select(registry, match_spec)
    |> Enum.map(fn {bot_server_id, pid, attrs} ->
      Map.merge(attrs, %{bot_server_id: bot_server_id, pid: pid})
    end)
  end

  # As of this writing (Elixir 1.10.1) `Registry.select/1` does not accept match specs that use `:'$_'`
  # these match specs could be much more concisely written if `:'$_'` was available

  defp matches_user_id(user_id) do
    # :ets.fun2ms(fn {bot_server_id, pid, attrs} when :erlang.map_get(:user_id, :erlang.map_get(:bot, attrs)) == 2 ->
    #   {bot_server_id, pid, attrs}
    # end)

    [
      {{:"$1", :"$2", :"$3"}, [{:==, {:map_get, :user_id, {:map_get, :bot, :"$3"}}, user_id}],
       [{{:"$1", :"$2", :"$3"}}]}
    ]
  end

  defp matches_bot_id(bot_id) do
    # :ets.fun2ms(fn {bot_server_id, pid, attrs} when :erlang.map_get(:id, :erlang.map_get(:bot, attrs)) == 2 ->
    #   {bot_server_id, pid, attrs}
    # end)
    [
      {{:"$1", :"$2", :"$3"}, [{:==, {:map_get, :id, {:map_get, :bot, :"$3"}}, bot_id}],
       [{{:"$1", :"$2", :"$3"}}]}
    ]
  end
end
