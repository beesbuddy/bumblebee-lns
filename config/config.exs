import Config

config :backpex,
  translator_function: {BumblebeeLnsWeb.CoreComponents, :translate_backpex},
  error_translator_function: {BumblebeeLnsWeb.CoreComponents, :translate_error}

config :bumblebee_lns,
  generators: [timestamp_type: :utc_datetime],
  applications: [{"semtech-mote", :bumblebee_application_semtech_mote}],
  connectors: [
    bumblebee_connector_amqp: ["amqp", "amqps"],
    bumblebee_connector_mqtt: ["mqtt", "mqtts"],
    bumblebee_connector_http: ["http", "https"],
    bumblebee_connector_mongodb: ["mongodb"],
    bumblebee_connector_ws: ["ws"]
  ],
  packet_forwarder_listen: [port: 1680],
  http_admin_credentials: {"admin", "admin"},
  http_extra_headers: %{},
  ssl_options: [],
  map_tile_server: "http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
  frames_before_adr: 50,
  retained_rxframes: 50,
  websocket_timeout: 3_600_000,
  devstat_gap: {432_000, 96},
  max_lost_after_reset: 10,
  gateway_delay: 200,
  deduplication_delay: 200,
  server_stats_interval: 60,
  slack_server: {~c"slack.com", 443},
  connector_monitor_period: 10_000,
  trim_interval: 3_600,
  event_lifetime: 86_400

config :bumblebee_lns, BumblebeeLnsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [formats: [html: BumblebeeLnsWeb.ErrorHTML], layout: false],
  pubsub_server: BumblebeeLns.PubSub,
  live_view: [signing_salt: "bumblebee-live"],
  secret_key_base: "WmQ7Sx4nxp5tEuKFnq6g7hpsJr5ZkNjbzM8gYhEuQGf4HgJp7eVc2mKa8yPb6tRq"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  bumblebee_lns: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  bumblebee_lns: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
