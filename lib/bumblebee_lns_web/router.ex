defmodule BumblebeeLnsWeb.Router do
  use BumblebeeLnsWeb, :router
  import Backpex.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug Backpex.ThemeSelectorPlug
    plug :put_root_layout, html: {BumblebeeLnsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", BumblebeeLnsWeb do
    pipe_through :browser

    live_session :admin, on_mount: Backpex.InitAssigns do
      live "/", DashboardLive, :index
      live_resources("/networks", NetworkLive, only: [:index, :new, :edit])
      live_resources("/areas", AreaLive, only: [:index, :new, :edit])
      live_resources("/gateways", GatewayLive, only: [:index, :new, :edit])
      live_resources("/groups", GroupLive, only: [:index, :new, :edit])
      live_resources("/profiles", ProfileLive, only: [:index, :new, :edit])
      live_resources("/devices", DeviceLive, only: [:index, :new, :edit])
      live_resources("/nodes", NodeLive, only: [:index, :new, :edit])
      live_resources("/ignored_nodes", IgnoredNodeLive, only: [:index, :new, :edit])
    end

    backpex_routes()
  end
end
