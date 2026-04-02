defmodule App.Pyre.GithubApp do
  use Ecto.Schema
  import Ecto.Changeset

  @fields ~w(app_id private_key webhook_secret client_id client_secret bot_slug html_url)a

  schema "pyre_github_apps" do
    field :app_id, :string
    field :private_key, :string
    field :webhook_secret, :string
    field :client_id, :string
    field :client_secret, :string
    field :bot_slug, :string
    field :html_url, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(github_app, attrs) do
    github_app
    |> cast(attrs, @fields)
    |> validate_required([:app_id])
    |> unique_constraint(:app_id)
  end
end
