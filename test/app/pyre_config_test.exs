defmodule App.PyreConfigTest do
  use App.DataCase, async: false

  alias App.Pyre.Config, as: PyreConfig
  alias App.Pyre.GithubApps

  import App.PyreFixtures

  setup do
    previous_apps = Application.get_env(:pyre, :github_apps)

    on_exit(fn ->
      if previous_apps do
        Application.put_env(:pyre, :github_apps, previous_apps)
      else
        Application.delete_env(:pyre, :github_apps)
      end
    end)

    Application.delete_env(:pyre, :github_apps)
    :ok
  end

  describe "update_github_app/1" do
    test "persists credentials to the database" do
      credentials = %{
        app_id: "99999",
        private_key: "pem-key",
        webhook_secret: "secret",
        bot_slug: "my-bot",
        client_id: "cid",
        client_secret: "csecret",
        html_url: "https://github.com/apps/my-bot"
      }

      assert :ok = PyreConfig.update_github_app(credentials)

      app = GithubApps.get_by(app_id: "99999")
      assert app.private_key == "pem-key"
      assert app.webhook_secret == "secret"
      assert app.bot_slug == "my-bot"
    end

    test "accepts string keys" do
      credentials = %{
        "app_id" => "88888",
        "bot_slug" => "string-bot"
      }

      assert :ok = PyreConfig.update_github_app(credentials)
      assert GithubApps.get_by(app_id: "88888")
    end

    test "upserts on duplicate app_id" do
      github_app_fixture(%{app_id: "77777", bot_slug: "old-slug"})

      assert :ok =
               PyreConfig.update_github_app(%{app_id: "77777", bot_slug: "new-slug"})

      app = GithubApps.get_by(app_id: "77777")
      assert app.bot_slug == "new-slug"
    end
  end

  describe "list_github_apps/0" do
    test "returns empty list when no apps exist anywhere" do
      assert PyreConfig.list_github_apps() == []
    end

    test "returns database apps" do
      github_app_fixture(%{app_id: "db-1"})
      github_app_fixture(%{app_id: "db-2"})

      result = PyreConfig.list_github_apps()
      ids = Enum.map(result, & &1[:app_id])
      assert "db-1" in ids
      assert "db-2" in ids
    end

    test "returns config apps" do
      Application.put_env(:pyre, :github_apps, [
        [app_id: "cfg-1", bot_slug: "bot-1"],
        [app_id: "cfg-2", bot_slug: "bot-2"]
      ])

      result = PyreConfig.list_github_apps()
      ids = Enum.map(result, & &1[:app_id])
      assert "cfg-1" in ids
      assert "cfg-2" in ids
    end

    test "merges DB and config apps, deduplicating by app_id" do
      github_app_fixture(%{app_id: "shared", bot_slug: "db-bot"})

      Application.put_env(:pyre, :github_apps, [
        [app_id: "shared", bot_slug: "config-bot"],
        [app_id: "config-only", bot_slug: "unique-bot"]
      ])

      result = PyreConfig.list_github_apps()
      ids = Enum.map(result, & &1[:app_id])
      assert "shared" in ids
      assert "config-only" in ids
      assert length(result) == 2

      shared = Enum.find(result, &(&1[:app_id] == "shared"))
      assert shared[:bot_slug] == "db-bot"
    end

    test "handles nil entries in config list" do
      Application.put_env(:pyre, :github_apps, [nil, [app_id: "valid"]])

      result = PyreConfig.list_github_apps()
      assert length(result) == 1
      assert hd(result)[:app_id] == "valid"
    end
  end
end
