defmodule BumblebeeLns.Gateways.Gateway do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:mac, :string, autogenerate: false}
  embedded_schema do
    field(:area, :string)
    field(:tx_rfch, :integer, default: 0)
    field(:ant_gain, :integer, default: 0)
    field(:desc, :string)
    field(:latitude, :float)
    field(:longitude, :float)
    field(:location_map, :string, virtual: true)
    field(:gpsalt, :float)
    field(:last_alive, :string)
    field(:last_gps, :string)
    field(:last_report, :string)
    field(:health_alerts, {:array, :string}, default: [])
  end

  def changeset(gateway, attrs, _metadata \\ []) do
    gateway
    |> cast(attrs, [
      :mac,
      :area,
      :tx_rfch,
      :ant_gain,
      :desc,
      :latitude,
      :longitude,
      :gpsalt
    ])
    |> update_change(:mac, &normalize_mac/1)
    |> update_change(:area, &normalize_optional/1)
    |> update_change(:desc, &normalize_optional/1)
    |> validate_required([:mac, :tx_rfch, :ant_gain, :latitude, :longitude])
    |> validate_format(:mac, ~r/\A[0-9A-F]{16}\z/, message: "must be 16 hexadecimal characters")
  end

  def from_map(gateway) do
    struct!(
      __MODULE__,
      Map.take(gateway, [
        :mac,
        :area,
        :tx_rfch,
        :ant_gain,
        :desc,
        :latitude,
        :longitude,
        :gpsalt,
        :last_alive,
        :last_gps,
        :last_report,
        :health_alerts
      ])
    )
  end

  defp normalize_mac(nil), do: nil
  defp normalize_mac(mac), do: mac |> to_string() |> String.trim() |> String.upcase()

  defp normalize_optional(nil), do: nil

  defp normalize_optional(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      value -> value
    end
  end
end
