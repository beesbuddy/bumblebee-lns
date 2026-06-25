defmodule BumblebeeLnsWeb.Backpex.Fields.LocationMap do
  @moduledoc false

  @config_schema [
    latitude_input: [
      doc: "DOM id of the latitude input controlled by the map.",
      type: :string,
      required: true
    ],
    longitude_input: [
      doc: "DOM id of the longitude input controlled by the map.",
      type: :string,
      required: true
    ],
    tile_url: [
      doc: "Leaflet tile layer URL.",
      type: :string,
      required: true
    ]
  ]

  use Backpex.Field, config_schema: @config_schema

  @impl Backpex.Field
  def render_value(assigns) do
    ~H"""
    <p></p>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label for="gateway-location-map" text={@field_options[:label]} />
        </:label>
        <div
          id="gateway-location-map"
          class="gateway-location-map"
          phx-hook="GatewayLocationMap"
          phx-update="ignore"
          data-latitude-input={@field_options[:latitude_input]}
          data-longitude-input={@field_options[:longitude_input]}
          data-tile-url={@field_options[:tile_url]}
        >
        </div>
      </Layout.field_container>
    </div>
    """
  end
end
