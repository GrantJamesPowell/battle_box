defmodule BattleBoxWeb.Router do
  use BattleBoxWeb, :router
  alias BattleBox.User

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BattleBoxWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/login", PageController, :login

    scope "/" do
      pipe_through :require_logged_in

      get "/banned", PageController, :banned
      get "/logout", PageController, :logout
    end

    live("/live_games", GamesLiveLive)
    live("/games/:game_id", GameLive)
    live("/users/:user_id/bots", BotsLive)
    live("/bot_servers/:bot_server_id/follow", BotServerFollow)

    scope "/health" do
      get "/", HealthController, :health
      get "/database", HealthController, :db
      get "/info", HealthController, :info
    end

    scope "/auth" do
      get "/github/login", GithubLoginController, :github_login
      get "/github/callback", GithubLoginController, :github_callback
    end

    scope "/" do
      pipe_through :require_logged_in
      pipe_through :require_not_banned

      get "/connections", UserRedirectController, :connections
      get "/lobbies", UserRedirectController, :lobbies
      get "/bots", UserRedirectController, :bots
      get "/me", UserRedirectController, :users

      resources "/bots", BotController, only: [:create, :new]
      resources "/lobbies", LobbyController, only: [:create, :new]
    end

    live("/lobbies/:lobby_id", LobbyLive)
    resources "/bots", BotController, only: [:show]

    live("/users/:user_id/connections", ConnectionsLive)

    resources "/users", UserController, only: [:show] do
      resources "/lobbies", LobbyController, only: [:index]
    end
  end

  defp require_logged_in(conn, _) do
    case conn.assigns.user do
      %User{} -> conn
      nil -> conn |> redirect(to: "/login") |> halt()
    end
  end

  defp require_not_banned(conn, _) do
    case conn.assigns.user do
      %User{is_banned: true} -> conn |> redirect(to: "/banned") |> halt()
      _ -> conn
    end
  end

  defp fetch_user(conn, _) do
    with id when not is_nil(id) <- get_session(conn, "user_id"),
         %User{} = user <- User.get_by_id(id) do
      assign(conn, :user, user)
    else
      _ ->
        assign(conn, :user, nil)
    end
  end
end
