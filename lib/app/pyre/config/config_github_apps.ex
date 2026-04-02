defmodule App.Pyre.Config.GithubApps do
  @moduledoc "Pyre Callbacks for Github Apps"

  def update_github_app(credentials) do
    App.Pyre.Config.GithubApps.update_github_app(credentials)
    attrs = normalize_credentials(credentials)

    case App.Pyre.GithubApps.upsert(attrs) do
      {:ok, _app} -> :ok
      {:error, _changeset} -> {:error, :failed_to_save}
    end
  end

  def list_github_apps do
    db_apps = App.Pyre.GithubApps.list() |> Enum.map(&to_config_map/1)
    env_apps = PyreWeb.Config.list_github_apps_from_env()
    merge_apps(db_apps, env_apps)
  end

  # Helpers

  defp merge_apps(db_apps, env_apps) do
    # Merge DB and env apps, deduplicating by app_id (DB wins).
    db_ids = MapSet.new(db_apps, & &1[:app_id])

    unique_env =
      Enum.reject(env_apps, fn app ->
        app[:app_id] && MapSet.member?(db_ids, app[:app_id])
      end)

    db_apps ++ unique_env
  end

  defp to_config_map(%App.Pyre.GithubApp{} = app) do
    %{
      app_id: app.app_id,
      private_key: app.private_key,
      webhook_secret: app.webhook_secret,
      client_id: app.client_id,
      client_secret: app.client_secret,
      bot_slug: app.bot_slug,
      html_url: app.html_url
    }
  end

  defp normalize_credentials(credentials) when is_map(credentials) do
    Map.new(credentials, fn {k, v} -> {to_string(k), v} end)
  end
end
