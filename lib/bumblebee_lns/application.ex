defmodule BumblebeeLns.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    :ok = :bumblebee_db.ensure_tables()
    :ok = maybe_start_erlang_reloader()

    children = [
      {Phoenix.PubSub, name: BumblebeeLns.PubSub},
      %{
        id: :bumblebee_runtime,
        start: {:bumblebee_sup, :start_link, []},
        type: :supervisor
      },
      BumblebeeLnsWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BumblebeeLns.Supervisor)
  end

  defp maybe_start_erlang_reloader do
    if Application.get_env(:bumblebee_lns, :erlang_code_reloader, false) do
      :bumblebee_reloader.start()
    else
      :ok
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    BumblebeeLnsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
