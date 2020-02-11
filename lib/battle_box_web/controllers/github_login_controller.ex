defmodule BattleBoxWeb.GithubLoginController do
  use BattleBoxWeb, :controller
  alias BattleBox.User

  def github_login(conn, _params) do
    state = make_state()

    conn
    |> put_session(:github_auth_state, state)
    |> redirect(external: authorization_url(conn, state))
  end

  def github_callback(conn, %{"code" => code, "state" => state}) do
    with {1, true} <- {1, state == get_session(conn, :github_auth_state)},
         {2, {:ok, access_token}} <- {2, token_exchange(code, state)},
         {3, {:ok, user}} <- {3, get_user(access_token)} do
      user = Map.put(user, "access_token", access_token)
      {:ok, user} = User.upsert_from_github(user)

      conn
      |> delete_session(:github_auth_state)
      |> put_session(:user_id, user.id)
      |> redirect(to: "/")
    else
      {1, false} ->
        raise "Invalid state param in github callback"
    end
  end

  defp get_user(access_token) do
    response =
      HTTPoison.get(github_api_user_url(), [
        {"Authorization", "token #{access_token}"},
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ])

    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, %{"id" => _, "name" => _}} = Jason.decode(body)
    end
  end

  defp token_exchange(code, state) do
    body =
      Jason.encode!(%{
        "client_id" => Keyword.fetch!(config(), :client_id),
        "client_secret" => Keyword.fetch!(config(), :client_secret),
        "code" => code,
        "state" => state
      })

    response =
      HTTPoison.post(github_access_token_url(), body, [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ])

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- response,
         {:ok, %{"access_token" => access_token}} <- Jason.decode(body) do
      {:ok, access_token}
    else
      {:ok, %{"error" => "bad_verification_code"}} ->
        raise "Invalid Verification Code"
    end
  end

  defp authorization_url(conn, state) do
    params =
      URI.encode_query(%{
        "state" => state,
        "redirect_uri" => Routes.github_login_url(conn, :github_callback),
        "client_id" => Keyword.fetch!(config(), :client_id)
      })

    "#{github_authorization_url()}?#{params}"
  end

  defp config do
    Application.fetch_env!(:battle_box, :github)
  end

  defp make_state do
    :crypto.strong_rand_bytes(32)
    |> Base.encode16()
    |> String.downcase()
  end

  defp github_authorization_url, do: "#{github_base_url()}/login/oauth/authorize"
  defp github_access_token_url, do: "#{github_base_url()}/login/oauth/access_token"
  defp github_api_user_url, do: "#{github_api_base_url()}/user"
  defp github_base_url, do: Process.get(:bypass) || "https://github.com"
  defp github_api_base_url, do: Process.get(:bypass) || "https://api.github.com"
end