defmodule BumblebeeLnsWeb.DashboardLive do
  use BumblebeeLnsWeb, :live_view

  alias BumblebeeLns.Dashboard
  alias BumblebeeLnsWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    summary = Dashboard.summary()

    {:ok,
     assign(socket,
       udp_port: Application.get_env(:bumblebee_lns, :packet_forwarder_listen, [])[:port],
       node_name: node(),
       servers: summary.servers,
       events: summary.events,
       frames: summary.frames,
       timeline_items: summary.timeline_items
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} socket={@socket} current_url={@current_url}>
      <div id="dashboard-page" class="space-y-6 pb-8">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-base-content/60 text-sm font-medium">Runtime overview</p>
            <h1 class="text-base-content text-3xl font-semibold">Bumblebee LNS</h1>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link navigate={~p"/areas"} class="btn btn-primary">
              <Backpex.HTML.CoreComponents.icon name="hero-map" class="size-5" /> Manage areas
            </.link>
            <.link navigate={~p"/gateways"} class="btn btn-outline">
              <Backpex.HTML.CoreComponents.icon name="hero-radio" class="size-5" /> Gateways
            </.link>
          </div>
        </div>

        <section class="grid gap-4 md:grid-cols-3">
          <.status_card
            title="UDP LNS"
            label="Packet forwarder port"
            value={@udp_port}
            status="Running"
          />
          <.status_card
            title="Basic Station"
            label="WebSocket endpoint"
            value="/router-info/:mac"
            status="Running"
          />
          <.status_card title="Mnesia" label="BEAM node" value={@node_name} status="Available" />
        </section>

        <section
          id="dashboard-timeline"
          class="bg-base-100 border-base-300 rounded-box border shadow-sm"
        >
          <div class="border-base-300 flex items-center justify-between border-b px-5 py-4">
            <div>
              <h2 class="text-base-content text-lg font-semibold">Incident Timeline</h2>
              <p class="text-base-content/60 text-sm">Recent incidents and frame activity</p>
            </div>
            <span class="badge badge-outline">{length(@timeline_items)} items</span>
          </div>
          <div class="overflow-x-auto p-5">
            <div :if={@timeline_items == []} class="text-base-content/60 py-8 text-center text-sm">
              No timeline activity available.
            </div>
            <ol :if={@timeline_items != []} class="flex min-w-max items-start gap-0">
              <li
                :for={item <- @timeline_items}
                id={"timeline-item-#{item.id}"}
                class="group relative flex w-48 flex-col items-center px-3"
              >
                <div class="bg-base-300 absolute top-4 right-0 left-0 h-px group-first:left-1/2 group-last:right-1/2">
                </div>
                <div class={[
                  "relative z-10 grid size-8 place-items-center rounded-full border-2 bg-base-100 shadow-sm",
                  timeline_border_class(item)
                ]}>
                  <Backpex.HTML.CoreComponents.icon name={timeline_icon(item)} class="size-4" />
                </div>
                <time class="text-base-content/60 mt-2 text-xs font-medium">
                  {Dashboard.format_timeline_time(item.started_at)}
                </time>
                <p class="text-base-content mt-1 max-w-40 truncate text-center text-sm font-semibold">
                  {item.label}
                </p>
                <p class="text-base-content/60 max-w-40 truncate text-center text-xs">
                  {item.detail}
                </p>
              </li>
            </ol>
          </div>
        </section>

        <section class="grid gap-4 xl:grid-cols-2">
          <.data_panel id="dashboard-servers" title="Servers" count={length(@servers)}>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Server Name</th>
                    <th>Version</th>
                    <th>Memory</th>
                    <th>Disk</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={server <- @servers} id={"dashboard-server-#{server.name}"}>
                    <td class="font-medium">{server.name}</td>
                    <td>{server.version}</td>
                    <td>{server.memory}</td>
                    <td>{server.disk}</td>
                    <td>
                      <span class={["badge gap-1", server.status.class]}>
                        <Backpex.HTML.CoreComponents.icon name={server.status.icon} class="size-4" />
                        {server.status.label}
                      </span>
                    </td>
                  </tr>
                  <tr :if={@servers == []}>
                    <td colspan="5" class="text-base-content/60 py-8 text-center">
                      No servers available.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </.data_panel>

          <.data_panel id="dashboard-events" title="Events" count={length(@events)}>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Last Occurred</th>
                    <th>Entity</th>
                    <th>Eid</th>
                    <th>Text</th>
                    <th>Args</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={event <- @events} id={"dashboard-event-#{event.id}"}>
                    <td class="whitespace-nowrap">{Dashboard.format_datetime(event.last_rx)}</td>
                    <td>{event.entity}</td>
                    <td class="font-mono text-xs">{event.eid}</td>
                    <td>{event.text}</td>
                    <td class="max-w-56 truncate">{event.args}</td>
                  </tr>
                  <tr :if={@events == []}>
                    <td colspan="5" class="text-base-content/60 py-8 text-center">
                      No events available.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </.data_panel>
        </section>

        <.data_panel id="dashboard-frames" title="Recent Frames" count={length(@frames)}>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Received</th>
                  <th>Direction</th>
                  <th>Network</th>
                  <th>Application</th>
                  <th>Device</th>
                  <th>Port</th>
                  <th>Bytes</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={frame <- @frames} id={"dashboard-frame-#{frame.id}"}>
                  <td class="whitespace-nowrap">{Dashboard.format_datetime(frame.datetime)}</td>
                  <td>
                    <span class={["badge badge-outline", frame_badge_class(frame.direction)]}>
                      {frame.direction}
                    </span>
                  </td>
                  <td>{frame.network}</td>
                  <td>{frame.app}</td>
                  <td class="font-mono text-xs">{frame.device}</td>
                  <td>{frame.port}</td>
                  <td>{frame.bytes}</td>
                </tr>
                <tr :if={@frames == []}>
                  <td colspan="7" class="text-base-content/60 py-8 text-center">
                    No frames available.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.data_panel>
      </div>
    </Layouts.admin>
    """
  end

  attr :title, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :status, :string, required: true

  defp status_card(assigns) do
    ~H"""
    <article class="card bg-base-100 border-base-300 border shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
      <div class="card-body gap-3">
        <div class="flex items-center justify-between gap-3">
          <h2 class="card-title text-base">{@title}</h2>
          <span class="badge badge-success">{@status}</span>
        </div>
        <p class="text-base-content/70 text-sm">{@label}</p>
        <code class="bg-base-200 rounded-field px-2 py-1 text-sm">{@value}</code>
      </div>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, required: true
  slot :inner_block, required: true

  defp data_panel(assigns) do
    ~H"""
    <section id={@id} class="bg-base-100 border-base-300 rounded-box border shadow-sm">
      <div class="border-base-300 flex items-center justify-between border-b px-5 py-4">
        <h2 class="text-base-content text-lg font-semibold">{@title}</h2>
        <span class="badge badge-outline">{@count}</span>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  defp timeline_icon(%{kind: :frame}), do: "hero-arrows-right-left"
  defp timeline_icon(%{severity: "error"}), do: "hero-exclamation-circle"
  defp timeline_icon(%{severity: "warning"}), do: "hero-exclamation-triangle"
  defp timeline_icon(_), do: "hero-information-circle"

  defp timeline_border_class(%{kind: :frame}), do: "border-info text-info"
  defp timeline_border_class(%{severity: "error"}), do: "border-error text-error"
  defp timeline_border_class(%{severity: "warning"}), do: "border-warning text-warning"
  defp timeline_border_class(_), do: "border-base-300 text-base-content/70"

  defp frame_badge_class("up"), do: "badge-success"
  defp frame_badge_class("down"), do: "badge-info"
  defp frame_badge_class("re-up"), do: "badge-warning"
  defp frame_badge_class(_), do: "badge-ghost"
end
