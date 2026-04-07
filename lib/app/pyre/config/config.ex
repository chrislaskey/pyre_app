defmodule App.Pyre.Config do
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
