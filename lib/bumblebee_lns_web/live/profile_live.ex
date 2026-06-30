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

  use BumblebeeLnsWeb.Backpex.ResourceSlots

  @impl Backpex.LiveResource
  def singular_name, do: "Profile"

  @impl Backpex.LiveResource
  def plural_name, do: "Profiles"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def panels do
    [
      general: "General",
      activation: "Activation",
      adr: "ADR",
      status: "Status"
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        placeholder: "default-profile",
        help_text: "Unique profile name used by devices and activated nodes.",
        panel: :general,
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      group: %{
        module: BumblebeeLnsWeb.Backpex.Fields.Select,
        label: "Group",
        prompt: "Select group",
        searchable: true,
        help_text: "Choose the group that owns this device profile.",
        panel: :general,
        options: fn _assigns -> Devices.list_group_options() end
      },
      app: %{
        module: Backpex.Fields.Text,
        label: "Application",
        placeholder: "my_application",
        help_text: "Application module or identifier used by the backend handler.",
        panel: :general,
        searchable: true
      },
      appid: %{
        module: Backpex.Fields.Text,
        label: "Application ID",
        placeholder: "optional-app-id",
        help_text: "Optional external application identifier. Leave empty when not needed.",
        panel: :general,
        searchable: true
      },
      join: %{
        module: Backpex.Fields.Select,
        label: "Join mode",
        help_text:
          "ABP uses existing session keys, OTAA requires a join request, Any accepts both.",
        panel: :activation,
        options: [{"ABP", 0}, {"OTAA", 1}, {"Any", 2}]
      },
      fcnt_check: %{
        module: Backpex.Fields.Number,
        label: "Frame counter check",
        placeholder: "16384",
        help_text: "Optional maximum accepted frame counter gap. Leave empty to use defaults.",
        panel: :activation
      },
      txwin: %{
        module: Backpex.Fields.Number,
        label: "TX window",
        placeholder: "1",
        help_text: "Optional RX window for downlinks. Use 1 or 2, or leave empty for default.",
        panel: :activation
      },
      adr_mode: %{
        module: Backpex.Fields.Select,
        label: "ADR mode",
        help_text:
          "Controls whether adaptive data rate is disabled, applied on join, or continuous.",
        panel: :adr,
        options: [{"Off", 0}, {"On join", 1}, {"Continuous", 2}]
      },
      max_datr: %{
        module: Backpex.Fields.Number,
        label: "Max data rate",
        placeholder: "5",
        help_text: "Optional maximum LoRaWAN data rate index allowed for this profile.",
        panel: :adr
      },
      dcycle_set: %{
        module: Backpex.Fields.Number,
        label: "Duty cycle",
        placeholder: "0",
        help_text: "Optional duty-cycle setting. Leave empty to use the network default.",
        panel: :adr
      },
      request_devstat: %{
        module: Backpex.Fields.Boolean,
        label: "Request device status",
        help_text: "Ask devices for status MAC commands when profile traffic is handled.",
        panel: :status,
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
