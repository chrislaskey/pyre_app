defmodule AppWeb.Admin.Users.Show do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_navigate(to: ~p"/admin/users")}

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
     |> push_navigate(to: ~p"/admin/users")}
  end
end
