defmodule BumblebeeLns.Areas.Area do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field(:region, :string)
    field(:admins, {:array, :string}, default: [])
    field(:slack_channel, :string)
    field(:log_ignored, :boolean, default: false)
  end

  def changeset(area, attrs, _metadata \\ []) do
    area
    |> cast(attrs, [:region, :admins, :slack_channel, :log_ignored])
    |> validate_required([:region])
    |> validate_inclusion(:region, region_names())
    |> update_change(:admins, &normalize_admins/1)
    |> update_change(:slack_channel, &normalize_optional/1)
  end

  def from_map(area) do
    struct!(__MODULE__, Map.take(area, [:name, :region, :admins, :slack_channel, :log_ignored]))
  end

  defp region_names do
    Enum.map(BumblebeeLns.Areas.regions(), &elem(&1, 0))
  end

  defp normalize_admins(admins) do
    admins
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_optional(nil), do: nil

  defp normalize_optional(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      value -> value
    end
  end
end
