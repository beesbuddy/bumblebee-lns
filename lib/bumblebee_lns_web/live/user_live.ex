defmodule BumblebeeLnsWeb.UserLive do
  @moduledoc false

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Users
  alias BumblebeeLns.Users.User

  use Backpex.LiveResource,
    adapter: MnesiaAdapter,
    adapter_config: [
      schema: User,
      list: &Users.list_users/0,
      get: &Users.get_user/1,
      create: &Users.create_user/1,
      update: &Users.update_user/2,
      delete: &Users.delete_user/1,
      create_changeset: &User.changeset/3,
      update_changeset: &User.changeset/3
    ],
    primary_key: :name,
    init_order: %{by: :name, direction: :asc},
    pubsub: [server: BumblebeeLns.PubSub, topic: "users"]

  use BumblebeeLnsWeb.Backpex.ResourceSlots

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {BumblebeeLnsWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def panels do
    [
      identity: "Identity",
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
        panel: :identity,
        searchable: true,
        readonly: fn assigns -> assigns.live_action == :edit end
      },
      pass: %{
        module: BumblebeeLnsWeb.Backpex.Fields.Password,
        label: "Password",
        help_text: "Leave blank on edit to keep the existing password.",
        panel: :identity,
        except: [:index],
        orderable: false
      },
      scopes: %{
        module: Backpex.Fields.MultiSelect,
        label: "Scopes",
        help_text: "Permissions this user receives in the admin interface.",
        panel: :access,
        options: fn _assigns -> Users.scope_options() end,
        orderable: false
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "E-Mail",
        panel: :notifications,
        searchable: true
      },
      send_alerts: %{
        module: Backpex.Fields.Boolean,
        label: "Send alerts",
        panel: :notifications,
        orderable: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: Keyword.take(default_actions, [:edit, :delete])

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item), do: action in [:index, :new, :edit, :delete]
end
