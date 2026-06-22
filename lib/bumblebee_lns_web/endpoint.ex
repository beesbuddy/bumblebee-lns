defmodule BumblebeeLnsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :bumblebee_lns

  @session_options [
    store: :cookie,
    key: "_bumblebee_lns_key",
    signing_salt: "bumblebee-session",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.Static,
    at: "/assets/phoenix",
    from: {:phoenix, "priv/static"},
    only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/assets/live_view",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Jason
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug BumblebeeLnsWeb.Router
end
