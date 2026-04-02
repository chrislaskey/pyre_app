defmodule AppWeb.UserLive.LoginTest do
  use AppWeb.ConnCase

  import Phoenix.LiveViewTest
  import App.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert html =~ "Continue"
    end
  end

  describe "user login" do
    test "sends verification code when credentials are valid", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form", user: %{email: user.email, password: valid_user_password()})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in/code")

      assert html =~ "We sent a verification code to your email."

      assert App.Repo.get_by!(App.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "shows error for invalid credentials", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        form(lv, "#login_form",
          user: %{email: "idonotexist@example.com", password: "wrongpassword1"}
        )
        |> render_submit()

      assert html =~ "Invalid email or password."
    end

    test "shows error for wrong password", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        form(lv, "#login_form", user: %{email: user.email, password: "wrongpassword1"})
        |> render_submit()

      assert html =~ "Invalid email or password."
      refute App.Repo.get_by(App.Accounts.UserToken, user_id: user.id, context: "login")
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "You need to reauthenticate"
      assert html =~ user.email
    end
  end
end
