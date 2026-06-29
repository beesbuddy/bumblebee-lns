defmodule BumblebeeLnsWeb.GroupLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Devices
  alias BumblebeeLns.Devices.Group

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Group,
      list: &Devices.list_groups/0,
      get: &Devices.get_group/1,
      create: &Devices.create_group/1,
      update: &Devices.update_group/2,
      delete: &Devices.delete_group/1,
      create_changeset: &Group.changeset/3,
      update_changeset: &Group.changeset/3
    ],
    primary_key: :name,
    init_order: %{by: :name, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "groups"]

  @impl Backpex.LiveResource
  def singular_name, do: "Group"

  @impl Backpex.LiveResource
  def plural_name, do: "Groups"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      network: %{
        module: Backpex.Fields.Select,
        label: "Network",
        options: fn _assigns -> Devices.list_network_options() end
      },
      admins: %{
        module: Backpex.Fields.MultiSelect,
        label: "Administrators",
        options: fn _assigns -> Devices.list_administrator_options() end,
        orderable: false
      },
      slack_channel: %{module: Backpex.Fields.Text, label: "Slack channel", searchable: true},
      can_join: %{module: Backpex.Fields.Boolean, label: "Can join", orderable: false}
    ]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
