import Config

config :bumblebee_lns, packet_forwarder_listen: [port: 0]

config :bumblebee_lns, BumblebeeLnsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 0],
  server: false,
  secret_key_base: "test-only-secret-key-base-that-is-at-least-sixty-four-bytes-long-123456789"

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
