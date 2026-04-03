defmodule AppWeb.UserManagementLiveTest do
  use AppWeb.ConnCase

  alias App.Accounts
  import Phoenix.LiveViewTest
  import App.AccountsFixtures

  describe "Index" do
    setup :register_and_log_in_user

    test "lists all users", %{conn: conn, user: user} do
      other_user = user_fixture(email: "other@example.com")

      {:ok, _lv, html} = live(conn, ~p"/admin/users")

      assert html =~ "Users"
      assert html =~ user.email
      assert html =~ other_user.email
    end

    test "navigates to new user page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv
      |> element(~s|a[href="/admin/users/new"]|)
      |> render_click()

      assert_redirect(lv, ~p"/admin/users/new")
    end

    test "navigates to show user page", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv
      |> element(~s|a[href="/admin/users/#{user.id}"]|, "Show")
      |> render_click()

      assert_redirect(lv, ~p"/admin/users/#{user}")
    end

    test "navigates to edit user page", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv
      |> element(~s|a[href="/admin/users/#{user.id}/edit"]|, "Edit")
      |> render_click()

      assert_redirect(lv, ~p"/admin/users/#{user}/edit")
    end

    test "redirects if user is not logged in", %{conn: _conn} do
      conn = build_conn()
      assert {:error, redirect} = live(conn, ~p"/admin/users")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end

  describe "Show" do
    setup :register_and_log_in_user

    test "displays user details", %{conn: conn} do
      user = user_fixture(email: "show-test@example.com")

      {:ok, _lv, html} = live(conn, ~p"/admin/users/#{user}")

      assert html =~ "show-test@example.com"
      assert html =~ "User ID: #{user.id}"
    end

    test "navigates to edit page", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}")

      lv
      |> element(~s|a[href="/admin/users/#{user.id}/edit"]|)
      |> render_click()

      assert_redirect(lv, ~p"/admin/users/#{user}/edit")
    end

    test "deletes user", %{conn: conn} do
      user = user_fixture(email: "delete-me@example.com")

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}")

      assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
               lv
               |> element(~s|button[phx-click="delete"]|)
               |> render_click()

      assert Accounts.get_user(user.id) == nil
    end

    test "navigates back to users list", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}")

      lv
      |> element(~s|a[href="/admin/users"]|, "Back to users")
      |> render_click()

      assert_redirect(lv, ~p"/admin/users")
    end

    test "redirects when user not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/users", flash: flash}}} =
               live(conn, ~p"/admin/users/-1")

      assert %{"error" => "User not found."} = flash
    end

    test "redirects if not logged in", %{conn: _conn} do
      conn = build_conn()
      user = user_fixture()
      assert {:error, redirect} = live(conn, ~p"/admin/users/#{user}")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end

  describe "New" do
    setup :register_and_log_in_user

    test "renders new user form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/users/new")

      assert html =~ "New User"
      assert html =~ "Create User"
    end

    test "validates form on change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")

      result =
        lv
        |> element("#user-form")
        |> render_change(%{"user" => %{"email" => "invalid"}})

      assert result =~ "must have the @ sign and no spaces"
    end

    test "creates user with valid data", %{conn: conn} do
      email = unique_user_email()
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")

      assert {:error, {:live_redirect, %{to: "/admin/users/" <> _}}} =
               lv
               |> form("#user-form", %{"user" => %{"email" => email}})
               |> render_submit()

      assert Accounts.get_user_by_email(email)
    end

    test "renders errors with invalid data on submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")

      result =
        lv
        |> form("#user-form", %{"user" => %{"email" => "invalid"}})
        |> render_submit()

      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors for duplicate email", %{conn: conn} do
      existing = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")

      result =
        lv
        |> form("#user-form", %{"user" => %{"email" => existing.email}})
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "navigates back to users list", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")

      lv
      |> element(~s|a[href="/admin/users"]|, "Back to users")
      |> render_click()

      assert_redirect(lv, ~p"/admin/users")
    end

    test "redirects if not logged in", %{conn: _conn} do
      conn = build_conn()
      assert {:error, redirect} = live(conn, ~p"/admin/users/new")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end

  describe "Edit" do
    setup :register_and_log_in_user

    setup %{conn: _conn} do
      user = user_fixture(email: "edit-target@example.com")
      %{target_user: user}
    end

    test "renders edit form with current email", %{conn: conn, target_user: user} do
      {:ok, _lv, html} = live(conn, ~p"/admin/users/#{user}/edit")

      assert html =~ "Edit User"
      assert html =~ "edit-target@example.com"
    end

    test "validates form on change", %{conn: conn, target_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}/edit")

      result =
        lv
        |> element("#user-form")
        |> render_change(%{"user" => %{"email" => "invalid"}})

      assert result =~ "must have the @ sign and no spaces"
    end

    test "updates user with valid data", %{conn: conn, target_user: user} do
      new_email = unique_user_email()
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}/edit")

      assert {:error, {:live_redirect, %{to: "/admin/users/" <> _}}} =
               lv
               |> form("#user-form", %{"user" => %{"email" => new_email}})
               |> render_submit()

      updated = Accounts.get_user(user.id)
      assert updated.email == new_email
    end

    test "succeeds when email is unchanged", %{conn: conn, target_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}/edit")

      assert {:error, {:live_redirect, %{to: "/admin/users/" <> _}}} =
               lv
               |> form("#user-form", %{"user" => %{"email" => user.email}})
               |> render_submit()

      assert Accounts.get_user(user.id).email == user.email
    end

    test "renders errors with invalid data on submit", %{conn: conn, target_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}/edit")

      result =
        lv
        |> form("#user-form", %{"user" => %{"email" => "invalid"}})
        |> render_submit()

      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors for duplicate email", %{conn: conn, target_user: user} do
      other = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}/edit")

      result =
        lv
        |> form("#user-form", %{"user" => %{"email" => other.email}})
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "navigates back to user show page", %{conn: conn, target_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user}/edit")

      lv
      |> element(~s|a[href="/admin/users/#{user.id}"]|, "Back to user")
      |> render_click()

      assert_redirect(lv, ~p"/admin/users/#{user}")
    end

    test "redirects when user not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/users", flash: flash}}} =
               live(conn, ~p"/admin/users/-1/edit")

      assert %{"error" => "User not found."} = flash
    end

    test "redirects if not logged in", %{conn: _conn} do
      conn = build_conn()
      user = user_fixture()
      assert {:error, redirect} = live(conn, ~p"/admin/users/#{user}/edit")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end
end
