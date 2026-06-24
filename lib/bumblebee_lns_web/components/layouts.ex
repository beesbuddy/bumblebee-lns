defmodule BumblebeeLnsWeb.Layouts do
  use BumblebeeLnsWeb, :html
  import BumblebeeLnsWeb.CoreComponents

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :fluid?, :boolean, default: false
  attr :live_resource, :atom, required: true
  attr :current_url, :string, default: ""
  slot :inner_block, required: true

  def admin(assigns) do
    assigns = assign_new(assigns, :current_url, fn -> "" end)

    ~H"""
    <Backpex.HTML.Layout.app_shell fluid={@fluid?} live_resource={@live_resource}>
      <:topbar>
        <.link navigate={~p"/"} class="text-lg font-semibold">Bumblebee LNS</.link>
      </:topbar>
      <:sidebar>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/areas"}>
          Areas
        </Backpex.HTML.Layout.sidebar_item>
      </:sidebar>
      <Backpex.HTML.Layout.flash_messages flash={@flash} />
      {render_slot(@inner_block)}
    </Backpex.HTML.Layout.app_shell>
    """
  end
end
