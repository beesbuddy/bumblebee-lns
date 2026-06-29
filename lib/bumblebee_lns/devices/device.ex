defmodule BumblebeeLns.Devices.Device do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:deveui, :string, autogenerate: false}
  embedded_schema do
    field(:profile, :string)
    field(:appargs, :string)
    field(:appeui, :string)
    field(:appkey, :string)
    field(:nwkkey, :string)
    field(:desc, :string)
    field(:node, :string)
    field(:health_alerts, {:array, :string}, default: [], virtual: true)
  end

  def changeset(device, attrs, _metadata \\ []) do
    device
    |> cast(attrs, [:deveui, :profile, :appargs, :appeui, :appkey, :nwkkey, :desc, :node])
    |> update_change(:deveui, &normalize_hex/1)
    |> update_change(:appeui, &normalize_hex/1)
    |> update_change(:appkey, &normalize_hex/1)
    |> update_change(:nwkkey, &normalize_hex/1)
    |> update_change(:node, &normalize_hex/1)
    |> update_change(:profile, &normalize/1)
    |> update_change(:appargs, &normalize_optional/1)
    |> update_change(:desc, &normalize_optional/1)
    |> validate_required([:deveui, :profile, :appkey])
    |> validate_hex(:deveui, 16)
    |> validate_hex(:appeui, 16)
    |> validate_hex(:appkey, 32)
    |> validate_hex(:nwkkey, 32)
    |> validate_hex(:node, 8)
  end

  def from_map(device),
    do:
      struct!(
        __MODULE__,
        Map.take(device, [
          :deveui,
          :profile,
          :appargs,
          :appeui,
          :appkey,
          :nwkkey,
          :desc,
          :node,
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
