defmodule AppWeb.Admin.Users.Show do
  @moduledoc false
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
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("send_login_link", _params, socket) do
    user = socket.assigns.user

    Accounts.deliver_magic_link_instructions(user, &url(~p"/users/log-in/#{&1}"))

    {:noreply, put_flash(socket, :info, "Login link sent to #{user.email}.")}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    user = socket.assigns.user
    {:ok, _} = Accounts.delete_user(user)

    socket =
      if seeded_email?(user.email) do
        put_flash(
          socket,
          :warning,
          "User defined in app config. If not removed there, it will be recreated on next app start."
        )
      else
        socket
      end

    {:noreply,
     socket
     |> put_flash(:info, "User deleted successfully.")
     |> push_navigate(to: ~p"/admin/users")}
  end

  defp seeded_email?(email) do
    :app
    |> Application.get_env(:accounts, [])
    |> List.wrap()
    |> Enum.any?(fn
      entry when is_list(entry) -> Keyword.get(entry, :email) == email
      _ -> false
    end)
  end
end
