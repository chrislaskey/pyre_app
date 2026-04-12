defmodule App.Pyre.Workers.QueueManagerTest do
  use App.DataCase

  alias App.Pyre.Workers.QueueManager

  describe "start_link/1" do
    test "starts successfully" do
      # QueueManager is already running in the supervision tree during tests,
      # so we just verify it's alive
      assert Process.whereis(QueueManager) != nil
    end
  end

  describe "handle_info/2 - presence_diff" do
    test "handles presence_diff messages without crashing" do
      pid = Process.whereis(QueueManager)
      assert pid != nil

      # Send a presence_diff message — the handler should process it gracefully
      # even when there are no connections
      diff = %Phoenix.Socket.Broadcast{
        topic: "pyre:connections",
        event: "presence_diff",
        payload: %{joins: %{}, leaves: %{}}
      }

      send(pid, diff)

      # Give it a moment to process
      Process.sleep(50)

      # GenServer should still be alive
      assert Process.alive?(pid)
    end
  end

  describe "workflow_queue_name derivation" do
    test "each workflow type maps to a queue name" do
      # Verify the naming convention used by QueueManager matches Runs
      assert App.Pyre.Runs.workflow_queue_name(:chat) == :workflows_chat
      assert App.Pyre.Runs.workflow_queue_name(:feature) == :workflows_feature
      assert App.Pyre.Runs.workflow_queue_name(:prototype) == :workflows_prototype
      assert App.Pyre.Runs.workflow_queue_name(:task) == :workflows_task
      assert App.Pyre.Runs.workflow_queue_name(:code_review) == :workflows_code_review

      assert App.Pyre.Runs.workflow_queue_name(:overnight_feature) ==
               :workflows_overnight_feature
    end
  end
end
