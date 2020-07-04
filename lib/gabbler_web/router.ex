defmodule GabblerWeb.Router do
  use GabblerWeb, :router

  import GabblerWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :live_browser do
    plug :put_root_layout, {GabblerWeb.LayoutView, :app}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GabblerWeb do
    pipe_through [:browser]

    get "/about", PageController, :about
    get "/tos", PageController, :tos

    # USER
    post "/u/session/new", UserController, :new
    get "/u/session/new", UserController, :index
    get "/u/session/delete", UserController, :delete
    get "/u/:username", UserController, :profile
    get "/u/:username/settings", UserController, :settings
  end

  scope "/", GabblerWeb do
    pipe_through [:browser, :live_browser]

    # GABBLER
    live "/", House.AllLive, :all
    live "/h/all", House.AllLive, :all
    live "/h/tag_tracker", House.TagTrackerLive, :tag_tracker

    # GABBLER -> ROOM
    live "/r/:room", Room.IndexLive, :index
    live "/r/:room/view/:mode", Room.IndexLive, :index
    live "/room/new", Room.NewLive, :new

    # GABBLER -> MODERATION
    live "/moderation", User.ModerationLive, :index

    # GABBLER -> ROOM -> POST
    live "/r/:room/new_post", Post.NewLive, :new
    live "/r/:room/comments/:hash/:title", Post.IndexLive, :index
    live "/r/:room/comments/:hash/:title/view/:mode", Post.IndexLive, :index
    live "/r/:room/comments/:hash/", Post.IndexLive, :index
    live "/r/:room/comments/:hash/view/:mode", Post.IndexLive, :index
    live "/r/:room/comments/:hash/:title/focus/:focushash", Post.IndexLive, :index
    live "/r/:room/comments/:hash/focus/:focushash", Post.IndexLive, :index
    live "/r/:room/comments/focus/:focushash", Post.IndexLive, :index
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test, :prod] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: GabblerWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", GabblerWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/login", UserSessionController, :new
    post "/users/login", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", GabblerWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/logout", UserSessionController, :delete
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings/update_password", UserSettingsController, :update_password
    put "/users/settings/update_email", UserSettingsController, :update_email
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GabblerWeb do
    pipe_through [:browser]

    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm
  end
end
