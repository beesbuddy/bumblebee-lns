defmodule BumblebeeLnsWeb.NodeLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Devices
  alias BumblebeeLns.Devices.Node

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Node,
      list: &Devices.list_nodes/0,
      get: &Devices.get_node/1,
      create: &Devices.create_node/1,
      update: &Devices.update_node/2,
      delete: &Devices.delete_node/1,
      create_changeset: &Node.changeset/3,
      update_changeset: &Node.changeset/3
    ],
    primary_key: :devaddr,
    init_order: %{by: :devaddr, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "nodes"]

  use BumblebeeLnsWeb.Backpex.ResourceSlots

  @impl Backpex.LiveResource
  def singular_name, do: "Activated Node"

  @impl Backpex.LiveResource
  def plural_name, do: "Activated Nodes"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def fields do
    [
      devaddr: %{
        module: Backpex.Fields.Text,
        label: "DevAddr",
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      profile: %{
        module: Backpex.Fields.Select,
        label: "Profile",
        options: fn _assigns -> Devices.list_profile_options() end
      },
      nwkskey: %{module: Backpex.Fields.Text, label: "NwkSKey"},
      appskey: %{module: Backpex.Fields.Text, label: "AppSKey"},
      fcntup: %{module: Backpex.Fields.Number, label: "Uplink frame counter"},
      fcntdown: %{module: Backpex.Fields.Number, label: "Downlink frame counter"},
      adr_flag: %{
        module: Backpex.Fields.Select,
        label: "ADR",
        options: [{"Disabled", 0}, {"Enabled", 1}]
      },
      last_rx: %{module: Backpex.Fields.Text, label: "Last RX", readonly: true},
      health_alerts: %{
        module: Backpex.Fields.MultiSelect,
        label: "Health alerts",
        options: fn _assigns -> [] end,
        only: [:index],
        orderable: false
      },
      location: %{module: Backpex.Fields.Text, label: "Location", searchable: true},
      desc: %{module: Backpex.Fields.Textarea, label: "Description", rows: 3, searchable: true},
      appargs: %{
        module: Backpex.Fields.Textarea,
        label: "Application args",
        rows: 3,
        searchable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
