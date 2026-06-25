# Bumblebee uses MQTT over TCP/TLS. Tell emqtt's Rebar config not to pull in
# the optional QUIC NIF and its bundled native toolchain.
System.put_env("BUILD_WITHOUT_QUIC", "1")

defmodule BumblebeeLns.MixProject do
  use Mix.Project

  def project do
    [
      app: :bumblebee_lns,
      version: "0.7.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: ["src"],
      aliases: aliases(),
      erlc_options: [:debug_info, :tuple_calls, {:parse_transform, :lager_transform}],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {BumblebeeLns.Application, []},
      # eunit is on the compiler code path because several legacy modules keep
      # their EUnit tests next to the production functions.
      extra_applications: [
        :logger,
        :runtime_tools,
        :eunit,
        :sasl,
        :os_mon,
        :mnesia
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.0"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_html, "~> 4.1"},
      {:backpex, "~> 0.18.3"},
      {:ecto, "~> 3.13"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:lazy_html, "~> 0.1.0", only: :test},
      {:plug_cowboy, "~> 2.8"},
      {:jason, "~> 1.4"},
      {:lager, "~> 3.9.1"},
      {:eid, git: "https://github.com/jur0/eid.git", tag: "0.6.0"},
      {:cowlib, git: "https://github.com/ninenines/cowlib", tag: "2.16.0", override: true},
      {:cowboy, git: "https://github.com/ninenines/cowboy", tag: "2.14.2", override: true},
      {:ranch, git: "https://github.com/ninenines/ranch", tag: "1.8.1", override: true},
      {:gun, git: "https://github.com/ninenines/gun.git", tag: "2.2.0", override: true},
      {:jsx, "~> 2.10"},
      {:iso8601, "~> 1.4"},
      {:cbor,
       git: "https://github.com/yjh0502/cbor-erlang.git",
       ref: "b5c9dbc2de15753b2db15e13d88c11738c2ac292"},
      {:gen_smtp, "~> 1.3"},
      {:amqp_client, "~> 4.2"},
      {:emqtt, git: "https://github.com/emqx/emqtt.git", tag: "1.14.7"},
      {:erlmongo,
       git: "https://github.com/SergejJurecko/erlmongo.git",
       ref: "f0d03cd4592f7bf28059b81214b61c28ccf046c0"},
      {:prometheus_cowboy, "~> 0.2.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": [
        "cmd npm install --prefix assets",
        "tailwind.install --if-missing",
        "esbuild.install --if-missing"
      ],
      "assets.build": ["compile", "tailwind bumblebee_lns", "esbuild bumblebee_lns"],
      "assets.deploy": [
        "tailwind bumblebee_lns --minify",
        "esbuild bumblebee_lns --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
