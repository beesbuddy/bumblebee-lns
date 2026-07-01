defmodule BumblebeeLnsWeb.ConnectorLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Connectors
  alias BumblebeeLns.Connectors.Connector

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: Connector,
      list: &Connectors.list_connectors/0,
      get: &Connectors.get_connector/1,
      create: &Connectors.create_connector/1,
      update: &Connectors.update_connector/2,
      delete: &Connectors.delete_connector/1,
      create_changeset: &Connector.changeset/3,
      update_changeset: &Connector.changeset/3
    ],
    primary_key: :connid,
    init_order: %{by: :connid, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "connectors"]

  use BumblebeeLnsWeb.Backpex.ResourceSlots

  @impl Backpex.LiveResource
  def singular_name, do: "Connector"

  @impl Backpex.LiveResource
  def plural_name, do: "Connectors"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def panels do
    [
      general: "General",
      publish: "Publish",
      subscribe: "Subscribe",
      credentials: "Credentials",
      status: "Status"
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      connid: %{
        module: Backpex.Fields.Text,
        label: "Connector ID",
        panel: :general,
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      app: %{
        module: Backpex.Fields.Text,
        label: "Application",
        panel: :general,
        searchable: true
      },
      format: %{
        module: Backpex.Fields.Select,
        label: "Format",
        panel: :general,
        options: [{"JSON", "json"}, {"Raw", "raw"}]
      },
      uri: %{
        module: Backpex.Fields.Text,
        label: "URI",
        panel: :general,
        searchable: true
      },
      enabled: %{
        module: Backpex.Fields.Boolean,
        label: "Enabled",
        panel: :general,
        orderable: false
      },
      publish_qos: %{
        module: Backpex.Fields.Select,
        label: "Publish QoS",
        panel: :publish,
        options: qos_options()
      },
      publish_uplinks: %{
        module: Backpex.Fields.Text,
        label: "Publish uplinks",
        panel: :publish,
        searchable: true
      },
      publish_events: %{
        module: Backpex.Fields.Text,
        label: "Publish events",
        panel: :publish,
        searchable: true
      },
      subscribe_qos: %{
        module: Backpex.Fields.Select,
        label: "Subscribe QoS",
        panel: :subscribe,
        options: qos_options()
      },
      subscribe: %{
        module: Backpex.Fields.Text,
        label: "Subscribe",
        panel: :subscribe,
        searchable: true
      },
      received: %{
        module: Backpex.Fields.Text,
        label: "Received",
        panel: :subscribe,
        searchable: true
      },
      client_id: %{
        module: Backpex.Fields.Text,
        label: "Client ID",
        panel: :credentials,
        searchable: true
      },
      auth: %{
        module: Backpex.Fields.Select,
        label: "Auth",
        panel: :credentials,
        options: [{"Basic", "basic"}, {"Token", "token"}],
        prompt: "No auth"
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Username",
        panel: :credentials,
        searchable: true
      },
      pass: %{
        module: BumblebeeLnsWeb.Backpex.Fields.Password,
        label: "Password",
        panel: :credentials,
        help_text: "Leave blank on edit to clear the stored password.",
        except: [:index],
        orderable: false
      },
      certfile: %{
        module: Backpex.Fields.Text,
        label: "Certificate file",
        panel: :credentials
      },
      keyfile: %{
        module: Backpex.Fields.Text,
        label: "Key file",
        panel: :credentials
      },
      failed: %{
        module: Backpex.Fields.MultiSelect,
        label: "Failures",
        panel: :status,
        options: fn _assigns -> [] end,
        only: [:index],
        orderable: false
      },
      health_alerts: %{
        module: Backpex.Fields.MultiSelect,
        label: "Health alerts",
        panel: :status,
        options: fn _assigns -> [] end,
        only: [:index],
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: Keyword.take(default_actions, [:edit, :delete])

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]

  defp qos_options,
    do: [{"0 - at most once", 0}, {"1 - at least once", 1}, {"2 - exactly once", 2}]
end
