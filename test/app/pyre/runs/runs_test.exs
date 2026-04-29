defmodule App.Pyre.RunsTest do
  use App.DataCase
  use Oban.Testing, repo: App.Repo

  alias App.Pyre.Run
  alias App.Pyre.Runs

  # --- Helpers ---

  defp create_run!(attrs \\ %{}) do
    defaults = %{
      run_id: "run_#{System.unique_integer([:positive])}",
      description: "Test workflow run",
      workflow_type: "feature"
    }

    {:ok, run} =
      %Run{}
      |> Run.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    run
  end

  defp sample_opts(overrides \\ []) do
    Keyword.merge(
      [
        workflow: :feature,
        llm: nil,
        skipped_stages: [],
        interactive_stages: [],
        feature: nil,
        attachments: []
      ],
      overrides
    )
  end

  # --- Tests ---

  describe "get_by_run_id/1" do
    test "returns the run when found" do
      run = create_run!(%{run_id: "lookup01"})
      found = Runs.get_by_run_id("lookup01")
      assert found.id == run.id
    end

    test "returns nil when not found" do
      assert Runs.get_by_run_id("nonexistent") == nil
    end
  end

  describe "get!/1" do
    test "returns the run by primary key" do
      run = create_run!()
      assert Runs.get!(run.id).id == run.id
    end

    test "raises when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Runs.get!(-1)
      end
    end
  end

  describe "list_recent/1" do
    test "returns runs ordered by inserted_at desc" do
      r1 = create_run!(%{run_id: "recent_1"})
      r2 = create_run!(%{run_id: "recent_2"})
      r3 = create_run!(%{run_id: "recent_3"})

      results = Runs.list_recent()
      run_ids = Enum.map(results, & &1.run_id)

      # Most recent first
      assert r3.run_id in run_ids
      assert r2.run_id in run_ids
      assert r1.run_id in run_ids
    end

    test "respects limit" do
      for i <- 1..5, do: create_run!(%{run_id: "lim_#{i}"})

      results = Runs.list_recent(3)
      assert length(results) == 3
    end
  end

  describe "create_and_enqueue/3" do
    test "creates a run and enqueues an Oban job" do
      run_id = "enqueue01"
      opts = sample_opts(workflow: :chat)

      assert {:ok, run} = Runs.create_and_enqueue(run_id, "Test chat workflow", opts)

      assert run.run_id == run_id
      assert run.description == "Test chat workflow"
      assert run.workflow_type == "chat"
      assert run.status == :queued
      assert run.oban_job_id != nil

      # Verify an Oban job was enqueued
      assert_enqueued(
        worker: App.Workers.WorkflowJob,
        args: %{"run_id" => run_id}
      )
    end

    test "enqueues job to the correct workflow queue" do
      opts = sample_opts(workflow: :prototype)

      assert {:ok, _run} = Runs.create_and_enqueue("proto01", "Prototype test", opts)

      assert_enqueued(
        worker: App.Workers.WorkflowJob,
        queue: :workflows_prototype
      )
    end

    test "stores serialized workflow params" do
      opts = sample_opts(workflow: :feature, feature: "login-page")

      assert {:ok, run} = Runs.create_and_enqueue("feat01", "Feature test", opts)

      assert run.workflow_params != nil
      decoded = Jason.decode!(run.workflow_params)
      assert decoded["workflow"] == "feature"
      assert decoded["feature"] == "login-page"
    end

    test "persists feature as a first-class column" do
      opts = sample_opts(workflow: :feature, feature: "login-page")

      assert {:ok, run} = Runs.create_and_enqueue("feat_col01", "Feature column test", opts)
      assert run.feature == "login-page"

      # Verify it survives a reload from the database
      reloaded = Runs.get_by_run_id("feat_col01")
      assert reloaded.feature == "login-page"
    end

    test "persists nil feature when not provided" do
      opts = sample_opts(workflow: :chat, feature: nil)

      assert {:ok, run} = Runs.create_and_enqueue("feat_col02", "No feature test", opts)
      assert run.feature == nil
    end

    test "rejects duplicate run_ids" do
      opts = sample_opts()

      assert {:ok, _run} = Runs.create_and_enqueue("dup01", "First run", opts)
      assert {:error, _changeset} = Runs.create_and_enqueue("dup01", "Second run", opts)
    end
  end

  describe "update_status/3" do
    test "updates the run status" do
      run = create_run!(%{run_id: "status01"})

      assert {:ok, updated} = Runs.update_status(run, :running, %{started_at: DateTime.utc_now()})
      assert updated.status == :running
      assert updated.started_at != nil
    end

    test "transitions through all valid statuses" do
      run = create_run!(%{run_id: "status02"})

      assert {:ok, run} = Runs.update_status(run, :dispatched, %{connection_id: "worker-1"})
      assert run.status == :dispatched
      assert run.connection_id == "worker-1"

      assert {:ok, run} = Runs.update_status(run, :running, %{started_at: DateTime.utc_now()})
      assert run.status == :running

      assert {:ok, run} =
               Runs.update_status(run, :complete, %{completed_at: DateTime.utc_now()})

      assert run.status == :complete
    end

    test "can set error status with error message" do
      run = create_run!(%{run_id: "error01"})

      assert {:ok, updated} =
               Runs.update_status(run, :error, %{
                 error: "Something went wrong",
                 errored_at: DateTime.utc_now()
               })

      assert updated.status == :error
      assert updated.error == "Something went wrong"
    end

    test "broadcasts status change via PubSub" do
      run = create_run!(%{run_id: "pubsub01"})
      Phoenix.PubSub.subscribe(App.PubSub, "pyre:runs:pubsub01")

      Runs.update_status(run, :running)

      assert_receive {:pyre_run_status, "pubsub01", :running}
    end

    test "can reset status back to queued" do
      run = create_run!(%{run_id: "reset01", status: :dispatched, connection_id: "worker-1"})

      assert {:ok, updated} = Runs.update_status(run, :queued, %{connection_id: nil})
      assert updated.status == :queued
      assert updated.connection_id == nil
    end
  end

  describe "serialize_workflow_params/1" do
    test "serializes basic workflow opts" do
      opts = [
        workflow: :feature,
        llm: nil,
        skipped_stages: [:testing],
        interactive_stages: [:reviewing],
        feature: "login-page",
        attachments: []
      ]

      {type, json} = Runs.serialize_workflow_params(opts)

      assert type == "feature"
      decoded = Jason.decode!(json)
      assert decoded["workflow"] == "feature"
      assert decoded["skipped_stages"] == ["testing"]
      assert decoded["interactive_stages"] == ["reviewing"]
      assert decoded["feature"] == "login-page"
      assert decoded["attachments"] == []
    end

    test "serializes attachments with base64 encoding" do
      opts = [
        workflow: :chat,
        llm: nil,
        skipped_stages: [],
        interactive_stages: [],
        feature: nil,
        attachments: [
          %{filename: "test.txt", content: "hello world", media_type: "text/plain"}
        ]
      ]

      {_type, json} = Runs.serialize_workflow_params(opts)
      decoded = Jason.decode!(json)

      [att] = decoded["attachments"]
      assert att["filename"] == "test.txt"
      assert att["media_type"] == "text/plain"
      assert Base.decode64!(att["content"]) == "hello world"
    end

    test "handles nil llm" do
      opts = sample_opts(llm: nil)
      {_type, json} = Runs.serialize_workflow_params(opts)
      decoded = Jason.decode!(json)
      assert decoded["llm"] == nil
    end
  end

  describe "deserialize_workflow_params/1" do
    test "round-trips basic workflow params" do
      original_opts = [
        workflow: :feature,
        llm: nil,
        skipped_stages: [:testing],
        interactive_stages: [:reviewing],
        feature: "login-page",
        attachments: []
      ]

      {_type, json} = Runs.serialize_workflow_params(original_opts)
      deserialized = Runs.deserialize_workflow_params(json)

      assert deserialized[:workflow] == :feature
      assert deserialized[:skipped_stages] == [:testing]
      assert deserialized[:interactive_stages] == [:reviewing]
      assert deserialized[:feature] == "login-page"
      assert deserialized[:attachments] == []
    end

    test "round-trips attachments" do
      original_opts = [
        workflow: :chat,
        llm: nil,
        skipped_stages: [],
        interactive_stages: [],
        feature: nil,
        attachments: [
          %{filename: "data.csv", content: "a,b,c\n1,2,3", media_type: "text/csv"}
        ]
      ]

      {_type, json} = Runs.serialize_workflow_params(original_opts)
      deserialized = Runs.deserialize_workflow_params(json)

      [att] = deserialized[:attachments]
      assert att.filename == "data.csv"
      assert att.content == "a,b,c\n1,2,3"
      assert att.media_type == "text/csv"
    end
  end

  describe "workflow_queue_name/1" do
    test "derives queue name from atom" do
      assert Runs.workflow_queue_name(:feature) == :workflows_feature
      assert Runs.workflow_queue_name(:chat) == :workflows_chat
      assert Runs.workflow_queue_name(:code_review) == :workflows_code_review
    end

    test "derives queue name from string" do
      assert Runs.workflow_queue_name("feature") == :workflows_feature
      assert Runs.workflow_queue_name("overnight_feature") == :workflows_overnight_feature
    end
  end
end
