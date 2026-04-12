defmodule App.Workers.WorkflowJobTest do
  use App.DataCase
  use Oban.Testing, repo: App.Repo

  alias App.Pyre.{Run, Runs}
  alias App.Workers.WorkflowJob

  # --- Helpers ---

  defp create_queued_run!(run_id, workflow_type \\ "feature") do
    serialized_params =
      Jason.encode!(%{
        "workflow" => workflow_type,
        "llm" => nil,
        "skipped_stages" => [],
        "interactive_stages" => [],
        "feature" => nil,
        "attachments" => []
      })

    {:ok, run} =
      %Run{}
      |> Run.changeset(%{
        run_id: run_id,
        description: "Test run",
        workflow_type: workflow_type,
        workflow_params: serialized_params
      })
      |> Repo.insert()

    {run, serialized_params}
  end

  # --- Tests ---

  describe "new/2" do
    test "creates a valid Oban changeset" do
      args = %{
        "run_id" => "test123",
        "description" => "A test run",
        "workflow_params" => ~s({"workflow":"feature"})
      }

      changeset = WorkflowJob.new(args, queue: :workflows_feature)
      assert changeset.valid?
    end

    test "sets queue and tags correctly" do
      args = %{
        "run_id" => "test123",
        "description" => "A test run",
        "workflow_params" => ~s({"workflow":"chat"})
      }

      changeset =
        WorkflowJob.new(args,
          queue: :workflows_chat,
          tags: ["workflow:chat"]
        )

      assert Ecto.Changeset.get_field(changeset, :queue) == "workflows_chat"
      assert Ecto.Changeset.get_field(changeset, :tags) == ["workflow:chat"]
    end
  end

  describe "perform/1 - no workers available" do
    test "snoozes when no workers are connected" do
      {_run, params} = create_queued_run!("snooze01")

      job =
        make_job(WorkflowJob, %{
          "run_id" => "snooze01",
          "description" => "Test run",
          "workflow_params" => params
        })

      # No Presence entries -> select_worker returns nil
      assert {:snooze, 5} = WorkflowJob.perform(job)
    end
  end

  describe "perform/1 - integration with Oban.Testing" do
    test "can be enqueued via create_and_enqueue" do
      opts = [
        workflow: :feature,
        llm: nil,
        skipped_stages: [],
        interactive_stages: [],
        feature: nil,
        attachments: []
      ]

      assert {:ok, run} = Runs.create_and_enqueue("integ01", "Integration test", opts)
      assert run.oban_job_id != nil

      assert_enqueued(
        worker: WorkflowJob,
        args: %{"run_id" => "integ01"}
      )
    end
  end

  defp make_job(worker, args) do
    %Oban.Job{
      worker: to_string(worker),
      args: args,
      queue: "workflows_feature",
      max_attempts: 10
    }
  end
end
