defmodule AppWeb.UserManagementLive.Show do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        User {@user.email}
        <:subtitle>User ID: {@user.id}</:subtitle>
        <:actions>
          <.button navigate={~p"/settings/users/#{@user}/edit"}>Edit</.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Email">{@user.email}</:item>
        <:item title="Confirmed">{if @user.confirmed_at, do: "Yes", else: "No"}</:item>
        <:item title="Created">{@user.inserted_at}</:item>
      </.list>

      <div class="mt-8 flex gap-4">
        <.button navigate={~p"/settings/users"}>Back to users</.button>
        <.button
          phx-click="delete"
          data-confirm="Are you sure you want to delete this user?"
          class="btn btn-error btn-soft"
        >
          Delete User
        </.button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_navigate(to: ~p"/settings/users")}

      user ->
        {:ok, assign(socket, :user, user)}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Accounts.delete_user(socket.assigns.user)

    {:noreply,
     socket
     |> put_flash(:info, "User deleted successfully.")
     |> push_navigate(to: ~p"/settings/users")}
  end
end
