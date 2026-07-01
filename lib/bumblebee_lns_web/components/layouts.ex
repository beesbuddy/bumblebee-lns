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

    assigns = assign(assigns, :breadcrumbs, breadcrumbs(assigns))

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
      <:sidebar class="app-sidebar-scrollbarless">
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/"}>
          <Backpex.HTML.CoreComponents.icon name="hero-home" class="size-5" /> Dashboard
        </Backpex.HTML.Layout.sidebar_item>

        <Backpex.HTML.Layout.sidebar_section id="server">
          <:label>
            <Backpex.HTML.CoreComponents.icon name="hero-server-stack" class="size-5" /> Server
          </:label>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/users"}>
            <Backpex.HTML.CoreComponents.icon name="hero-user" class="size-5" /> Users
          </Backpex.HTML.Layout.sidebar_item>
        </Backpex.HTML.Layout.sidebar_section>

        <Backpex.HTML.Layout.sidebar_section id="network">
          <:label>
            <Backpex.HTML.CoreComponents.icon name="hero-signal" class="size-5" /> Network
          </:label>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/networks"}>
            <Backpex.HTML.CoreComponents.icon name="hero-cloud" class="size-5" /> Networks
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/areas"}>
            <Backpex.HTML.CoreComponents.icon name="hero-map" class="size-5" /> Areas
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/gateways"}>
            <Backpex.HTML.CoreComponents.icon name="hero-radio" class="size-5" /> Gateways
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} href="#">
            <Backpex.HTML.CoreComponents.icon name="hero-cube" class="size-5" /> Applications
          </Backpex.HTML.Layout.sidebar_item>
        </Backpex.HTML.Layout.sidebar_section>

        <Backpex.HTML.Layout.sidebar_section id="devices">
          <:label>
            <Backpex.HTML.CoreComponents.icon name="hero-cube-transparent" class="size-5" /> Devices
          </:label>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/groups"}>
            <Backpex.HTML.CoreComponents.icon name="hero-squares-2x2" class="size-5" /> Groups
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/profiles"}>
            <Backpex.HTML.CoreComponents.icon name="hero-adjustments-horizontal" class="size-5" />
            Profiles
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/devices"}>
            <Backpex.HTML.CoreComponents.icon name="hero-cube" class="size-5" /> Commissioned
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/nodes"}>
            <Backpex.HTML.CoreComponents.icon name="hero-rss" class="size-5" /> Activated
          </Backpex.HTML.Layout.sidebar_item>

          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/ignored_nodes"}>
            <Backpex.HTML.CoreComponents.icon name="hero-no-symbol" class="size-5" /> Ignored
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
      <.admin_breadcrumbs breadcrumbs={@breadcrumbs} />
      {render_slot(@inner_block)}
    </Backpex.HTML.Layout.app_shell>
    """
  end

  attr :breadcrumbs, :list, required: true

  def admin_breadcrumbs(assigns) do
    ~H"""
    <nav
      :if={@breadcrumbs != []}
      id="admin-breadcrumbs"
      class="mb-5 flex min-w-0 items-center gap-2 text-sm"
      aria-label="Breadcrumb"
    >
      <%= for breadcrumb <- @breadcrumbs do %>
        <Backpex.HTML.CoreComponents.icon
          :if={not breadcrumb.first?}
          name="hero-chevron-right"
          class="text-base-content/35 size-4 shrink-0 self-center"
        />
        <div class="flex min-w-0 items-center">
          <span class="text-base-content min-w-0 text-xl font-semibold leading-relaxed">
            <.link
              :if={not breadcrumb.current?}
              navigate={breadcrumb.path}
              class="text-base-content/60 hover:text-primary truncate transition-colors"
            >
              {breadcrumb.label}
            </.link>
            <span
              :if={breadcrumb.current?}
              class="text-base-content truncate font-medium"
              aria-current="page"
            >
              {breadcrumb.label}
            </span>
          </span>
        </div>
      <% end %>
    </nav>
    """
  end

  defp themes do
    [
      {"Light", "light"},
      {"Dark", "dark"},
      {"Bumblebee", "bumblebee"}
    ]
  end

  defp breadcrumbs(assigns) do
    path =
      assigns
      |> Map.get(:current_url, "/")
      |> current_path()

    live_resource = Map.get(assigns, :live_resource)
    live_action = Map.get(assigns, :live_action)
    resource_path = resource_path(path)

    crumbs =
      if resource_path == "/" do
        [%{label: "Dashboard", path: "/", current?: true}]
      else
        [
          %{label: "Dashboard", path: "/", current?: false},
          %{
            label: resource_label(resource_path, live_resource),
            path: resource_path,
            current?: live_action in [nil, :index]
          }
        ] ++ action_breadcrumbs(live_action, live_resource)
      end

    Enum.with_index(crumbs, fn crumb, index -> Map.put(crumb, :first?, index == 0) end)
  end

  defp current_path(""), do: "/"

  defp current_path(current_url) do
    current_url
    |> URI.parse()
    |> Map.get(:path)
    |> normalize_path()
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path("/"), do: "/"

  defp normalize_path(path) do
    path
    |> String.trim_trailing("/")
    |> then(fn
      "" -> "/"
      path -> path
    end)
  end

  defp resource_path("/"), do: "/"

  defp resource_path(path) do
    case String.split(path, "/", trim: true) do
      [] -> "/"
      [resource | _rest] -> "/" <> resource
    end
  end

  defp resource_label(_path, live_resource)
       when is_atom(live_resource) and not is_nil(live_resource) do
    live_resource.plural_name()
  end

  defp resource_label(path, _live_resource) do
    Map.get(route_labels(), path, path |> String.trim_leading("/") |> Phoenix.Naming.humanize())
  end

  defp action_breadcrumbs(:new, live_resource)
       when is_atom(live_resource) and not is_nil(live_resource) do
    [%{label: "New #{live_resource.singular_name()}", path: nil, current?: true}]
  end

  defp action_breadcrumbs(:edit, live_resource)
       when is_atom(live_resource) and not is_nil(live_resource) do
    [%{label: "Edit #{live_resource.singular_name()}", path: nil, current?: true}]
  end

  defp action_breadcrumbs(:resource_action, _live_resource) do
    [%{label: "Action", path: nil, current?: true}]
  end

  defp action_breadcrumbs(_live_action, _live_resource), do: []

  defp route_labels do
    %{
      "/areas" => "Areas",
      "/devices" => "Commissioned Devices",
      "/gateways" => "Gateways",
      "/groups" => "Groups",
      "/ignored_nodes" => "Ignored Nodes",
      "/networks" => "Networks",
      "/nodes" => "Activated Nodes",
      "/profiles" => "Profiles",
      "/users" => "Users"
    }
  end
end
