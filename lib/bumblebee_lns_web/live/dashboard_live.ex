defmodule BumblebeeLnsWeb.DashboardLive do
  use BumblebeeLnsWeb, :live_view

  alias BumblebeeLnsWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       udp_port: Application.get_env(:bumblebee_lns, :packet_forwarder_listen, [])[:port],
       node_name: node()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} socket={@socket} current_url={@current_url}>
      <div id="dashboard-page" class="space-y-6">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-base-content/60 text-sm font-medium">Runtime overview</p>
            <h1 class="text-base-content text-3xl font-semibold">Bumblebee LNS</h1>
          </div>
          <.link navigate={~p"/areas"} class="btn btn-primary">
            <Backpex.HTML.CoreComponents.icon name="hero-map" class="size-5" /> Manage areas
          </.link>
        </div>

        <section class="grid gap-4 md:grid-cols-3">
          <article class="card bg-base-100 border-base-300 border shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
            <div class="card-body gap-3">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-base">UDP LNS</h2>
                <span class="badge badge-success">Running</span>
              </div>
              <p class="text-base-content/70 text-sm">Packet forwarder port</p>
              <code class="bg-base-200 rounded-field px-2 py-1 text-sm">{@udp_port}</code>
            </div>
          </article>

          <article class="card bg-base-100 border-base-300 border shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
            <div class="card-body gap-3">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-base">Basic Station</h2>
                <span class="badge badge-success">Running</span>
              </div>
              <p class="text-base-content/70 text-sm">WebSocket endpoint</p>
              <code class="bg-base-200 rounded-field px-2 py-1 text-sm">/router-info/:mac</code>
            </div>
          </article>

          <article class="card bg-base-100 border-base-300 border shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
            <div class="card-body gap-3">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-base">Mnesia</h2>
                <span class="badge badge-success">Available</span>
              </div>
              <p class="text-base-content/70 text-sm">BEAM node</p>
              <code class="bg-base-200 rounded-field px-2 py-1 text-sm">{@node_name}</code>
            </div>
          </article>
        </section>
      </div>
    </Layouts.admin>
    """
  end
end
