defmodule BumblebeeLns.Devices.Node do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:devaddr, :string, autogenerate: false}
  embedded_schema do
    field(:profile, :string)
    field(:appargs, :string)
    field(:nwkskey, :string)
    field(:appskey, :string)
    field(:desc, :string)
    field(:location, :string)
    field(:fcntup, :integer, default: 0)
    field(:fcntdown, :integer, default: 0)
    field(:adr_flag, :integer, default: 0)
    field(:last_rx, :string)
    field(:health_alerts, {:array, :string}, default: [])
  end

  def changeset(node, attrs, _metadata \\ []) do
    node
    |> cast(attrs, [
      :devaddr,
      :profile,
      :appargs,
      :nwkskey,
      :appskey,
      :desc,
      :location,
      :fcntup,
      :fcntdown,
      :adr_flag
    ])
    |> update_change(:devaddr, &normalize_hex/1)
    |> update_change(:nwkskey, &normalize_hex/1)
    |> update_change(:appskey, &normalize_hex/1)
    |> update_change(:profile, &normalize/1)
    |> update_change(:appargs, &normalize_optional/1)
    |> update_change(:desc, &normalize_optional/1)
    |> update_change(:location, &normalize_optional/1)
    |> validate_required([:devaddr, :profile, :nwkskey, :appskey, :fcntup, :fcntdown, :adr_flag])
    |> validate_hex(:devaddr, 8)
    |> validate_hex(:nwkskey, 32)
    |> validate_hex(:appskey, 32)
    |> validate_inclusion(:adr_flag, 0..1)
  end

  def from_map(node),
    do:
      struct!(
        __MODULE__,
        Map.take(node, [
          :devaddr,
          :profile,
          :appargs,
          :nwkskey,
          :appskey,
          :desc,
          :location,
          :fcntup,
          :fcntdown,
          :adr_flag,
          :last_rx,
          :health_alerts
        ])
      )

  defp validate_hex(changeset, field, size) do
    validate_format(changeset, field, ~r/\A[0-9A-F]{#{size}}\z/,
      message: "must be #{size} hexadecimal characters"
    )
  end

  defp normalize(nil), do: nil
  defp normalize(value), do: value |> to_string() |> String.trim()
  defp normalize_optional(nil), do: nil
  defp normalize_optional(value), do: if((value = normalize(value)) == "", do: nil, else: value)
  defp normalize_hex(nil), do: nil
  defp normalize_hex(value), do: value |> normalize() |> String.upcase()
end
