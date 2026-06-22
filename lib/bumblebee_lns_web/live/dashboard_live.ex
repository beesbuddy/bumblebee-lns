defmodule BumblebeeLnsWeb.DashboardLive do
  use BumblebeeLnsWeb, :live_view

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
    <h1>Bumblebee LNS</h1>
    <p>Phoenix LiveView is running with the Erlang LoRaWAN runtime.</p>
    <section class="status">
      <article class="card">
        <div class="ok">UDP LNS running</div>
        <p>Packet forwarder port: <code>{@udp_port}</code></p>
      </article>
      <article class="card">
        <div class="ok">Basic Station running</div>
        <p>WebSocket endpoint: <code>/router-info/:mac</code></p>
      </article>
      <article class="card">
        <div class="ok">Mnesia available</div>
        <p>BEAM node: <code>{@node_name}</code></p>
      </article>
    </section>
    """
  end
end
