defmodule App.Pyre.GithubApps do
  @moduledoc """
  Context for managing GitHub App records.
  """

  import Ecto.Query, warn: false
  alias App.Repo
  alias App.Pyre.GithubApp

  def list do
    Repo.all(from g in GithubApp, order_by: [asc: g.id])
  end

  def get(id) do
    Repo.get(GithubApp, id)
  end

  def get_by(clauses) do
    Repo.get_by(GithubApp, clauses)
  end

  def create(attrs) do
    %GithubApp{}
    |> GithubApp.changeset(attrs)
    |> Repo.insert()
  end

  def update(%GithubApp{} = github_app, attrs) do
    github_app
    |> GithubApp.changeset(attrs)
    |> Repo.update()
  end

  def upsert(attrs) do
    %GithubApp{}
    |> GithubApp.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :app_id,
      returning: true
    )
  end

  def delete(%GithubApp{} = github_app) do
    Repo.delete(github_app)
  end
end
