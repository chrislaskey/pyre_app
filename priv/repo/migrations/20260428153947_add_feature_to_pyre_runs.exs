defmodule App.Repo.Migrations.AddFeatureToPyreRuns do
  use Ecto.Migration

  def change do
    alter table(:pyre_runs) do
      add :feature, :string
    end
  end
end
