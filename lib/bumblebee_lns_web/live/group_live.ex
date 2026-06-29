defmodule BumblebeeLnsWeb.GroupLive do
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
  def panels do
    [
      general: "General",
      access: "Access",
      notifications: "Notifications"
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        help_text: "Unique group name used by profiles and multicast channels.",
        panel: :general,
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      network: %{
        module: Backpex.Fields.Select,
        label: "Network",
        prompt: "Select network",
        help_text: "Network this group belongs to. Profiles inherit network behavior through the group.",
        panel: :general,
        options: fn _assigns -> Devices.list_network_options() end
      },
      admins: %{
        module: Backpex.Fields.MultiSelect,
        label: "Administrators",
        help_text: "Users allowed to administer this group. Leave empty for no group-specific admins.",
        panel: :access,
        options: fn _assigns -> Devices.list_administrator_options() end,
        orderable: false
      },
      can_join: %{
        module: Backpex.Fields.Boolean,
        label: "Can join",
        help_text: "Allow devices in this group to complete OTAA joins.",
        panel: :access,
        orderable: false
      },
      slack_channel: %{
        module: Backpex.Fields.Text,
        label: "Slack channel",
        placeholder: "#lorawan-alerts",
        help_text: "Optional Slack channel for group alerts. Use a channel name such as #lorawan-alerts.",
        panel: :notifications,
        searchable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
