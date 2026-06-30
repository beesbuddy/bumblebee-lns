defmodule BumblebeeLnsWeb.IgnoredNodeLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Devices
  alias BumblebeeLns.Devices.IgnoredNode

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: IgnoredNode,
      list: &Devices.list_ignored_nodes/0,
      get: &Devices.get_ignored_node/1,
      create: &Devices.create_ignored_node/1,
      update: &Devices.update_ignored_node/2,
      delete: &Devices.delete_ignored_node/1,
      create_changeset: &IgnoredNode.changeset/3,
      update_changeset: &IgnoredNode.changeset/3
    ],
    primary_key: :devaddr,
    init_order: %{by: :devaddr, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "ignored_nodes"]

  use BumblebeeLnsWeb.Backpex.ResourceSlots

  @impl Backpex.LiveResource
  def singular_name, do: "Ignored Node"

  @impl Backpex.LiveResource
  def plural_name, do: "Ignored Nodes"

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
      mask: %{module: Backpex.Fields.Text, label: "Mask", searchable: true}
    ]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
