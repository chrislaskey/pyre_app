defmodule App.Repo.Migrations.CreatePyreRuns do
  use Ecto.Migration

  def change do
    create table(:pyre_runs) do
      add :status, :string, null: false, default: "queued"
      add :run_id, :string, null: false
      add :description, :text, null: false
      add :workflow_type, :string, null: false
      add :workflow_params, :text
      add :connection_id, :string
      add :oban_job_id, :integer
      add :error, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :errored_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pyre_runs, [:run_id])
    create index(:pyre_runs, [:status])
  end
end
