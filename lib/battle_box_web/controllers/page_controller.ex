defmodule BattleBoxWeb.PageController do
  use BattleBoxWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", user: conn.assigns.user)
  end
end
