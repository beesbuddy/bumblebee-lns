defmodule BumblebeeLnsWeb.AreaLive.Index do
  use BumblebeeLnsWeb, :live_view

  alias BumblebeeLns.Areas

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Areas", areas: Areas.list_areas())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="page-header">
      <div>
        <p class="eyebrow">Infrastructure</p>
        <h1>Areas</h1>
        <p class="muted">All configured LoRaWAN areas.</p>
      </div>
    </header>

    <section class="card table-card">
      <div class="table-wrap">
        <table id="areas">
          <thead>
            <tr>
              <th>Name</th>
              <th>Region</th>
              <th>Administrators</th>
              <th>Slack channel</th>
              <th>Log ignored</th>
              <th><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@areas == []} id="areas-empty">
              <td colspan="6">No areas configured.</td>
            </tr>
            <tr :for={area <- @areas} id={"area-#{area.name}"}>
              <td><strong>{area.name}</strong></td>
              <td>{area.region}</td>
              <td>{format_admins(area.admins)}</td>
              <td>{area.slack_channel}</td>
              <td>{if area.log_ignored, do: "Yes", else: "No"}</td>
              <td class="actions">
                <.link navigate={~p"/areas/#{area.name}/edit"} class="button secondary">Edit</.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp format_admins([]), do: "—"
  defp format_admins(admins), do: Enum.join(admins, ", ")
end
