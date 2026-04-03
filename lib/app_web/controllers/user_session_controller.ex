defmodule AppWeb.UserSessionController do
  use AppWeb, :controller

  alias App.Accounts
  alias AppWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link token
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "Login link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # login code
  defp create(conn, %{"user" => %{"code" => code, "email" => email} = user_params}, info) do
    case Accounts.login_user_by_login_code(code, email) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The code is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params}) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> put_flash(:info, "Password updated successfully!")
    |> UserAuth.log_in_user(user, user_params)
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
