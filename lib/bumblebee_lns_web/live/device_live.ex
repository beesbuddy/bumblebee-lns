defmodule BumblebeeLnsWeb.DeviceLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Devices
  alias BumblebeeLns.Devices.Device

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Device,
      list: &Devices.list_devices/0,
      get: &Devices.get_device/1,
      create: &Devices.create_device/1,
      update: &Devices.update_device/2,
      delete: &Devices.delete_device/1,
      create_changeset: &Device.changeset/3,
      update_changeset: &Device.changeset/3
    ],
    primary_key: :deveui,
    init_order: %{by: :deveui, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "devices"]

  @impl Backpex.LiveResource
  def singular_name, do: "Commissioned Device"

  @impl Backpex.LiveResource
  def plural_name, do: "Commissioned Devices"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def fields do
    [
      deveui: %{
        module: Backpex.Fields.Text,
        label: "DevEUI",
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      appeui: %{module: Backpex.Fields.Text, label: "AppEUI", searchable: true},
      profile: %{
        module: Backpex.Fields.Select,
        label: "Profile",
        options: fn _assigns -> Devices.list_profile_options() end
      },
      appkey: %{module: Backpex.Fields.Text, label: "AppKey"},
      nwkkey: %{module: Backpex.Fields.Text, label: "NwkKey"},
      node: %{module: Backpex.Fields.Text, label: "Activated node", searchable: true},
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
