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
  live_reload: [
    web_console_logger: true,
    patterns: [
      # Static assets, except user uploads
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      # Gettext translations
      ~r"priv/gettext/.*\.po$",
      # Router, Controllers, LiveViews and LiveComponents
      ~r"lib/bumblebee_lns_web/router\.ex$",
      ~r"lib/bumblebee_lns_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ],
  debug_errors: true,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:bumblebee_lns, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:bumblebee_lns, ~w(--watch)]}
  ]

config :logger, :console, format: "[$level] $message\n"

# Enable dev routes for dashboard and mailbox
config :bumblebee_lns, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
