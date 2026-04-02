defmodule AppWeb.Admin.Users.Index do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :users, Accounts.list_users())}
  end
end
