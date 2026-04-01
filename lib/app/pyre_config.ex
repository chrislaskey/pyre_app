defmodule App.PyreConfig do
  use Pyre.Config
  use PyreWeb.Config

  # Callbacks - Pyre

  @impl Pyre.Config
  def after_flow_complete(%Pyre.Events.FlowCompleted{} = _event) do
    :ok
  end

  # Callbacks - PyreWeb

  @impl PyreWeb.Config
  def authorize_socket_connect(_params, _connect_info) do
    :ok
  end
end
