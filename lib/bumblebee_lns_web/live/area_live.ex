defmodule BumblebeeLnsWeb.AreaLive do
  @moduledoc false

  alias BumblebeeLns.Areas
  alias BumblebeeLns.Areas.Area
  alias BumblebeeLns.Backpex.MnesiaAdapter

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Area,
      list: &Areas.list_areas/0,
      get: &Areas.get_area/1,
      create: &Areas.create_area/1,
      update: &Areas.update_area/2,
      create_changeset: &Area.changeset/3,
      update_changeset: &Area.changeset/3
    ],
    primary_key: :name,
    init_order: %{by: :name, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "areas"]

  @impl Backpex.LiveResource
  def singular_name, do: "Area"

  @impl Backpex.LiveResource
  def plural_name, do: "Areas"

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
      region: %{
        module: Backpex.Fields.Select,
        label: "Region",
        options: Enum.map(Areas.regions(), fn {code, description} -> {description, code} end)
      },
      admins: %{
        module: Backpex.Fields.MultiSelect,
        label: "Administrators",
        options: fn _assigns -> Enum.map(Areas.list_administrators(), &{&1, &1}) end,
        orderable: false
      },
      slack_channel: %{
        module: Backpex.Fields.Text,
        label: "Slack channel",
        searchable: true
      },
      log_ignored: %{
        module: Backpex.Fields.Boolean,
        label: "Log ignored",
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: Keyword.take(default_actions, [:edit])

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit]
end
