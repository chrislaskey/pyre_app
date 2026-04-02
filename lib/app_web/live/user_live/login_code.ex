defmodule AppWeb.UserLive.LoginCode do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            Enter your login code
            <:subtitle>
              We sent a 6-digit code to <strong>{@email}</strong>.
              It expires in 5 minutes.
            </:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="login_code_form"
          phx-submit="submit_code"
          action={@form_action}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:email].name} value={@email} />
          <.input
            field={@form[:code]}
            type="text"
            label="Login code"
            inputmode="numeric"
            autocomplete="one-time-code"
            maxlength="6"
            pattern="[0-9]{6}"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Verify code <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <p class="text-center text-sm">
          <.link navigate={~p"/users/log-in"} class="link">
            ← Back to login
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :login_email)

    if email do
      form = to_form(%{"code" => "", "email" => email}, as: "user")

      {:ok,
       assign(socket,
         email: email,
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
