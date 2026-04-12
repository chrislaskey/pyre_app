defmodule App.Pyre.RunTest do
  use App.DataCase

  alias App.Pyre.Run

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset =
        Run.changeset(%Run{}, %{
          run_id: "abc12345",
          description: "Build a login page",
          workflow_type: "feature"
        })

      assert changeset.valid?
    end

    test "invalid without run_id" do
      changeset =
        Run.changeset(%Run{}, %{
          description: "Build a login page",
          workflow_type: "feature"
        })

      refute changeset.valid?
      assert %{run_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without description" do
      changeset =
        Run.changeset(%Run{}, %{
          run_id: "abc12345",
          workflow_type: "feature"
        })

      refute changeset.valid?
      assert %{description: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without workflow_type" do
      changeset =
        Run.changeset(%Run{}, %{
          run_id: "abc12345",
          description: "Build a login page"
        })

      refute changeset.valid?
      assert %{workflow_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "defaults status to :queued" do
      changeset =
        Run.changeset(%Run{}, %{
          run_id: "abc12345",
          description: "Build a login page",
          workflow_type: "feature"
        })

      assert Ecto.Changeset.get_field(changeset, :status) == :queued
    end

    test "accepts all valid statuses" do
      for status <- [:queued, :dispatched, :running, :complete, :error, :stopped] do
        changeset =
          Run.changeset(%Run{}, %{
            run_id: "abc12345",
            description: "Build a login page",
            workflow_type: "feature",
            status: status
          })

        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "casts optional fields" do
      changeset =
        Run.changeset(%Run{}, %{
          run_id: "abc12345",
          description: "Build a login page",
          workflow_type: "feature",
          workflow_params: ~s({"workflow":"feature"}),
          connection_id: "worker-1",
          oban_job_id: 42,
          error: "something went wrong",
          started_at: ~U[2026-04-12 12:00:00Z],
          completed_at: ~U[2026-04-12 13:00:00Z],
          errored_at: ~U[2026-04-12 13:00:00Z]
        })

      assert changeset.valid?
    end

    test "enforces unique run_id constraint" do
      attrs = %{
        run_id: "unique123",
        description: "First run",
        workflow_type: "feature"
      }

      {:ok, _run} = %Run{} |> Run.changeset(attrs) |> Repo.insert()

      assert {:error, changeset} =
               %Run{}
               |> Run.changeset(%{attrs | description: "Second run"})
               |> Repo.insert()

      assert %{run_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
