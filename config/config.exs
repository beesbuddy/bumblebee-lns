import Config

config :bumblebee_lns,
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

import_config "#{config_env()}.exs"
