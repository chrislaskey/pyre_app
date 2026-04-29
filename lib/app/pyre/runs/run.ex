defmodule App.Pyre.Run do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:queued, :dispatched, :running, :complete, :error, :stopped]

  schema "pyre_runs" do
    field :status, Ecto.Enum, values: @statuses, default: :queued
    field :run_id, :string
    field :description, :string
    field :workflow_type, :string
    field :workflow_params, :string
    field :feature, :string
    field :connection_id, :string
    field :oban_job_id, :integer
    field :error, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :errored_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :status,
      :run_id,
      :description,
      :workflow_type,
      :workflow_params,
      :feature,
      :connection_id,
      :oban_job_id,
      :error,
      :started_at,
      :completed_at,
      :errored_at
    ])
    |> validate_required([:run_id, :description, :workflow_type])
    |> unique_constraint(:run_id)
  end
end
