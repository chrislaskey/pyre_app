defmodule App.Workers.WorkflowJob do
  @moduledoc """
  Oban worker that bridges the queue and remote workflow execution.

  Selects a compatible worker from connected clients, dispatches work
  via PubSub, awaits acknowledgement, then blocks until the run completes.

  The queue is set dynamically per-job at insert time (see `App.Pyre.Runs`),
  not at compile time.
  """
  use Oban.Worker,
    max_attempts: 10,
    unique: [keys: [:run_id]]

  @impl Oban.Worker
  def timeout(_job), do: :timer.hours(24)

  alias App.Pyre.Runs

  @ack_timeout :timer.seconds(10)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    run_id = args["run_id"]
    description = args["description"]
    workflow_params = args["workflow_params"]

    run = Runs.get_by_run_id(run_id)

    case select_worker(workflow_params) do
      nil ->
        # No compatible workers available — snooze. QueueManager should
        # have paused the queue, but this handles the race condition.
        {:snooze, 5}

      worker ->
        dispatch_and_run(run, run_id, worker, description, workflow_params)
    end
  end

  # Selects a connected client that:
  # 1. Has status "active" and available_capacity > 0
  # 2. Supports the required LLM backend (if specified)
  # 3. Supports the workflow type (or is general-purpose)
  #
  # Returns the client with the highest available capacity, or nil.
  defp select_worker(workflow_params) do
    opts = Jason.decode!(workflow_params)
    required_backend = opts["llm"]
    workflow_type = opts["workflow"]

    PyreWeb.Presence.list_connections()
    |> Enum.filter(&compatible_worker?(&1, required_backend, workflow_type))
    |> Enum.max_by(&worker_capacity/1, fn -> nil end)
  end

  defp compatible_worker?(meta, required_backend, workflow_type) do
    worker_status(meta) == "active" and
      worker_capacity(meta) > 0 and
      backend_matches?(meta, required_backend) and
      workflow_matches?(meta, workflow_type)
  end

  defp worker_capacity(meta), do: meta["available_capacity"] || meta[:available_capacity] || 0
  defp worker_status(meta), do: meta["status"] || meta[:status] || "active"
  defp worker_backends(meta), do: meta["backends"] || meta[:backends] || []
  defp worker_enabled_workflows(meta), do: meta["enabled_workflows"] || meta[:enabled_workflows] || []

  defp backend_matches?(_meta, nil), do: true
  defp backend_matches?(meta, required), do: required in worker_backends(meta)

  defp workflow_matches?(meta, type) do
    enabled = worker_enabled_workflows(meta)
    enabled == [] or type in enabled
  end

  defp dispatch_and_run(run, run_id, worker, description, workflow_params) do
    connection_id = worker["connection_id"] || worker[:connection_id]

    # Update run: dispatched
    Runs.update_status(run, :dispatched, %{
      connection_id: connection_id
    })

    # Dispatch to the worker via PubSub
    execution_id = "run:#{run_id}"

    if pubsub = Application.get_env(:pyre, :pubsub) do
      Phoenix.PubSub.broadcast(
        pubsub,
        "pyre:action:input:#{connection_id}",
        {:action, execution_id,
         %{
           type: "workflow",
           run_id: run_id,
           description: description,
           workflow_params: workflow_params
         }}
      )
    end

    # Await client ack
    case await_ack(execution_id, @ack_timeout) do
      {:ok, :accepted} ->
        start_run(run, run_id, description, workflow_params)

      {:ok, :rejected} ->
        # Client rejected (at capacity). Snooze and retry with a
        # different worker.
        Runs.update_status(run, :queued, %{
          connection_id: nil
        })

        {:snooze, 3}

      {:error, :timeout} ->
        # Client didn't respond. Reset and retry.
        Runs.update_status(run, :queued, %{
          connection_id: nil
        })

        {:snooze, 5}
    end
  end

  defp start_run(run, run_id, _description, workflow_params) do
    opts = Runs.deserialize_workflow_params(workflow_params)

    Runs.update_status(run, :running, %{
      started_at: DateTime.utc_now()
    })

    case apply(Pyre.RunServer, :start_run, [run.description, [id: run_id] ++ opts]) do
      {:ok, ^run_id} ->
        # RunServer is now running. Block until it completes.
        case await_run_completion(run_id) do
          :completed ->
            Runs.update_status(run, :complete, %{
              completed_at: DateTime.utc_now()
            })

            :ok

          {:failed, reason} ->
            Runs.update_status(run, :error, %{
              error: inspect(reason),
              errored_at: DateTime.utc_now()
            })

            {:error, reason}
        end

      {:error, reason} ->
        Runs.update_status(run, :error, %{
          error: inspect(reason),
          errored_at: DateTime.utc_now()
        })

        {:error, reason}
    end
  end

  defp await_ack(execution_id, timeout) do
    pubsub = Application.get_env(:pyre, :pubsub)

    if pubsub do
      Phoenix.PubSub.subscribe(pubsub, "pyre:action:output:#{execution_id}")
    end

    receive do
      {:action_output, %{"type" => "ack", "status" => "accepted"}} ->
        {:ok, :accepted}

      {:action_output, %{"type" => "ack", "status" => "rejected"}} ->
        {:ok, :rejected}
    after
      timeout -> {:error, :timeout}
    end
  end

  defp await_run_completion(run_id) do
    pubsub = Application.get_env(:pyre, :pubsub)

    if pubsub do
      Phoenix.PubSub.subscribe(pubsub, "pyre:runs:#{run_id}")
    end

    # Poll + subscribe: check if already complete, then wait.
    #
    # RunServer broadcasts {:pyre_run_status, run_id, status} on
    # "pyre:runs:#{run_id}" when the flow task exits. The terminal
    # statuses are:
    #   :complete — flow finished successfully
    #   :error   — flow errored or task crashed
    #   :stopped — user stopped the run
    case apply(Pyre.RunServer, :get_state, [run_id]) do
      {:ok, %{status: :complete}} ->
        :completed

      {:ok, %{status: :error}} ->
        {:failed, :error}

      {:ok, %{status: :stopped}} ->
        {:failed, :stopped}

      {:ok, _state} ->
        receive do
          {:pyre_run_status, ^run_id, :complete} -> :completed
          {:pyre_run_status, ^run_id, :error} -> {:failed, :error}
          {:pyre_run_status, ^run_id, :stopped} -> {:failed, :stopped}
        after
          :timer.hours(24) -> {:failed, :timeout}
        end

      {:error, :not_found} ->
        {:failed, :run_not_found}
    end
  end
end
