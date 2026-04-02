defmodule App.Repo.Migrations.CreatePyreGithubApps do
  use Ecto.Migration

  def change do
    create table(:pyre_github_apps) do
      add :app_id, :string, null: false
      add :private_key, :text
      add :webhook_secret, :string
      add :client_id, :string
      add :client_secret, :string
      add :bot_slug, :string
      add :html_url, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pyre_github_apps, [:app_id])
  end
end
