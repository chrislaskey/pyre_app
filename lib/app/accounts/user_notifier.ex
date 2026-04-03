defmodule App.Accounts.UserNotifier do
  import Swoosh.Email

  alias App.Mailer
  alias App.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"App", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Your login link", """

    ==============================

    Hi #{user.email},

    You can log in by visiting the URL below:

    #{url}

    This link expires in 60 minutes.

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a login code.
  """
  def deliver_login_instructions(user, code) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_code_instructions(user, code)
      _ -> deliver_login_code_instructions(user, code)
    end
  end

  defp deliver_login_code_instructions(user, code) do
    deliver(user.email, "Your login code", """

    ==============================

    Hi #{user.email},

    Your login code is:

    #{code}

    This code expires in 5 minutes.

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_code_instructions(user, code) do
    deliver(user.email, "Your confirmation code", """

    ==============================

    Hi #{user.email},

    Your confirmation code is:

    #{code}

    This code expires in 5 minutes.

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
