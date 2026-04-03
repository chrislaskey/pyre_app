defmodule AppWeb.UserLive.LoginCode do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :login_email)
    remember_me = Phoenix.Flash.get(socket.assigns.flash, :login_remember_me) || false

    if email do
      form = to_form(%{"code" => "", "email" => email}, as: "user")

      {:ok,
       assign(socket,
         email: email,
         remember_me: remember_me,
         form: form,
         trigger_submit: false,
         form_action: ~p"/users/log-in"
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Please enter your email first.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("submit_code", %{"user" => %{"code" => code}}, socket) do
    email = socket.assigns.email

    case Accounts.get_user_by_login_code(code, email) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "The code is invalid or it has expired.")
         |> assign(form: to_form(%{"code" => "", "email" => email}, as: "user"))}

      user ->
        form_action =
          if is_nil(user.confirmed_at),
            do: ~p"/users/log-in?_action=confirmed",
            else: ~p"/users/log-in"

        form = to_form(%{"code" => code, "email" => email}, as: "user")

        {:noreply,
         assign(socket,
           form: form,
           trigger_submit: true,
           form_action: form_action
         )}
    end
  end
end
