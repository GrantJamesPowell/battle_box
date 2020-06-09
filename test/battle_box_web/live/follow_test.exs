defmodule BattleBoxWeb.Live.FollowTest do
  use BattleBoxWeb.ConnCase, async: false
  alias BattleBoxWeb.Live.Follow
  import Phoenix.LiveViewTest

  @bot_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @lobby_id Ecto.UUID.generate()
  @game_id Ecto.UUID.generate()

  @bot %{name: "bot-name", id: @bot_id}
  @user %{username: "user-name", id: @user_id}
  @lobby %{name: "lobby-name", id: @lobby_id}

  @base %{"lobby" => nil, "bot" => nil, "user" => @user}

  @with_bot Map.merge(@base, %{"bot" => @bot})
  @with_lobby Map.merge(@base, %{"lobby" => @lobby})

  [
    {@base, "Waiting for a Game with User (user-name)"},
    {@with_bot, "Waiting for a Game with Bot (bot-name)"},
    {@with_lobby, "Waiting for a Game in Lobby (lobby-name)"}
  ]
  |> Enum.each(fn {session, expected} ->
    test "it displays the correct message: #{inspect(expected)}", context do
      {:ok, _view, html} =
        live_isolated(context.conn, Follow, session: unquote(Macro.escape(session)))

      assert html =~ unquote(expected)
    end
  end)

  redirect_cases = [
    {@base, "/games/#{@game_id}?follow[user]=user-name"},
    {@with_bot, "/games/#{@game_id}?follow[bot]=bot-name&follow[user]=user-name"},
    {@with_lobby, "/games/#{@game_id}?follow[lobby]=lobby-name&follow[user]=user-name"}
  ]

  for {session, expected} <- redirect_cases, msg <- [:game_started, :game_update] do
    test "it redirects correctly on #{msg} to #{expected}", context do
      {:ok, view, _html} =
        live_isolated(context.conn, Follow, session: unquote(Macro.escape(session)))

      send(view.pid, {:some_topic, unquote(msg), @game_id})
      assert_redirect(view, unquote(expected))
    end
  end
end
