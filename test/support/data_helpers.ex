defmodule BattleBox.Test.DataHelpers do
  alias BattleBox.{User, Repo}
  import Phoenix.ConnTest

  def signin(conn, opts \\ %{}) do
    opts = Enum.into(opts, %{})

    user =
      case opts do
        %{user: user} ->
          user

        %{} ->
          {:ok, user} = create_user(opts)
          user
      end

    conn
    |> init_test_session(token: "foo")
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  def create_user(opts \\ %{}) do
    user_id = opts[:user_id] || opts[:id] || Ecto.UUID.generate()

    User.changeset(%User{id: user_id}, %{
      github_id: :erlang.unique_integer([:positive]),
      github_avatar_url: "http://not-real.com",
      github_login_name: opts[:github_login_name] || "github_login_name:#{user_id}",
      is_banned: opts[:is_banned] || false,
      is_admin: opts[:is_admin] || false
    })
    |> Repo.insert()
  end
end
