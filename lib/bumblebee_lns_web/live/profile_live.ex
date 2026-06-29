defmodule BumblebeeLnsWeb.ProfileLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Devices
  alias BumblebeeLns.Devices.Profile

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Profile,
      list: &Devices.list_profiles/0,
      get: &Devices.get_profile/1,
      create: &Devices.create_profile/1,
      update: &Devices.update_profile/2,
      delete: &Devices.delete_profile/1,
      create_changeset: &Profile.changeset/3,
      update_changeset: &Profile.changeset/3
    ],
    primary_key: :name,
    init_order: %{by: :name, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "profiles"]

  @impl Backpex.LiveResource
  def singular_name, do: "Profile"

  @impl Backpex.LiveResource
  def plural_name, do: "Profiles"

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
      group: %{
        module: Backpex.Fields.Select,
        label: "Group",
        options: fn _assigns -> Devices.list_group_options() end
      },
      app: %{module: Backpex.Fields.Text, label: "Application", searchable: true},
      appid: %{module: Backpex.Fields.Text, label: "Application ID", searchable: true},
      join: %{
        module: Backpex.Fields.Select,
        label: "Join mode",
        options: [{"ABP", 0}, {"OTAA", 1}, {"Any", 2}]
      },
      fcnt_check: %{module: Backpex.Fields.Number, label: "Frame counter check"},
      txwin: %{module: Backpex.Fields.Number, label: "TX window"},
      adr_mode: %{
        module: Backpex.Fields.Select,
        label: "ADR mode",
        options: [{"Off", 0}, {"On join", 1}, {"Continuous", 2}]
      },
      max_datr: %{module: Backpex.Fields.Number, label: "Max data rate"},
      dcycle_set: %{module: Backpex.Fields.Number, label: "Duty cycle"},
      request_devstat: %{
        module: Backpex.Fields.Boolean,
        label: "Request device status",
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
