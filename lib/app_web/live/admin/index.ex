defmodule AppWeb.Admin.Index do
  use AppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end
end
