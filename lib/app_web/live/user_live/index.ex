defmodule AppWeb.UserLive.Index do
  use AppWeb, :live_view

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end
end
