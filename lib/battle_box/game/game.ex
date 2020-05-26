defmodule BattleBox.Game do
  defmodule GameType do
    use Ecto.Type
    import BattleBox.InstalledGames

    def type, do: :string

    for game <- installed_games() do
      def cast(unquote("#{game.name}")), do: {:ok, unquote(game)}
      def cast(unquote(game)), do: {:ok, unquote(game)}
      def load(unquote("#{game.name}")), do: {:ok, unquote(game)}
      def dump(unquote(game)), do: {:ok, unquote("#{game.name}")}
    end
  end

  use Ecto.Schema
  import Ecto.Changeset
  import BattleBox.InstalledGames
  alias BattleBox.{Lobby, Bot, GameBot}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "games" do
    belongs_to :lobby, Lobby
    has_many :game_bots, GameBot
    many_to_many :bots, Bot, join_through: "game_bots"

    field :game_type, GameType

    for game_type <- installed_games() do
      has_one(game_type.name, game_type)
    end

    timestamps()
  end

  def game_data(game) do
    Map.get(game, game.game_type.name)
  end

  def calculate_turn(game, commands) do
    game = update_game_data(game, &BattleBoxGame.calculate_turn(&1, commands))
    scores = score(game)
    winner = winner(game)

    update_in(game.game_bots, fn bots ->
      for bot <- bots,
          do: %{
            bot
            | score: scores[bot.player],
              winner: winner == bot.player
          }
    end)
  end

  def changeset(game, params \\ %{}) do
    game
    |> cast(params, :game_type)
    |> validate_inclusion(:game_type, installed_games())
    |> cast_assoc(:game_bots)
    |> cast_assoc(game.game_type.name)
  end

  def initialize(game) do
    update_game_data(game, &BattleBoxGame.initialize/1)
  end

  def score(game) do
    game |> game_data |> BattleBoxGame.score()
  end

  def winner(game) do
    game |> game_data |> BattleBoxGame.winner()
  end

  def commands_requests(game) do
    game |> game_data |> BattleBoxGame.commands_requests()
  end

  def over?(game) do
    game |> game_data |> BattleBoxGame.over?()
  end

  def disqualify(game, player) do
    update_game_data(game, &BattleBoxGame.disqualify(&1, player))
  end

  def settings(game) do
    game |> game_data() |> BattleBoxGame.settings()
  end

  def metadata_only(game) do
    Map.drop(game, [game.game_type.name])
  end

  defp update_game_data(game, fun) do
    new_game_data =
      game
      |> game_data()
      |> fun.()

    Map.put(game, game.game_type.name, new_game_data)
  end
end
