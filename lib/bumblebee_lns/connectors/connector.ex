defmodule BumblebeeLns.Connectors.Connector do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:connid, :string, autogenerate: false}
  embedded_schema do
    field(:app, :string)
    field(:format, :string, default: "json")
    field(:uri, :string)
    field(:publish_qos, :integer, default: 0)
    field(:publish_uplinks, :string)
    field(:publish_events, :string)
    field(:subscribe_qos, :integer, default: 0)
    field(:subscribe, :string)
    field(:received, :string)
    field(:enabled, :boolean, default: true)
    field(:failed, {:array, :string}, default: [])
    field(:client_id, :string)
    field(:auth, :string, default: "basic")
    field(:name, :string)
    field(:pass, :string)
    field(:certfile, :string)
    field(:keyfile, :string)
    field(:health_alerts, {:array, :string}, default: [])
  end

  def changeset(connector, attrs, _metadata \\ []) do
    connector
    |> cast(attrs, [
      :connid,
      :app,
      :format,
      :uri,
      :publish_qos,
      :publish_uplinks,
      :publish_events,
      :subscribe_qos,
      :subscribe,
      :received,
      :enabled,
      :client_id,
      :auth,
      :name,
      :pass,
      :certfile,
      :keyfile
    ])
    |> update_change(:connid, &normalize/1)
    |> update_change(:app, &normalize/1)
    |> update_change(:format, &normalize/1)
    |> update_change(:uri, &normalize/1)
    |> update_change(:publish_uplinks, &normalize_optional/1)
    |> update_change(:publish_events, &normalize_optional/1)
    |> update_change(:subscribe, &normalize_optional/1)
    |> update_change(:received, &normalize_optional/1)
    |> update_change(:client_id, &normalize_optional/1)
    |> update_change(:auth, &normalize_optional/1)
    |> update_change(:name, &normalize_optional/1)
    |> update_change(:pass, &normalize_optional/1)
    |> update_change(:certfile, &normalize_optional/1)
    |> update_change(:keyfile, &normalize_optional/1)
    |> validate_required([:connid, :app, :format, :uri, :publish_qos, :subscribe_qos])
    |> validate_inclusion(:format, ["json", "raw"])
    |> validate_inclusion(:publish_qos, 0..2)
    |> validate_inclusion(:subscribe_qos, 0..2)
  end

  def from_map(connector),
    do:
      struct!(
        __MODULE__,
        Map.take(connector, [
          :connid,
          :app,
          :format,
          :uri,
          :publish_qos,
          :publish_uplinks,
          :publish_events,
          :subscribe_qos,
          :subscribe,
          :received,
          :enabled,
          :failed,
          :client_id,
          :auth,
          :name,
          :pass,
          :certfile,
          :keyfile,
          :health_alerts
        ])
      )

  defp normalize(nil), do: nil
  defp normalize(value), do: value |> to_string() |> String.trim()
  defp normalize_optional(nil), do: nil
  defp normalize_optional(value), do: if((value = normalize(value)) == "", do: nil, else: value)
end
