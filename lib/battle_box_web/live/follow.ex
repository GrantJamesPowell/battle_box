defmodule BattleBoxWeb.Live.Follow do
  use BattleBoxWeb, :live_view
  alias BattleBox.GameEngine
  alias BattleBoxWeb.FollowView

  def mount(_params, session, socket) do
    if connected?(socket) do
      case session do
        %{"arena" => %{id: id}} ->
          GameEngine.subscribe_to_arena_events(game_engine(), id, [:game_started, :game_update])

        %{"bot" => %{id: id}} ->
          GameEngine.subscribe_to_bot_events(game_engine(), id, [:game_started, :game_update])

        %{"user" => %{id: id}} ->
          GameEngine.subscribe_to_user_events(game_engine(), id, [:game_started, :game_update])
      end
    end

    {:ok, assign(socket, follow_params: session)}
  end

  def handle_info({_topic, event, game_id}, socket) when event in [:game_update, :game_started] do
    keep_following =
      case socket.assigns.follow_params do
        %{"arena" => %{name: name}, "user" => %{username: username}} ->
          %{arena: name, user: username}

        %{"bot" => %{name: name}, "user" => %{username: username}} ->
          %{bot: name, user: username}

        %{"user" => %{username: username}} ->
          %{user: username}
      end

    {:noreply,
     redirect(socket,
       to: Routes.game_path(socket, :show, game_id, %{follow: keep_following})
     )}
  end

  def render(assigns) do
    FollowView.render("_follow.html", assigns)
  end
end
