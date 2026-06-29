defmodule BumblebeeLns.Networks.Network do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field(:netid, :string)
    field(:region, :string)
    field(:tx_codr, :string, default: "4/5")
    field(:join1_delay, :integer, default: 5)
    field(:join2_delay, :integer, default: 6)
    field(:rx1_delay, :integer, default: 1)
    field(:rx2_delay, :integer, default: 2)
    field(:gw_power, :integer)
    field(:max_eirp, :integer)
    field(:max_power, :integer)
    field(:min_power, :integer)
    field(:max_datr, :float)
    field(:dcycle_init, :integer, default: 0)
    field(:rx1_dr_offset, :integer, default: 0)
    field(:rx2_dr, :integer)
    field(:rx2_freq, :float)
    field(:init_chans, :string, default: "0-2")
    field(:cflist, :string)
  end

  def changeset(network, attrs, _metadata \\ []) do
    network
    |> cast(attrs, [
      :name,
      :netid,
      :region,
      :tx_codr,
      :join1_delay,
      :join2_delay,
      :rx1_delay,
      :rx2_delay,
      :gw_power,
      :max_eirp,
      :max_power,
      :min_power,
      :max_datr,
      :dcycle_init,
      :rx1_dr_offset,
      :rx2_dr,
      :rx2_freq,
      :init_chans,
      :cflist
    ])
    |> update_change(:name, &normalize_name/1)
    |> update_change(:netid, &normalize_hex/1)
    |> update_change(:region, &normalize_string/1)
    |> update_change(:tx_codr, &normalize_string/1)
    |> update_change(:init_chans, &normalize_string/1)
    |> update_change(:cflist, &normalize_optional/1)
    |> validate_required([
      :name,
      :netid,
      :region,
      :tx_codr,
      :join1_delay,
      :join2_delay,
      :rx1_delay,
      :rx2_delay,
      :gw_power,
      :max_eirp,
      :max_power,
      :min_power,
      :max_datr,
      :dcycle_init,
      :rx1_dr_offset,
      :rx2_dr,
      :rx2_freq,
      :init_chans
    ])
    |> validate_format(:netid, ~r/\A[0-9A-F]{6}\z/, message: "must be 6 hexadecimal characters")
    |> validate_inclusion(:region, region_names())
    |> validate_inclusion(:tx_codr, ["4/5", "4/6", "4/7", "4/8"])
    |> validate_number(:max_power, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:min_power, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:dcycle_init, greater_than_or_equal_to: 0, less_than_or_equal_to: 15)
    |> validate_change(:init_chans, &validate_intervals/2)
    |> validate_change(:cflist, &validate_cflist/2)
  end

  def from_map(network), do: struct!(__MODULE__, Map.take(network, __schema__(:fields)))

  defp region_names, do: Enum.map(BumblebeeLns.Areas.regions(), &elem(&1, 0))

  defp normalize_name(nil), do: nil
  defp normalize_name(name), do: name |> to_string() |> String.trim()

  defp normalize_hex(nil), do: nil
  defp normalize_hex(value), do: value |> to_string() |> String.trim() |> String.upcase()

  defp normalize_string(nil), do: nil
  defp normalize_string(value), do: value |> to_string() |> String.trim()

  defp normalize_optional(nil), do: nil

  defp normalize_optional(value) do
    case normalize_string(value) do
      "" -> nil
      value -> value
    end
  end

  defp validate_intervals(field, value) do
    case BumblebeeLns.Networks.parse_intervals(value) do
      {:ok, _intervals} -> []
      {:error, message} -> [{field, message}]
    end
  end

  defp validate_cflist(_field, nil), do: []
  defp validate_cflist(_field, ""), do: []

  defp validate_cflist(field, value) do
    case BumblebeeLns.Networks.parse_cflist(value) do
      {:ok, _channels} -> []
      {:error, message} -> [{field, message}]
    end
  end
end
