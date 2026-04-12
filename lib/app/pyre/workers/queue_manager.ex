defmodule App.Pyre.Workers.QueueManager do
  @moduledoc """
  Manages all workflow queues via dynamic scaling.

  Subscribes to Presence diffs on `"pyre:connections"`. On every diff
  (worker join, leave, or metadata update), computes the actual capacity
  for each workflow type and scales the corresponding Oban queue to match.
  Queues with zero capacity are paused; queues gaining capacity are
  resumed and scaled.
  """
  use GenServer
  require Logger

  @presence_topic "pyre:connections"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if pubsub = Application.get_env(:pyre, :pubsub) do
      Phoenix.PubSub.subscribe(pubsub, @presence_topic)
    end

    state = %{queue_limits: %{}}
    {:ok, sync_all_queues(state)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, state) do
    {:noreply, sync_all_queues(state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp sync_all_queues(state) do
    connections = PyreWeb.Presence.list_connections()
    capacity_by_type = compute_capacity_by_type(connections)

    new_queue_limits =
      apply(Pyre.Config, :list_workflows, [])
      |> Map.new(fn entry ->
        type_str = to_string(entry.name)
        queue_name = App.Pyre.Runs.workflow_queue_name(entry.name)
        new_limit = Map.get(capacity_by_type, type_str, 0)
        old_limit = Map.get(state.queue_limits, queue_name, 0)

        apply_queue_limit(queue_name, old_limit, new_limit)

        {queue_name, new_limit}
      end)

    %{state | queue_limits: new_queue_limits}
  end

  # Oban requires limit to be a pos_integer() (strictly > 0).
  # scale_queue(queue: :foo, limit: 0) raises:
  #
  #   "expected :limit to be an integer greater than 0, got: 0"
  #
  # The queue's `paused` flag and `limit` are independent fields in the
  # producer metadata. Pausing sets `paused: true` which short-circuits
  # job fetching before `limit` is even checked. So we must use
  # pause_queue/resume_queue for the 0 <-> N transitions, and scale_queue
  # for N <-> M transitions where both are > 0.
  defp apply_queue_limit(queue_name, old_limit, new_limit) do
    cond do
      new_limit > 0 and old_limit == 0 ->
        # Queue was inactive, now has capacity — resume and scale
        Logger.debug("QueueManager: activating #{queue_name} (limit: #{new_limit})")
        Oban.resume_queue(queue: queue_name)
        Oban.scale_queue(queue: queue_name, limit: new_limit)

      new_limit > 0 and new_limit != old_limit ->
        # Queue already active, capacity changed — rescale
        Logger.debug("QueueManager: scaling #{queue_name} (#{old_limit} -> #{new_limit})")
        Oban.scale_queue(queue: queue_name, limit: new_limit)

      new_limit == 0 and old_limit > 0 ->
        # Queue was active, no more capacity — pause (can't scale to 0)
        Logger.debug("QueueManager: pausing #{queue_name} (no compatible clients)")
        Oban.pause_queue(queue: queue_name)

      true ->
        # No change — either still paused (0 -> 0) or same limit
        :ok
    end
  end

  # Returns a map of %{type_string => total_available_capacity}.
  #
  # For each connected client:
  # - General-purpose clients (empty enabled_workflows) contribute their
  #   available_capacity to every workflow type from Pyre.Config.list_workflows().
  # - Specialist clients contribute only to the types they declare.
  #
  # Note: general-purpose clients are double-counted across types. This is
  # intentional — it means every queue's limit reflects the capacity that
  # *could* serve it. The tradeoff is that simultaneous dequeues across
  # queues may exceed actual total capacity, causing some snooze churn.
  defp compute_capacity_by_type(connections) do
    all_types = apply(Pyre.Config, :list_workflows, []) |> Enum.map(&to_string(&1.name))

    Enum.reduce(connections, %{}, fn meta, acc ->
      enabled = meta["enabled_workflows"] || meta[:enabled_workflows] || []
      capacity = meta["available_capacity"] || meta[:available_capacity] || 0
      status = meta["status"] || meta[:status] || "active"

      if status != "active" or capacity <= 0 do
        acc
      else
        types_to_credit =
          if enabled == [] do
            # General-purpose client: credit all workflow types
            all_types
          else
            # Specialist: credit only declared types
            enabled
          end

        Enum.reduce(types_to_credit, acc, fn type, inner_acc ->
          Map.update(inner_acc, type, capacity, &(&1 + capacity))
        end)
      end
    end)
  end
end
