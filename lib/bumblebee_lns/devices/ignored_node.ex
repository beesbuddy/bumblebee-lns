defmodule BumblebeeLns.Devices.IgnoredNode do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:devaddr, :string, autogenerate: false}
  embedded_schema do
    field(:mask, :string)
  end

  def changeset(ignored_node, attrs, _metadata \\ []) do
    ignored_node
    |> cast(attrs, [:devaddr, :mask])
    |> update_change(:devaddr, &normalize_hex/1)
    |> update_change(:mask, &normalize_hex/1)
    |> validate_required([:devaddr, :mask])
    |> validate_hex(:devaddr)
    |> validate_hex(:mask)
  end

  def from_map(ignored_node), do: struct!(__MODULE__, Map.take(ignored_node, [:devaddr, :mask]))

  defp validate_hex(changeset, field) do
    validate_format(changeset, field, ~r/\A[0-9A-F]{8}\z/,
      message: "must be 8 hexadecimal characters"
    )
  end

  defp normalize_hex(nil), do: nil
  defp normalize_hex(value), do: value |> to_string() |> String.trim() |> String.upcase()
end
