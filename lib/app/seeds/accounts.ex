defmodule App.Seeds.Accounts do
  @moduledoc """
  Seeds user accounts from application configuration on startup.

  Reads the `:app, :accounts` config, which is a list of user entries
  (each a keyword list with `:email` and `:password`). For each entry,
  if no user with the given email exists, a new confirmed user is created
  with the given password.
  """

  require Logger

  alias App.Accounts
  alias App.Accounts.User
  alias App.Repo

  @doc """
  Seeds users from the `:app, :accounts` application config.

  Returns `:ok` after processing all entries.
  """
  def seed do
    :app
    |> Application.get_env(:accounts, [])
    |> List.wrap()
    |> Enum.each(&seed_user/1)
  end

  defp seed_user(nil), do: :ok

  defp seed_user(config) when is_list(config) do
    email = Keyword.get(config, :email)
    password = Keyword.get(config, :password)

    cond do
      is_nil(email) or email == "" ->
        Logger.warning("Seeds.Accounts: skipping entry with missing email")

      is_nil(password) or password == "" ->
        Logger.warning("Seeds.Accounts: skipping entry for #{email} with missing password")

      true ->
        create_user(email, password)
    end
  end

  defp create_user(email, password) do
    case Accounts.get_user_by_email(email) do
      nil ->
        result = register_and_set_password(email, password)
        log_create_result(result, email)
        result

      _user ->
        Logger.debug("Seeds.Accounts: user #{email} already exists, skipping")
        :ok
    end
  end

  defp register_and_set_password(email, password) do
    Repo.transact(fn ->
      with {:ok, user} <- Accounts.register_user(%{email: email}),
           {:ok, user} <- confirm_user(user),
           {:ok, {user, _tokens}} <-
             Accounts.update_user_password(user, %{password: password}) do
        {:ok, user}
      end
    end)
  end

  defp log_create_result({:ok, user}, _email) do
    Logger.info("Seeds.Accounts: created user #{user.email}")
  end

  defp log_create_result({:error, changeset}, email) do
    Logger.error("Seeds.Accounts: failed to create user #{email}: #{inspect(changeset.errors)}")
  end

  defp confirm_user(user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end
end
