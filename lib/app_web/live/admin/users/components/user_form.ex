defmodule AppWeb.Admin.Users.UserForm do
  use AppWeb, :html

  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :atom, required: true

  def user_form(assigns) do
    ~H"""
    <.form for={@form} id="user-form" phx-change="validate" phx-submit="save">
      <.input
        field={@form[:email]}
        type="email"
        label="Email"
        autocomplete="email"
        spellcheck="false"
        required
      />
      <.button variant="primary" phx-disable-with="Saving...">
        {if @action == :new, do: "Create User", else: "Save Changes"}
      </.button>
    </.form>
    """
  end
end
