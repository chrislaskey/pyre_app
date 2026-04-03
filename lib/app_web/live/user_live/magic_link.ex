defmodule AppWeb.UserLive.MagicLink do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_magic_link_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Login link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/log-in")}

      user ->
        form = to_form(%{"token" => token, "remember_me" => "true"}, as: "user")

        {:ok,
         assign(socket,
           user: user,
           token: token,
           form: form,
           trigger_submit: false,
           form_action: ~p"/users/log-in"
         )}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    form_action =
      if is_nil(socket.assigns.user.confirmed_at),
        do: ~p"/users/log-in?_action=confirmed",
        else: ~p"/users/log-in"

    {:noreply,
     assign(socket,
       trigger_submit: true,
       form_action: form_action
     )}
  end
end
