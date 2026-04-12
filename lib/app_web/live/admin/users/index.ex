defmodule AppWeb.Admin.Users.Index do
  @moduledoc false
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :users, Accounts.list_users())}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("send_login_link", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    Accounts.deliver_magic_link_instructions(user, &url(~p"/users/log-in/#{&1}"))

    {:noreply, put_flash(socket, :info, "Login link sent to #{user.email}.")}
  end
end
