defmodule BumblebeeLnsWeb.Router do
  use BumblebeeLnsWeb, :router
  import Backpex.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BumblebeeLnsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", BumblebeeLnsWeb do
    pipe_through :browser
    live "/", DashboardLive, :index

    live_session :admin, on_mount: Backpex.InitAssigns do
      live_resources("/areas", AreaLive, only: [:index, :edit])
    end
  end

  backpex_routes()
end
