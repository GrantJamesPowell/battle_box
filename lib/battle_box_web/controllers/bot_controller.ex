defmodule BattleBoxWeb.BotController do
  use BattleBoxWeb, :controller
  alias BattleBox.Bot

  def new(conn, _params) do
    changeset = Bot.changeset(%Bot{})
    render(conn, "new.html", user: conn.assigns.user, changeset: changeset)
  end

  def create(%{assigns: %{user: user}} = conn, %{"bot" => bot}) do
    params = Map.put(bot, "user_id", user.id)

    case Bot.create(params) do
      {:ok, bot} ->
        conn
        |> put_flash(:info, "Bot created successfully.")
        |> redirect(to: Routes.bot_path(conn, :show, bot.id))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    bot = Bot.get_by_id(id)
    render(conn, "show.html", bot: bot)
  end
end