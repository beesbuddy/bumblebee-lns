defmodule BumblebeeLnsWeb.NetworkLive do
  @moduledoc false

  alias BumblebeeLns.Areas
  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Networks
  alias BumblebeeLns.Networks.Network

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Network,
      list: &Networks.list_networks/0,
      get: &Networks.get_network/1,
      create: &Networks.create_network/1,
      update: &Networks.update_network/2,
      delete: &Networks.delete_network/1,
      create_changeset: &Network.changeset/3,
      update_changeset: &Network.changeset/3
    ],
    primary_key: :name,
    init_order: %{by: :name, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "networks"]

  @impl Backpex.LiveResource
  def singular_name, do: "Network"

  @impl Backpex.LiveResource
  def plural_name, do: "Networks"

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
      netid: %{module: Backpex.Fields.Text, label: "NetID", searchable: true},
      region: %{
        module: Backpex.Fields.Select,
        label: "Region",
        options: Enum.map(Areas.regions(), fn {code, description} -> {description, code} end)
      },
      tx_codr: %{
        module: Backpex.Fields.Select,
        label: "Coding rate",
        options: Networks.coding_rate_options()
      },
      join1_delay: %{module: Backpex.Fields.Number, label: "RX1 join delay (s)"},
      join2_delay: %{module: Backpex.Fields.Number, label: "RX2 join delay (s)"},
      rx1_delay: %{module: Backpex.Fields.Number, label: "RX1 delay (s)"},
      rx2_delay: %{module: Backpex.Fields.Number, label: "RX2 delay (s)"},
      gw_power: %{module: Backpex.Fields.Number, label: "Gateway power (dBm)"},
      max_eirp: %{module: Backpex.Fields.Number, label: "Max EIRP (dBm)"},
      max_power: %{
        module: Backpex.Fields.Select,
        label: "Max power",
        options: Networks.power_options()
      },
      min_power: %{
        module: Backpex.Fields.Select,
        label: "Min power",
        options: Networks.power_options()
      },
      max_datr: %{module: Backpex.Fields.Number, label: "Max data rate"},
      dcycle_init: %{
        module: Backpex.Fields.Select,
        label: "Initial duty cycle",
        options: Networks.duty_cycle_options()
      },
      rx1_dr_offset: %{module: Backpex.Fields.Number, label: "Initial RX1 DR offset"},
      rx2_dr: %{module: Backpex.Fields.Number, label: "Initial RX2 DR"},
      rx2_freq: %{module: Backpex.Fields.Number, label: "Initial RX2 freq (MHz)"},
      init_chans: %{module: Backpex.Fields.Text, label: "Initial channels"},
      cflist: %{
        module: Backpex.Fields.Textarea,
        label: "CFList channels",
        rows: 4,
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: Keyword.take(default_actions, [:edit, :delete])

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
