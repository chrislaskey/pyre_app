defmodule AppWeb.UserLive.LoginCodeTest do
  use AppWeb.ConnCase

  import Phoenix.LiveViewTest
  import App.AccountsFixtures

  alias App.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), confirmed_user: user_fixture()}
  end

  describe "Login code page" do
    test "redirects to login if no email in flash", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/code")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Please enter your email first."
    end

    test "renders code entry form for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      code =
        extract_login_code(fn ->
          Accounts.deliver_login_instructions(user, "http://localhost/users/log-in/code")
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in/code")

      assert html =~ "Enter your login code"
      assert html =~ user.email

      form =
        form(lv, "#login_code_form", %{"user" => %{"code" => code, "email" => user.email}})

      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User confirmed successfully"

      assert Accounts.get_user!(user.id).confirmed_at
      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "renders code entry form for confirmed user", %{conn: conn, confirmed_user: user} do
      code =
        extract_login_code(fn ->
          Accounts.deliver_login_instructions(user, "http://localhost/users/log-in/code")
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in/code")

      assert html =~ "Enter your login code"

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
      _code =
        extract_login_code(fn ->
          Accounts.deliver_login_instructions(user, "http://localhost/users/log-in/code")
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, lv, _html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in/code")

      html =
        form(lv, "#login_code_form", %{"user" => %{"code" => "000000"}})
        |> render_submit()

      assert html =~ "The code is invalid or it has expired."
    end
  end
end
