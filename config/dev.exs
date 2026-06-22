import Config

config :bumblebee_lns, erlang_code_reloader: true

config :bumblebee_lns, BumblebeeLnsWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("PHX_PORT", "8080")),
    dispatch: [
      {:_,
       [
         {"/router-info/[:mac]", :bumblebee_gw_lns, []},
         {:_, Plug.Cowboy.Handler, {BumblebeeLnsWeb.Endpoint, []}}
       ]}
    ]
  ],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: []

config :logger, :console, format: "[$level] $message\n"
