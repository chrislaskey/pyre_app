defmodule AppWeb.UserLive.Login do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Enter your email and password. We'll send a verification code to confirm it's you.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form for={@form} id="login_form" phx-submit="submit">
          <.input
            readonly={!!@current_scope}
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            spellcheck="false"
            required
          />
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <.button class="btn btn-primary w-full">
            Continue <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => "true"}, as: "user")

    {:ok, assign(socket, form: form)}
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
        Accounts.deliver_login_instructions(user)

        {:noreply,
         socket
         |> put_flash(:info, "We sent a verification code to your email.")
         |> put_flash(:login_email, email)
         |> put_flash(:login_remember_me, remember_me)
         |> push_navigate(to: ~p"/users/log-in/code")}
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:app, App.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
