defmodule App.Pyre.Config do
  @moduledoc false
  use Pyre.Config
  use PyreWeb.Config

  # Callbacks - Pyre

  @impl Pyre.Config
  def after_flow_complete(%Pyre.Events.FlowCompleted{} = _event) do
    :ok
  end

  @impl Pyre.Config
  def list_llm_backends do
    custom_llm_backends = maybe_custom_config(App.Pyre.Config.Custom, :list_llm_backends, [], [])

    Pyre.Config.included_llm_backends() ++ custom_llm_backends
  end

  # Callbacks - PyreWeb

  @impl PyreWeb.Config
  def run_submit(description, opts) do
    run_id = apply(Pyre.RunServer, :generate_id, [])

    case App.Pyre.Runs.create_and_enqueue(run_id, description, opts) do
      {:ok, _run} ->
        {:ok, redirect_to: "/runs/#{run_id}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl PyreWeb.Config
  def get_run(run_id) do
    instance_data = apply(Pyre.RunServer, :get_state, [run_id])
    database_data = App.Pyre.Runs.get_by_run_id(run_id)

    case {instance_data, database_data} do
      {{:ok, run_state}, %App.Pyre.Run{} = run} ->
        # Both exist: RunServer is the source of truth for transient state
        # (status, phase, log, etc.), merge in DB-only fields for render_run.
        {:ok,
         Map.merge(run_state, %{
           connection_id: run.connection_id,
           queued_at: run.inserted_at,
           errored_at: run.errored_at,
           error: run.error,
           oban_job_id: run.oban_job_id
         })}

      {{:ok, run_state}, nil} ->
        # RunServer exists but no DB record (e.g., run started directly
        # without queueing). Pass through RunServer state as-is.
        {:ok, run_state}

      {{:error, :not_found}, %App.Pyre.Run{} = run} ->
        # No RunServer (queued, completed, or failed). Build state from
        # the persistent DB record so the page can render queue status.
        # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
        {:ok,
         %{
           status: run.status,
           feature_description: run.description,
           workflow: String.to_atom(run.workflow_type),
           feature: nil,
           log: [],
           connection_id: run.connection_id,
           queued_at: run.inserted_at,
           started_at: run.started_at,
           completed_at: run.completed_at,
           errored_at: run.errored_at,
           error: run.error,
           oban_job_id: run.oban_job_id
         }}

      {{:error, :not_found}, nil} ->
        # Neither source has this run.
        {:error, :not_found}
    end
  end

  @impl PyreWeb.Config
  def render_run(assigns) do
    App.Pyre.Config.Web.render_run(assigns)
  end

  @impl PyreWeb.Config
  def authorize_socket_connect(_params, _connect_info) do
    :ok
  end

  @impl PyreWeb.Config
  def update_github_app(credentials) do
    App.Pyre.Config.GithubApps.update_github_app(credentials)
  end

  @impl PyreWeb.Config
  def list_github_apps do
    App.Pyre.Config.GithubApps.list_github_apps()
  end

  @impl PyreWeb.Config
  def additional_nav_links(assigns) do
    App.Pyre.Config.Web.additional_nav_links(assigns)
  end

  @impl PyreWeb.Config
  def sidebar_footer(assigns) do
    App.Pyre.Config.Web.sidebar_footer(assigns)
  end

  # Config helpers

  def maybe_custom_config(module, function, args, default) do
    if Code.ensure_loaded?(module) and
         function_exported?(module, function, length(args)) do
      apply(module, function, args)
    else
      default
    end
  end
end
