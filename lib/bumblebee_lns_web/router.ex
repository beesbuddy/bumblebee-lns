defmodule BumblebeeLnsWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

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
    live "/areas", AreaLive.Index, :index
    live "/areas/:name/edit", AreaLive.Edit, :edit
  end
end
