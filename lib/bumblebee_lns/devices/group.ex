defmodule BumblebeeLns.Devices.Group do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field(:network, :string)
    field(:admins, {:array, :string}, default: [])
    field(:slack_channel, :string)
    field(:can_join, :boolean, default: false)
  end

  def changeset(group, attrs, _metadata \\ []) do
    group
    |> cast(attrs, [:name, :network, :admins, :slack_channel, :can_join])
    |> update_change(:name, &normalize/1)
    |> update_change(:network, &normalize/1)
    |> update_change(:slack_channel, &normalize_optional/1)
    |> update_change(:admins, &normalize_list/1)
    |> validate_required([:name, :network])
  end

  def from_map(group),
    do:
      struct!(
        __MODULE__,
        Map.take(group, [:name, :network, :admins, :slack_channel, :can_join])
      )

  defp normalize(nil), do: nil
  defp normalize(value), do: value |> to_string() |> String.trim()

  defp normalize_optional(nil), do: nil
  defp normalize_optional(value), do: if((value = normalize(value)) == "", do: nil, else: value)

  defp normalize_list(values) do
    values
    |> List.wrap()
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end
end
