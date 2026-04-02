defmodule App.Seeds.AccountsTest do
  use App.DataCase

  alias App.Accounts
  alias App.Seeds.Accounts, as: SeedsAccounts

  describe "seed/0" do
    test "creates a user when config has a valid entry" do
      email = "seed-test-#{System.unique_integer([:positive])}@example.com"
      password = "a_valid_password_123"

      Application.put_env(:app, :accounts, [[email: email, password: password]])

      SeedsAccounts.seed()

      user = Accounts.get_user_by_email(email)
      assert user
      assert user.confirmed_at
      assert Accounts.get_user_by_email_and_password(email, password)
    after
      Application.put_env(:app, :accounts, [])
    end

    test "skips creation when a user with the same email already exists" do
      email = "seed-existing-#{System.unique_integer([:positive])}@example.com"
      password = "a_valid_password_123"

      {:ok, existing_user} = Accounts.register_user(%{email: email})

      Application.put_env(:app, :accounts, [[email: email, password: password]])

      SeedsAccounts.seed()

      # User should be unchanged — not re-created or duplicated
      assert Accounts.get_user_by_email(email).id == existing_user.id
    after
      Application.put_env(:app, :accounts, [])
    end

    test "handles empty config" do
      Application.put_env(:app, :accounts, [])

      assert SeedsAccounts.seed() == :ok
    after
      Application.put_env(:app, :accounts, [])
    end

    test "handles nil entries in config list" do
      Application.put_env(:app, :accounts, [nil])

      assert SeedsAccounts.seed() == :ok
    after
      Application.put_env(:app, :accounts, [])
    end

    test "skips entry with missing email" do
      Application.put_env(:app, :accounts, [[password: "a_valid_password_123"]])

      assert SeedsAccounts.seed() == :ok
      # No crash, just a warning log
    after
      Application.put_env(:app, :accounts, [])
    end

    test "skips entry with missing password" do
      email = "seed-no-pw-#{System.unique_integer([:positive])}@example.com"

      Application.put_env(:app, :accounts, [[email: email]])

      SeedsAccounts.seed()

      refute Accounts.get_user_by_email(email)
    after
      Application.put_env(:app, :accounts, [])
    end

    test "skips entry with empty password" do
      email = "seed-empty-pw-#{System.unique_integer([:positive])}@example.com"

      Application.put_env(:app, :accounts, [[email: email, password: ""]])

      SeedsAccounts.seed()

      refute Accounts.get_user_by_email(email)
    after
      Application.put_env(:app, :accounts, [])
    end

    test "creates multiple users from config" do
      email1 = "seed-multi1-#{System.unique_integer([:positive])}@example.com"
      email2 = "seed-multi2-#{System.unique_integer([:positive])}@example.com"
      password = "a_valid_password_123"

      Application.put_env(:app, :accounts, [
        [email: email1, password: password],
        [email: email2, password: password]
      ])

      SeedsAccounts.seed()

      assert Accounts.get_user_by_email(email1)
      assert Accounts.get_user_by_email(email2)
    after
      Application.put_env(:app, :accounts, [])
    end
  end
end
