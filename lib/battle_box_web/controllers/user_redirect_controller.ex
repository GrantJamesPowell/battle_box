defmodule BattleBoxWeb.UserRedirectController do
  use BattleBoxWeb, :controller

  def lobbies(%{assigns: %{current_user: user}} = conn, _params) do
    redirect(conn, to: Routes.user_lobby_path(conn, :index, user.user_name))
  end

  def bots(%{assigns: %{current_user: user}} = conn, _params) do
    redirect(conn, to: Routes.live_path(conn, BattleBoxWeb.Bots, user.user_name))
  end

  def users(%{assigns: %{current_user: user}} = conn, _params) do
    redirect(conn, to: Routes.user_path(conn, :show, user.user_name))
  end
end
