defmodule App.Pyre.Config do
  use Pyre.Config
  use PyreWeb.Config

  import Phoenix.Component, only: [sigil_H: 2]

  # Callbacks - Pyre

  @impl Pyre.Config
  def after_flow_complete(%Pyre.Events.FlowCompleted{} = _event) do
    :ok
  end

  # Callbacks - PyreWeb

  @impl PyreWeb.Config
  def authorize_socket_connect(_params, _connect_info) do
    :ok
  end

  @impl PyreWeb.Config
  def update_github_app(credentials) do
    App.Pyre.Config.GithubApps.update_github_app(credentials)
  end

  @impl PyreWeb.Config
  def list_github_apps do
    App.Pyre.Config.GithubApps.list_github_apps()
  end

  @impl PyreWeb.Config
  def additional_nav_links(assigns) do
    ~H"""
    <li>
      <a href="/admin">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          class="size-4"
        >
          <path
            fill-rule="evenodd"
            d="M9.661 2.237a.531.531 0 0 1 .678 0 11.947 11.947 0 0 0 7.078 2.749.5.5 0 0 1 .479.425c.069.52.104 1.05.104 1.589 0 5.162-3.26 9.563-7.834 11.256a.48.48 0 0 1-.332 0C5.26 16.563 2 12.162 2 7c0-.538.035-1.069.104-1.589a.5.5 0 0 1 .48-.425 11.947 11.947 0 0 0 7.077-2.75Zm4.196 5.954a.75.75 0 0 0-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 1 0-1.06 1.061l2.5 2.5a.75.75 0 0 0 1.137-.089l4-5.5Z"
            clip-rule="evenodd"
          />
        </svg>
        Admin
      </a>
    </li>
    """
  end

  @impl PyreWeb.Config
  def sidebar_footer(assigns) do
    ~H"""
    <div class="border-t border-base-300 pt-3 mt-3">
      <ul class="menu w-full gap-y-1">
        <li>
          <Phoenix.Component.link class="flex" href="/users/settings">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="size-4"
            >
              <path
                fill-rule="evenodd"
                d="M7.5 6a4.5 4.5 0 1 1 9 0 4.5 4.5 0 0 1-9 0ZM3.751 20.105a8.25 8.25 0 0 1 16.498 0 .75.75 0 0 1-.437.695A18.683 18.683 0 0 1 12 22.5c-2.786 0-5.433-.608-7.812-1.7a.75.75 0 0 1-.437-.695Z"
                clip-rule="evenodd"
              />
            </svg>
            My Account
          </Phoenix.Component.link>
        </li>
      </ul>
    </div>
    """
  end
end
