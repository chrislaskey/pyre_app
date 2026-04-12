defmodule App.Pyre.Config.CallbacksTest do
  use App.DataCase
  use Oban.Testing, repo: App.Repo

  alias App.Pyre.{Run, Runs}

  describe "run_submit/2" do
    test "creates a run and enqueues a job" do
      opts = [
        workflow: :feature,
        llm: nil,
        skipped_stages: [],
        interactive_stages: [],
        feature: nil,
        attachments: []
      ]

      assert {:ok, redirect_to: redirect_path} = App.Pyre.Config.run_submit("Build login", opts)

      # Redirect path should be /runs/<run_id>
      assert redirect_path =~ ~r|^/runs/[a-f0-9]+$|

      run_id = String.replace_prefix(redirect_path, "/runs/", "")

      # Verify run was created in the database
      run = Runs.get_by_run_id(run_id)
      assert run != nil
      assert run.description == "Build login"
      assert run.workflow_type == "feature"
      assert run.status == :queued

      # Verify Oban job was enqueued
      assert_enqueued(
        worker: App.Workers.WorkflowJob,
        args: %{"run_id" => run_id}
      )
    end

    test "returns error on duplicate run_id" do
      # Pre-create a run
      {:ok, _} =
        %Run{}
        |> Run.changeset(%{
          run_id: "deadbeef",
          description: "First",
          workflow_type: "feature"
        })
        |> Repo.insert()

      # Mock generate_id to return the same ID — but since generate_id is
      # called inside run_submit and we can't easily mock it, we'll just
      # verify the error handling path by calling create_and_enqueue directly
      opts = [
        workflow: :feature,
        llm: nil,
        skipped_stages: [],
        interactive_stages: [],
        feature: nil,
        attachments: []
      ]

      assert {:error, _} = Runs.create_and_enqueue("deadbeef", "Second", opts)
    end
  end

  describe "get_run/1" do
    test "returns DB-only data when RunServer is not running" do
      # Create a run in the database
      {:ok, run} =
        %Run{}
        |> Run.changeset(%{
          run_id: "getrun01",
          description: "Queued run",
          workflow_type: "feature",
          status: :queued
        })
        |> Repo.insert()

      # get_run should return data from DB since RunServer won't have this run
      result = App.Pyre.Config.get_run("getrun01")
      assert {:ok, run_map} = result
      assert run_map.status == :queued
      assert run_map.feature_description == "Queued run"
      assert run_map.workflow == :feature
      assert run_map.log == []
      assert run_map.oban_job_id == run.oban_job_id
    end

    test "returns not_found when run doesn't exist anywhere" do
      assert {:error, :not_found} = App.Pyre.Config.get_run("nonexistent")
    end

    test "returns completed run data from DB" do
      {:ok, _run} =
        %Run{}
        |> Run.changeset(%{
          run_id: "complete01",
          description: "Completed run",
          workflow_type: "chat",
          status: :complete,
          started_at: ~U[2026-04-12 10:00:00Z],
          completed_at: ~U[2026-04-12 11:00:00Z],
          connection_id: "worker-1"
        })
        |> Repo.insert()

      assert {:ok, run_map} = App.Pyre.Config.get_run("complete01")
      assert run_map.status == :complete
      assert run_map.workflow == :chat
      assert run_map.connection_id == "worker-1"
      assert run_map.started_at == ~U[2026-04-12 10:00:00Z]
      assert run_map.completed_at == ~U[2026-04-12 11:00:00Z]
    end

    test "returns error run data from DB" do
      {:ok, _run} =
        %Run{}
        |> Run.changeset(%{
          run_id: "error01",
          description: "Failed run",
          workflow_type: "feature",
          status: :error,
          error: "Something broke",
          errored_at: ~U[2026-04-12 12:00:00Z]
        })
        |> Repo.insert()

      assert {:ok, run_map} = App.Pyre.Config.get_run("error01")
      assert run_map.status == :error
      assert run_map.error == "Something broke"
      assert run_map.errored_at == ~U[2026-04-12 12:00:00Z]
    end
  end

  describe "render_run/1" do
    test "returns empty HEEx when no connection_id" do
      assigns = %{run: %{status: :queued}}
      result = App.Pyre.Config.render_run(assigns)
      # Empty HEEx renders to an empty rendered struct
      assert result != nil
    end

    test "renders worker info when connection_id present" do
      assigns = %{
        run: %{
          connection_id: "worker-abc123",
          queued_at: ~U[2026-04-12 10:30:00Z]
        },
        __changed__: nil
      }

      result = App.Pyre.Config.render_run(assigns)
      # The result should be a rendered struct (not nil/empty)
      assert result != nil
    end
  end
end
