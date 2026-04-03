defmodule AppWeb.UserSessionControllerTest do
  use AppWeb.ConnCase

  import App.AccountsFixtures
  alias App.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "POST /users/log-in - login code" do
    test "logs the user in", %{conn: conn, user: user} do
      {code, _hashed_code} = generate_user_login_code(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"code" => code, "email" => user.email}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {code, _hashed_code} = generate_user_login_code(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"code" => code, "email" => user.email},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully."

      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "redirects to login page when login code is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"code" => "000000", "email" => "test@example.com"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The code is invalid or it has expired."

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
