defmodule BumblebeeLnsWeb.GatewayLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Gateways
  alias BumblebeeLns.Gateways.Gateway

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Gateway,
      list: &Gateways.list_gateways/0,
      get: &Gateways.get_gateway/1,
      create: &Gateways.create_gateway/1,
      update: &Gateways.update_gateway/2,
      create_changeset: &Gateway.changeset/3,
      update_changeset: &Gateway.changeset/3
    ],
    primary_key: :mac,
    init_order: %{by: :mac, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "gateways"]

  @impl Backpex.LiveResource
  def singular_name, do: "Gateway"

  @impl Backpex.LiveResource
  def plural_name, do: "Gateways"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def fields do
    [
      mac: %{
        module: Backpex.Fields.Text,
        label: "MAC",
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      area: %{
        module: Backpex.Fields.Select,
        label: "Area",
        options: fn _assigns -> Gateways.list_area_options() end,
        prompt: "No area"
      },
      tx_rfch: %{
        module: Backpex.Fields.Number,
        label: "TX RF chain"
      },
      ant_gain: %{
        module: Backpex.Fields.Number,
        label: "Antenna gain"
      },
      desc: %{
        module: Backpex.Fields.Textarea,
        label: "Description",
        rows: 3,
        searchable: true
      },
      location_map: %{
        module: BumblebeeLnsWeb.Backpex.Fields.LocationMap,
        label: "Location",
        latitude_input: "resource-form_latitude",
        longitude_input: "resource-form_longitude",
        tile_url: Application.get_env(:bumblebee_lns, :map_tile_server),
        only: [:new, :edit],
        orderable: false
      },
      latitude: %{
        module: Backpex.Fields.Number,
        label: "Latitude",
        orderable: false
      },
      longitude: %{
        module: Backpex.Fields.Number,
        label: "Longitude",
        orderable: false
      },
      gpsalt: %{
        module: Backpex.Fields.Number,
        label: "GPS altitude",
        orderable: false
      },
      last_alive: %{
        module: Backpex.Fields.Text,
        label: "Last alive",
        readonly: true
      },
      health_alerts: %{
        module: Backpex.Fields.MultiSelect,
        label: "Health alerts",
        options: fn _assigns -> [] end,
        only: [:index],
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: Keyword.take(default_actions, [:edit])

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit]
end
