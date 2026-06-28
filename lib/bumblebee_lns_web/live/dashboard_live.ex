defmodule BumblebeeLnsWeb.DashboardLive do
  use BumblebeeLnsWeb, :live_view

  alias BumblebeeLns.Dashboard
  alias BumblebeeLnsWeb.Layouts

  @traffic_window_keys ~w(15m 1h 6h 24h 7d all)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:traffic_window_key, "1h")
     |> assign(:traffic_window_offset, 0)
     |> assign(:traffic_custom_window, nil)
     |> assign_dashboard()}
  end

  @impl true
  def handle_event("set_traffic_window", %{"window" => window}, socket) do
    {:noreply,
     socket
     |> assign(:traffic_window_key, window)
     |> assign(:traffic_window_offset, 0)
     |> assign(:traffic_custom_window, nil)
     |> assign_dashboard()}
  end

  def handle_event("shift_traffic_window", %{"direction" => direction}, socket) do
    shift =
      case direction do
        "previous" -> -1
        "next" -> 1
        _ -> 0
      end

    socket =
      if socket.assigns.traffic_custom_window do
        window = socket.assigns.traffic_custom_window

        assign(
          socket,
          :traffic_custom_window,
          Dashboard.shift_traffic_window(window, shift * window.duration)
        )
      else
        offset = min(socket.assigns.traffic_window_offset + shift, 0)
        assign(socket, :traffic_window_offset, offset)
      end

    {:noreply, assign_dashboard(socket)}
  end

  def handle_event("reset_traffic_window", _params, socket) do
    {:noreply,
     socket
     |> assign(:traffic_window_offset, 0)
     |> assign(:traffic_custom_window, nil)
     |> assign_dashboard()}
  end

  def handle_event("pan_traffic_window", %{"seconds" => seconds}, socket) do
    with %{duration: duration} when is_integer(duration) <- socket.assigns.traffic_window,
         {seconds, _rest} <- Float.parse(to_string(seconds)) do
      socket =
        if socket.assigns.traffic_custom_window do
          window = Dashboard.shift_traffic_window(socket.assigns.traffic_custom_window, seconds)
          assign(socket, :traffic_custom_window, window)
        else
          offset =
            socket.assigns.traffic_window_offset
            |> Kernel.+(seconds / duration)
            |> min(0)

          assign(socket, :traffic_window_offset, offset)
        end

      {:noreply, assign_dashboard(socket)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("zoom_traffic_window", %{"direction" => direction, "anchor" => anchor}, socket) do
    with {anchor, _rest} <- Float.parse(to_string(anchor)),
         %{duration: duration} when is_integer(duration) <- socket.assigns.traffic_window do
      window =
        socket.assigns.traffic_window
        |> Dashboard.zoom_traffic_interval(anchor - 0.25, anchor + 0.25, direction)

      {:noreply,
       socket
       |> assign(:traffic_window_key, "custom")
       |> assign(:traffic_window_offset, 0)
       |> assign(:traffic_custom_window, window)
       |> assign_dashboard()}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("zoom_traffic_window", %{"direction" => direction}, socket) do
    window_key = adjacent_traffic_window(socket.assigns.traffic_window_key, direction)

    {:noreply,
     socket
     |> assign(:traffic_window_key, window_key)
     |> assign(:traffic_window_offset, 0)
     |> assign(:traffic_custom_window, nil)
     |> assign_dashboard()}
  end

  def handle_event("zoom_traffic_interval", params, socket) do
    with {start_ratio, _rest} <- Float.parse(to_string(params["start"])),
         {end_ratio, _rest} <- Float.parse(to_string(params["end"])) do
      mode = Map.get(params, "mode", "in")

      window =
        Dashboard.zoom_traffic_interval(
          socket.assigns.traffic_window,
          start_ratio,
          end_ratio,
          mode
        )

      {:noreply,
       socket
       |> assign(:traffic_window_key, "custom")
       |> assign(:traffic_window_offset, 0)
       |> assign(:traffic_custom_window, window)
       |> assign_dashboard()}
    else
      _ -> {:noreply, socket}
    end
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
          id="dashboard-traffic-graph"
          data-vega-lite-spec={Jason.encode!(@traffic_chart.vega_lite_spec)}
          class="bg-base-100 border-base-300 rounded-box border shadow-sm"
        >
          <div class="border-base-300 flex items-center justify-between border-b px-5 py-4">
            <div>
              <h2 class="text-base-content text-lg font-semibold">Observability Graph</h2>
              <p class="text-base-content/60 text-sm">
                Router traffic with incidents and frame activity over time
              </p>
            </div>
            <div class="flex flex-wrap items-center justify-end gap-2">
              <button
                id="dashboard-traffic-window-previous"
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="shift_traffic_window"
                phx-value-direction="previous"
                disabled={@traffic_window.key == "all"}
              >
                <Backpex.HTML.CoreComponents.icon name="hero-chevron-left" class="size-4" />
              </button>
              <button
                :for={{key, label} <- @traffic_windows}
                id={"dashboard-traffic-window-#{key}"}
                type="button"
                class={[
                  "btn btn-sm",
                  if(@traffic_window.key == key, do: "btn-primary", else: "btn-ghost")
                ]}
                phx-click="set_traffic_window"
                phx-value-window={key}
              >
                {label}
              </button>
              <button
                id="dashboard-traffic-window-next"
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="shift_traffic_window"
                phx-value-direction="next"
                disabled={@traffic_window.key == "all" or @traffic_window.offset == 0}
              >
                <Backpex.HTML.CoreComponents.icon name="hero-chevron-right" class="size-4" />
              </button>
              <button
                id="dashboard-traffic-zoom-in"
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="zoom_traffic_window"
                phx-value-direction="in"
                disabled={@traffic_window.key == "15m"}
              >
                <Backpex.HTML.CoreComponents.icon name="hero-magnifying-glass-plus" class="size-4" />
              </button>
              <button
                id="dashboard-traffic-zoom-out"
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="zoom_traffic_window"
                phx-value-direction="out"
                disabled={@traffic_window.key == "all"}
              >
                <Backpex.HTML.CoreComponents.icon name="hero-magnifying-glass-minus" class="size-4" />
              </button>
              <button
                id="dashboard-traffic-window-reset"
                type="button"
                class="btn btn-sm btn-outline"
                phx-click="reset_traffic_window"
                disabled={@traffic_window.key == "all" or @traffic_window.offset == 0}
              >
                Now
              </button>
            </div>
          </div>
          <div class="border-base-300 flex flex-wrap items-center justify-between gap-3 border-b px-5 py-3">
            <div class="text-base-content/70 text-sm">
              <span :if={@traffic_window.key == "all"}>Showing all available telemetry</span>
              <span :if={@traffic_window.key != "all"}>
                {Dashboard.format_datetime(@traffic_window.start_at)} - {Dashboard.format_datetime(
                  @traffic_window.end_at
                )}
              </span>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <span class="inline-flex items-center gap-1.5 text-xs font-medium">
                <span class="bg-primary size-2.5 rounded-full"></span> Requests
              </span>
              <span class="inline-flex items-center gap-1.5 text-xs font-medium">
                <span class="bg-error size-2.5 rounded-full"></span> Errors
              </span>
              <span class="inline-flex items-center gap-1.5 text-xs font-medium">
                <span class="bg-warning size-2.5 rounded-full"></span> Events
              </span>
              <span class="inline-flex items-center gap-1.5 text-xs font-medium">
                <span class="bg-info size-2.5 rounded-full"></span> Frames
              </span>
            </div>
          </div>
          <div class="p-5">
            <div
              :if={!@traffic_chart.has_data?}
              class="text-base-content/60 py-12 text-center text-sm"
            >
              No observability data available for this window.
            </div>
            <div
              :if={@traffic_chart.has_data?}
              id="dashboard-traffic-graph-navigator"
              class="relative min-h-72 cursor-grab touch-pan-y select-none overflow-x-auto active:cursor-grabbing"
              phx-hook="TrafficGraphNavigator"
              data-window-key={@traffic_window.key}
              data-window-duration={@traffic_window.duration}
            >
              <svg
                id="dashboard-router-traffic-svg"
                viewBox={"0 0 #{@traffic_chart.width} #{@traffic_chart.height}"}
                role="img"
                aria-labelledby="dashboard-router-traffic-title dashboard-router-traffic-desc"
                class="h-72 min-w-[48rem] w-full"
              >
                <title id="dashboard-router-traffic-title">Router traffic graph</title>
                <desc id="dashboard-router-traffic-desc">
                  Line graph showing router requests and errors per minute with event and frame markers.
                </desc>

                <rect
                  x={@traffic_chart.plot.x}
                  y={@traffic_chart.plot.y}
                  width={@traffic_chart.plot.width}
                  height={@traffic_chart.plot.height}
                  rx="10"
                  class="fill-base-200/40"
                />

                <g :for={tick <- @traffic_chart.y_ticks}>
                  <line
                    x1={@traffic_chart.plot.x}
                    x2={@traffic_chart.plot.right}
                    y1={tick.y}
                    y2={tick.y}
                    class="stroke-base-300"
                    stroke-width="1"
                  />
                  <text
                    x={@traffic_chart.plot.x - 12}
                    y={tick.y + 4}
                    text-anchor="end"
                    class="fill-base-content/60 text-[11px]"
                  >
                    {tick.value}
                  </text>
                </g>

                <polyline
                  points={@traffic_chart.requests_path}
                  fill="none"
                  class="stroke-primary"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
                <polyline
                  points={@traffic_chart.errors_path}
                  fill="none"
                  class="stroke-error"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />

                <g :for={point <- @traffic_chart.points}>
                  <circle
                    id={"dashboard-traffic-request-#{point.id}"}
                    cx={point.x}
                    cy={point.requests_y}
                    r="4"
                    class="fill-primary transition hover:r-5"
                  >
                    <title>
                      {point.server} at {point.label}: {point.requests} requests/min
                    </title>
                  </circle>
                  <circle
                    id={"dashboard-traffic-error-#{point.id}"}
                    cx={point.x}
                    cy={point.errors_y}
                    r="4"
                    class="fill-error transition hover:r-5"
                  >
                    <title>
                      {point.server} at {point.label}: {point.errors} errors/min
                    </title>
                  </circle>
                </g>

                <g :for={tick <- @traffic_chart.x_ticks}>
                  <line
                    x1={tick.x}
                    x2={tick.x}
                    y1={@traffic_chart.plot.bottom}
                    y2={@traffic_chart.plot.bottom + 6}
                    class="stroke-base-content/30"
                    stroke-width="1"
                  />
                  <text
                    x={tick.x}
                    y={@traffic_chart.plot.bottom + 24}
                    text-anchor="middle"
                    class="fill-base-content/60 text-[11px]"
                  >
                    {tick.short_label}
                  </text>
                </g>

                <line
                  x1={@traffic_chart.plot.x}
                  x2={@traffic_chart.plot.right}
                  y1={@traffic_chart.height - 58}
                  y2={@traffic_chart.height - 58}
                  class="stroke-base-300"
                  stroke-width="1"
                />
                <line
                  x1={@traffic_chart.plot.x}
                  x2={@traffic_chart.plot.right}
                  y1={@traffic_chart.height - 34}
                  y2={@traffic_chart.height - 34}
                  class="stroke-base-300"
                  stroke-width="1"
                />
                <text
                  x={@traffic_chart.plot.x - 12}
                  y={@traffic_chart.height - 42}
                  text-anchor="end"
                  class="fill-base-content/60 text-[11px]"
                >
                  Events
                </text>
                <text
                  x={@traffic_chart.plot.x - 12}
                  y={@traffic_chart.height - 18}
                  text-anchor="end"
                  class="fill-base-content/60 text-[11px]"
                >
                  Frames
                </text>

                <g :for={item <- @traffic_chart.observability_items}>
                  <circle
                    id={"dashboard-observability-#{item.kind}-#{item.id}"}
                    cx={item.x}
                    cy={item.y}
                    r="5"
                    class={["stroke-2 transition hover:r-6", item.class]}
                  >
                    <title>
                      {item.icon}: {item.label} at {Dashboard.format_datetime(item.started_at)} ({item.detail})
                    </title>
                  </circle>
                </g>
              </svg>
            </div>
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

  defp assign_dashboard(socket) do
    summary =
      if socket.assigns.traffic_custom_window do
        Dashboard.summary(socket.assigns.traffic_custom_window)
      else
        Dashboard.summary(socket.assigns.traffic_window_key, socket.assigns.traffic_window_offset)
      end

    assign(socket,
      udp_port: Application.get_env(:bumblebee_lns, :packet_forwarder_listen, [])[:port],
      node_name: node(),
      servers: summary.servers,
      events: summary.events,
      frames: summary.frames,
      traffic_windows: summary.traffic_windows,
      traffic_window: summary.traffic_window,
      traffic_chart: summary.traffic_chart
    )
  end

  defp adjacent_traffic_window(current, direction) do
    index = Enum.find_index(@traffic_window_keys, &(&1 == current)) || 1

    next_index =
      case direction do
        "in" -> max(index - 1, 0)
        "out" -> min(index + 1, length(@traffic_window_keys) - 1)
        _ -> index
      end

    Enum.at(@traffic_window_keys, next_index)
  end

  defp frame_badge_class("up"), do: "badge-success"
  defp frame_badge_class("down"), do: "badge-info"
  defp frame_badge_class("re-up"), do: "badge-warning"
  defp frame_badge_class(_), do: "badge-ghost"
end
