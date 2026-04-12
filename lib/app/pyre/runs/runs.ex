defmodule App.Pyre.Runs do
  @moduledoc """
  Context for managing persistent workflow run records.

  Supplements the transient `Pyre.RunServer` GenServer with durable state
  that survives restarts. Handles Oban job enqueuing, serialization of
  workflow params, and PubSub broadcasts on status changes.
  """
  import Ecto.Query
  alias App.Repo
  alias App.Pyre.Run

  def get_by_run_id(run_id) do
    Repo.get_by(Run, run_id: run_id)
  end

  def get!(id), do: Repo.get!(Run, id)

  def list_recent(limit \\ 50) do
    from(r in Run, order_by: [desc: r.inserted_at], limit: ^limit)
    |> Repo.all()
  end

  def create_and_enqueue(run_id, description, opts) do
    {workflow_type, serialized_opts} = serialize_workflow_params(opts)

    changeset =
      Run.changeset(%Run{}, %{
        run_id: run_id,
        description: description,
        workflow_type: workflow_type,
        workflow_params: serialized_opts
      })

    queue = workflow_queue_name(workflow_type)

    job_args = %{
      "run_id" => run_id,
      "description" => description,
      "workflow_params" => serialized_opts
    }

    # Use Oban.insert/3 (Multi-aware) instead of wrapping Oban.insert/1
    # inside Multi.run. With SQLite (single-writer), a nested
    # Oban.insert/1 inside a Multi transaction can deadlock because both
    # compete for the same write lock. Oban.insert/3 participates in the
    # existing transaction via the same database connection.
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:run, changeset)
    |> Oban.insert(
      :oban_job,
      App.Workers.WorkflowJob.new(job_args,
        queue: queue,
        tags: ["workflow:#{workflow_type}"]
      )
    )
    |> Ecto.Multi.update(:link_job, fn %{run: run, oban_job: job} ->
      Run.changeset(run, %{oban_job_id: job.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{link_job: run}} -> {:ok, run}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  def stop(run_id) do
    apply(Pyre.RunServer, :stop_run, [run_id])

    case get_by_run_id(run_id) do
      %Run{} = run ->
        if run.oban_job_id, do: Oban.cancel_job(run.oban_job_id)
        update_status(run, :stopped)

      nil ->
        :ok
    end
  end

  def update_status(run, status, attrs \\ %{}) do
    case run |> Run.changeset(Map.put(attrs, :status, status)) |> Repo.update() do
      {:ok, updated} ->
        if pubsub = Application.get_env(:pyre, :pubsub) do
          Phoenix.PubSub.broadcast(
            pubsub,
            "pyre:runs:#{updated.run_id}",
            {:pyre_run_status, updated.run_id, status}
          )
        end

        {:ok, updated}

      error ->
        error
    end
  end

  # --- Serialization ---

  @doc """
  Serialize workflow opts to JSON-safe format.

  The opts keyword list from pyre_web contains:
  - `:workflow` - atom -> string
  - `:llm` - module atom -> string via Pyre.Config.backend_name_for_module/1
  - `:skipped_stages` - atom list -> string list
  - `:interactive_stages` - atom list -> string list
  - `:attachments` - binary content -> base64 encoded
  - `:feature` - string or nil (already JSON-safe)
  """
  def serialize_workflow_params(opts) do
    workflow_type = opts[:workflow] |> to_string()

    llm_name =
      if opts[:llm] do
        apply(Pyre.Config, :backend_name_for_module, [opts[:llm]])
      end

    serialized = %{
      "workflow" => workflow_type,
      "llm" => llm_name,
      "skipped_stages" => Enum.map(opts[:skipped_stages] || [], &to_string/1),
      "interactive_stages" => Enum.map(opts[:interactive_stages] || [], &to_string/1),
      "feature" => opts[:feature],
      "attachments" =>
        Enum.map(opts[:attachments] || [], fn att ->
          %{
            "filename" => att.filename,
            "content" => Base.encode64(att.content),
            "media_type" => att.media_type
          }
        end)
    }

    {workflow_type, Jason.encode!(serialized)}
  end

  @doc """
  Deserialize JSON opts back to the keyword list format expected by
  Pyre.RunServer.start_run/2.
  """
  def deserialize_workflow_params(workflow_params) do
    opts = Jason.decode!(workflow_params)

    llm_module =
      if opts["llm"] do
        apply(Pyre.Config, :get_llm_backend, [opts["llm"]])
      else
        apply(Pyre.LLM, :default, [])
      end

    # Use String.to_atom/1 instead of String.to_existing_atom/1 because
    # Oban jobs may be retried after a deploy that changes workflow/stage
    # names. If the atom no longer exists, to_existing_atom raises.
    # The values are bounded by Pyre.Config (not arbitrary user input).
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    [
      workflow: String.to_atom(opts["workflow"]),
      llm: llm_module,
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      skipped_stages: Enum.map(opts["skipped_stages"] || [], &String.to_atom/1),
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      interactive_stages: Enum.map(opts["interactive_stages"] || [], &String.to_atom/1),
      feature: opts["feature"],
      attachments:
        Enum.map(opts["attachments"] || [], fn att ->
          %{
            filename: att["filename"],
            content: Base.decode64!(att["content"]),
            media_type: att["media_type"]
          }
        end)
    ]
  end

  # --- Queue Name Derivation ---

  @doc ~S"""
  Derives the Oban queue name for a workflow type.

  Convention: `:workflows_#{type}`. All queue names are derived dynamically
  from `Pyre.Config.list_workflows/0` — no hardcoded maps.
  """
  def workflow_queue_name(type) when is_atom(type), do: :"workflows_#{type}"
  def workflow_queue_name(type) when is_binary(type), do: :"workflows_#{type}"
end
