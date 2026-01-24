defmodule ProductiveWorkgroupsWeb.Router do
  use ProductiveWorkgroupsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProductiveWorkgroupsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ProductiveWorkgroupsWeb do
    pipe_through :browser

    # Home page - create new session
    live "/", HomeLive, :index

    # Session routes
    live "/session/new", SessionLive.New, :new
    live "/session/:code", SessionLive.Show, :show
    live "/session/:code/join", SessionLive.Join, :join

    # Controller routes (for actions that need to set session)
    post "/session/:code/join", SessionController, :join
  end

  # Development routes
  if Application.compile_env(:productive_workgroups, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ProductiveWorkgroupsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
