import Config

config :bumblebee_lns, packet_forwarder_listen: [port: 0]

config :bumblebee_lns, BumblebeeLnsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 0],
  server: false,
  secret_key_base: "test-only-secret-key-base-that-is-at-least-sixty-four-bytes-long-123456789"

config :logger, level: :warning
