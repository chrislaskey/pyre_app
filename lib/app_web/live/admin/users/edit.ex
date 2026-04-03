defmodule AppWeb.Admin.Users.Edit do
  use AppWeb, :live_view

  alias App.Accounts

  import AppWeb.Admin.Users.UserForm

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_navigate(to: ~p"/admin/users")}

      user ->
        changeset = Accounts.change_user(user)
        {:ok, socket |> assign(:user, user) |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully.")
         |> push_navigate(to: ~p"/admin/users/#{user}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end
end
