defmodule AppWeb.Router do
  use AppWeb, :router

  import AppWeb.UserAuth

  import Oban.Web.Router
  import Phoenix.LiveDashboard.Router
  import PyreWeb.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## Authentication routes

  scope "/", AppWeb do
    pipe_through :browser

    live_session :current_user,
      on_mount: [{AppWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/code", UserLive.LoginCode, :new
      live "/users/log-in/:token", UserLive.MagicLink, :new
    end

    post "/users/log-in", UserSessionController, :create
    get "/users/log-out", UserSessionController, :delete
    delete "/users/log-out", UserSessionController, :delete
  end

  ## App routes

  scope "/", AppWeb do
    pipe_through :browser
    pipe_through :require_authenticated_user

    live_session :require_authenticated_user,
      on_mount: [{AppWeb.UserAuth, :require_authenticated}] do
      live "/users", UserLive.Index, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/admin", Admin.Index, :index
      live "/admin/users", Admin.Users.Index, :index
      live "/admin/users/new", Admin.Users.New, :new
      live "/admin/users/:id", Admin.Users.Show, :show
      live "/admin/users/:id/edit", Admin.Users.Edit, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/" do
    pipe_through :browser
    pipe_through :require_authenticated_user

    live_dashboard "/live-dashboard", metrics: AppWeb.Telemetry
    oban_dashboard("/oban")

    pyre_web("/")
  end

  ## Development routes

  if Application.compile_env(:app, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
