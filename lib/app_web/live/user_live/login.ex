defmodule AppWeb.UserLive.Login do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => "true"}, as: "user")

    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    %{"email" => email, "password" => password} = user_params
    remember_me = user_params["remember_me"] == "true"

    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid email or password.")
         |> assign(form: to_form(%{"email" => email}, as: "user"))}

      user ->
        {:ok, _} = Accounts.deliver_login_instructions(user)

        {:noreply,
         socket
         |> put_flash(:info, "We sent a verification code to your email.")
         |> put_flash(:login_email, email)
         |> put_flash(:login_remember_me, remember_me)
         |> push_navigate(to: ~p"/users/log-in/code")}
    end
  end
end
