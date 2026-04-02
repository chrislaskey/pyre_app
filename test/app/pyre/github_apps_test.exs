defmodule App.Pyre.GithubAppsTest do
  use App.DataCase

  alias App.Pyre.{GithubApp, GithubApps}
  import App.PyreFixtures

  describe "list/0" do
    test "returns empty list when no apps exist" do
      assert GithubApps.list() == []
    end

    test "returns all apps ordered by id" do
      app1 = github_app_fixture()
      app2 = github_app_fixture()

      assert [%GithubApp{id: id1}, %GithubApp{id: id2}] = GithubApps.list()
      assert id1 == app1.id
      assert id2 == app2.id
    end
  end

  describe "get/1" do
    test "returns the app with the given id" do
      app = github_app_fixture()
      assert %GithubApp{id: id} = GithubApps.get(app.id)
      assert id == app.id
    end

    test "returns nil for non-existent id" do
      assert GithubApps.get(-1) == nil
    end
  end

  describe "get_by/1" do
    test "returns the app matching the clauses" do
      app = github_app_fixture()
      assert %GithubApp{id: id} = GithubApps.get_by(app_id: app.app_id)
      assert id == app.id
    end

    test "returns nil when no match" do
      assert GithubApps.get_by(app_id: "nonexistent") == nil
    end
  end

  describe "create/1" do
    test "creates an app with valid attributes" do
      attrs = valid_github_app_attributes()
      assert {:ok, %GithubApp{} = app} = GithubApps.create(attrs)
      assert app.app_id == attrs.app_id
      assert app.private_key == attrs.private_key
      assert app.webhook_secret == attrs.webhook_secret
      assert app.bot_slug == attrs.bot_slug
    end

    test "requires app_id" do
      assert {:error, changeset} = GithubApps.create(%{})
      assert %{app_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique app_id" do
      app = github_app_fixture()
      assert {:error, changeset} = GithubApps.create(%{app_id: app.app_id})
      assert %{app_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update/2" do
    test "updates the app with valid attributes" do
      app = github_app_fixture()
      assert {:ok, updated} = GithubApps.update(app, %{bot_slug: "new-slug"})
      assert updated.bot_slug == "new-slug"
      assert updated.app_id == app.app_id
    end

    test "returns error changeset for invalid data" do
      app = github_app_fixture()
      other = github_app_fixture()
      assert {:error, changeset} = GithubApps.update(app, %{app_id: other.app_id})
      assert %{app_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "upsert/1" do
    test "inserts a new app" do
      attrs = valid_github_app_attributes()
      assert {:ok, %GithubApp{} = app} = GithubApps.upsert(attrs)
      assert app.app_id == attrs.app_id
    end

    test "updates an existing app on conflict" do
      app = github_app_fixture()
      new_slug = "updated-slug"

      assert {:ok, updated} =
               GithubApps.upsert(%{app_id: app.app_id, bot_slug: new_slug})

      assert updated.id == app.id
      assert updated.bot_slug == new_slug
    end
  end

  describe "delete/1" do
    test "deletes the app" do
      app = github_app_fixture()
      assert {:ok, %GithubApp{}} = GithubApps.delete(app)
      assert GithubApps.get(app.id) == nil
    end
  end
end
