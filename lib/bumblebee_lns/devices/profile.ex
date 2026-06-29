defmodule BumblebeeLns.Devices.Profile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field(:group, :string)
    field(:app, :string)
    field(:appid, :string)
    field(:join, :integer, default: 1)
    field(:fcnt_check, :integer)
    field(:txwin, :integer)
    field(:adr_mode, :integer, default: 0)
    field(:max_datr, :float)
    field(:dcycle_set, :integer)
    field(:request_devstat, :boolean, default: false)
  end

  def changeset(profile, attrs, _metadata \\ []) do
    profile
    |> cast(attrs, [
      :name,
      :group,
      :app,
      :appid,
      :join,
      :fcnt_check,
      :txwin,
      :adr_mode,
      :max_datr,
      :dcycle_set,
      :request_devstat
    ])
    |> update_change(:name, &normalize/1)
    |> update_change(:group, &normalize/1)
    |> update_change(:app, &normalize/1)
    |> update_change(:appid, &normalize_optional/1)
    |> validate_required([:name, :group, :app, :join, :adr_mode])
    |> validate_inclusion(:join, 0..2)
    |> validate_inclusion(:adr_mode, 0..2)
  end

  def from_map(profile),
    do:
      struct!(
        __MODULE__,
        Map.take(profile, [
          :name,
          :group,
          :app,
          :appid,
          :join,
          :fcnt_check,
          :txwin,
          :adr_mode,
          :max_datr,
          :dcycle_set,
          :request_devstat
        ])
      )

  defp normalize(nil), do: nil
  defp normalize(value), do: value |> to_string() |> String.trim()
  defp normalize_optional(nil), do: nil
  defp normalize_optional(value), do: if((value = normalize(value)) == "", do: nil, else: value)
end
