defmodule AppWeb.UserManagementLive.New do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.User

  import AppWeb.UserManagementLive.UserForm

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        New User
        <:subtitle>Create a new user account</:subtitle>
      </.header>

      <.user_form form={@form} action={:new} />

      <div class="mt-4">
        <.button navigate={~p"/settings/users"}>Back to users</.button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user(%User{})
    {:ok, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully.")
         |> push_navigate(to: ~p"/settings/users/#{user}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end
end
