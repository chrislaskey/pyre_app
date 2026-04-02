defmodule AppWeb.UserLive.LoginCodeTest do
  use AppWeb.ConnCase

  import Phoenix.LiveViewTest
  import App.AccountsFixtures

  alias App.Accounts

  setup do
    confirmed_user = user_fixture() |> set_password()
    %{confirmed_user: confirmed_user}
  end

  describe "Login code page" do
    test "redirects to login if no email in flash", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/code")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Please enter your email first."
    end

    test "full login flow with password and code", %{conn: conn, confirmed_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, lv, html} =
        form(lv, "#login_form", user: %{email: user.email, password: valid_user_password()})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in/code")

      assert html =~ "Enter your login code"
      assert html =~ user.email

      # Generate a fresh code since we can't reverse the hash from the first one
      code =
        extract_login_code(fn ->
          Accounts.deliver_login_instructions(user)
        end)

      form =
        form(lv, "#login_code_form", %{"user" => %{"code" => code, "email" => user.email}})

      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "shows error for invalid code", %{conn: conn, confirmed_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, lv, _html} =
        form(lv, "#login_form", user: %{email: user.email, password: valid_user_password()})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in/code")

      html =
        form(lv, "#login_code_form", %{"user" => %{"code" => "000000"}})
        |> render_submit()

      assert html =~ "The code is invalid or it has expired."
    end
  end
end
