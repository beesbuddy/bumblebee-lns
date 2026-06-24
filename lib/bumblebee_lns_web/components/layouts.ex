defmodule BumblebeeLnsWeb.Layouts do
  use BumblebeeLnsWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :fluid?, :boolean, default: false
  attr :live_resource, :atom, default: nil
  attr :socket, :any, required: true
  attr :current_url, :string, default: ""
  slot :inner_block, required: true

  def admin(assigns) do
    assigns =
      assigns
      |> assign_new(:current_url, fn -> "" end)
      |> assign(:themes, themes())

    ~H"""
    <Backpex.HTML.Layout.app_shell fluid={@fluid?} live_resource={@live_resource}>
      <:topbar>
        <Backpex.HTML.Layout.topbar_branding title="Bumblebee LNS">
          <:logo>
            <div class="bg-primary text-primary-content flex size-8 items-center justify-center rounded-field font-bold">
              B
            </div>
          </:logo>
        </Backpex.HTML.Layout.topbar_branding>

        <Backpex.HTML.Layout.theme_selector socket={@socket} themes={@themes} />

        <Backpex.HTML.Layout.topbar_dropdown>
          <:label>
            <div class="btn btn-square btn-ghost">
              <Backpex.HTML.CoreComponents.icon name="hero-user-circle" class="size-6" />
            </div>
          </:label>
          <li>
            <.link navigate={~p"/"} class="flex justify-between hover:bg-base-200">
              <span>Dashboard</span>
              <Backpex.HTML.CoreComponents.icon name="hero-arrow-right" class="size-5" />
            </.link>
          </li>
        </Backpex.HTML.Layout.topbar_dropdown>
      </:topbar>
      <:sidebar>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/"}>
          <Backpex.HTML.CoreComponents.icon name="hero-home" class="size-5" /> Dashboard
        </Backpex.HTML.Layout.sidebar_item>

        <Backpex.HTML.Layout.sidebar_section id="network">
          <:label>
            <Backpex.HTML.CoreComponents.icon name="hero-signal" class="size-5" /> Network
          </:label>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/areas"}>
            <Backpex.HTML.CoreComponents.icon name="hero-map" class="size-5" /> Areas
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} href="#">
            <Backpex.HTML.CoreComponents.icon name="hero-radio" class="size-5" /> Gateways
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} href="#">
            <Backpex.HTML.CoreComponents.icon name="hero-cube" class="size-5" /> Applications
          </Backpex.HTML.Layout.sidebar_item>
        </Backpex.HTML.Layout.sidebar_section>

        <Backpex.HTML.Layout.sidebar_section id="operations">
          <:label>
            <Backpex.HTML.CoreComponents.icon name="hero-wrench-screwdriver" class="size-5" />
            Operations
          </:label>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} href="#">
            <Backpex.HTML.CoreComponents.icon name="hero-arrow-path-rounded-square" class="size-5" />
            Connectors
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} href="#">
            <Backpex.HTML.CoreComponents.icon name="hero-chart-bar-square" class="size-5" /> Traffic
          </Backpex.HTML.Layout.sidebar_item>
        </Backpex.HTML.Layout.sidebar_section>
      </:sidebar>
      <Backpex.HTML.Layout.flash_messages flash={@flash} />
      {render_slot(@inner_block)}
    </Backpex.HTML.Layout.app_shell>
    """
  end

  defp themes do
    [
      {"Light", "light"},
      {"Dark", "dark"},
      {"Cupcake", "cupcake"},
      {"Bumblebee", "bumblebee"},
      {"Emerald", "emerald"},
      {"Corporate", "corporate"},
      {"Synthwave", "synthwave"},
      {"Retro", "retro"},
      {"Cyberpunk", "cyberpunk"},
      {"Valentine", "valentine"},
      {"Halloween", "halloween"},
      {"Garden", "garden"},
      {"Forest", "forest"},
      {"Aqua", "aqua"},
      {"Lofi", "lofi"},
      {"Pastel", "pastel"},
      {"Fantasy", "fantasy"},
      {"Wireframe", "wireframe"},
      {"Black", "black"},
      {"Luxury", "luxury"},
      {"Dracula", "dracula"},
      {"CMYK", "cmyk"},
      {"Autumn", "autumn"},
      {"Business", "business"},
      {"Acid", "acid"},
      {"Lemonade", "lemonade"},
      {"Night", "night"},
      {"Coffee", "coffee"},
      {"Winter", "winter"},
      {"Dim", "dim"},
      {"Nord", "nord"},
      {"Sunset", "sunset"}
    ]
  end
end
