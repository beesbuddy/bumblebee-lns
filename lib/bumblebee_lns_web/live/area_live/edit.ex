defmodule BumblebeeLnsWeb.AreaLive.Edit do
  use BumblebeeLnsWeb, :live_view

  alias BumblebeeLns.Areas

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Areas.get_area(name) do
      {:ok, area} ->
        {:ok,
         assign(socket,
           page_title: "Edit area #{area.name}",
           area: area,
           form: to_form(form_params(area), as: :area),
           errors: %{},
           administrators: Areas.list_administrators(),
           regions: Areas.regions()
         )}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Area not found.")
         |> redirect(to: ~p"/areas")}
    end
  end

  @impl true
  def handle_event("save", %{"area" => params}, socket) do
    case Areas.update_area(socket.assigns.area.name, params) do
      {:ok, area} ->
        {:noreply,
         socket
         |> put_flash(:info, "Area #{area.name} updated.")
         |> push_navigate(to: ~p"/areas")}

      {:error, errors} ->
        {:noreply,
         assign(socket,
           form: to_form(params, as: :area),
           errors: errors
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="page-header">
      <div>
        <p class="eyebrow">Infrastructure</p>
        <h1>Edit area</h1>
        <p class="muted">{@area.name}</p>
      </div>
      <.link navigate={~p"/areas"} class="button secondary">Back to areas</.link>
    </header>

    <section class="card form-card">
      <.form for={@form} id="area-form" phx-submit="save">
        <div class="field">
          <label for="area-name">Name</label>
          <input id="area-name" type="text" value={@area.name} disabled />
        </div>

        <div class="field">
          <label for={@form[:region].id}>Region</label>
          <select id={@form[:region].id} name={@form[:region].name}>
            <option
              :for={{label, description} <- @regions}
              value={label}
              selected={label == @form[:region].value}
            >
              {description}
            </option>
          </select>
          <span :if={@errors[:region]} class="field-error">{@errors[:region]}</span>
        </div>

        <fieldset class="field">
          <legend>Administrators</legend>
          <p :if={@administrators == []} class="muted">No users are available.</p>
          <label :for={admin <- @administrators} class="check-row">
            <input
              type="checkbox"
              name="area[admins][]"
              value={admin}
              checked={admin in selected_admins(@form[:admins].value)}
            />
            <span>{admin}</span>
          </label>
        </fieldset>

        <div class="field">
          <label for={@form[:slack_channel].id}>Slack channel</label>
          <input
            id={@form[:slack_channel].id}
            name={@form[:slack_channel].name}
            type="text"
            value={@form[:slack_channel].value}
          />
        </div>

        <label class="check-row field">
          <input
            type="checkbox"
            name={@form[:log_ignored].name}
            value="true"
            checked={@form[:log_ignored].value in [true, "true", "on", "1"]}
          />
          <span>Log ignored nodes</span>
        </label>

        <p :if={@errors[:base]} class="field-error">{@errors[:base]}</p>

        <div class="form-actions">
          <button type="submit" class="button">Save area</button>
          <.link navigate={~p"/areas"} class="button secondary">Cancel</.link>
        </div>
      </.form>
    </section>
    """
  end

  defp form_params(area) do
    %{
      "region" => area.region,
      "admins" => area.admins,
      "slack_channel" => area.slack_channel,
      "log_ignored" => area.log_ignored
    }
  end

  defp selected_admins(value), do: value |> List.wrap() |> Enum.map(&to_string/1)
end
