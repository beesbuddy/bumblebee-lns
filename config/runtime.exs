import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PHX_PORT", "8080"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE must be set in production"

  config :bumblebee_lns, BumblebeeLnsWeb.Endpoint,
    http: [
      ip: {0, 0, 0, 0},
      port: port,
      dispatch: [
        {:_,
         [
           {"/router-info/[:mac]", :bumblebee_gw_lns, []},
           {:_, Plug.Cowboy.Handler, {BumblebeeLnsWeb.Endpoint, []}}
         ]}
      ]
    ],
    secret_key_base: secret_key_base
end
