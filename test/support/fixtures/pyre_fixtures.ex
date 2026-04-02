defmodule App.PyreFixtures do
  @moduledoc """
  Test helpers for creating entities via the `App.Pyre.GithubApps` context.
  """

  alias App.Pyre.GithubApps

  def unique_app_id, do: "app-#{System.unique_integer([:positive])}"

  def valid_github_app_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      app_id: unique_app_id(),
      private_key: "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----",
      webhook_secret: "whsec_test_#{System.unique_integer([:positive])}",
      bot_slug: "test-bot-#{System.unique_integer([:positive])}"
    })
  end

  def github_app_fixture(attrs \\ %{}) do
    {:ok, app} =
      attrs
      |> valid_github_app_attributes()
      |> GithubApps.create()

    app
  end
end
