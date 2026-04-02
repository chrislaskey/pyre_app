defmodule AppWeb.UserManagementLive.Index do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Users
        <:actions>
          <.button navigate={~p"/settings/users/new"} variant="primary">New User</.button>
        </:actions>
      </.header>

      <.table id="users" rows={@users} row_click={&JS.navigate(~p"/settings/users/#{&1}")}>
        <:col :let={user} label="Email">{user.email}</:col>
        <:col :let={user} label="Confirmed">
          {if user.confirmed_at, do: "Yes", else: "No"}
        </:col>
        <:action :let={user}>
          <.link navigate={~p"/settings/users/#{user}"}>Show</.link>
        </:action>
        <:action :let={user}>
          <.link navigate={~p"/settings/users/#{user}/edit"}>Edit</.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :users, Accounts.list_users())}
  end
end
