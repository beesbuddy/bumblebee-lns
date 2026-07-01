defmodule BumblebeeLns.Users.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field(:pass_ha1, :string)
    field(:pass, :string, virtual: true)
    field(:scopes, {:array, :string}, default: [])
    field(:email, :string)
    field(:send_alerts, :boolean, default: true)
  end

  def changeset(user, attrs, _metadata \\ []) do
    user
    |> cast(attrs, [:name, :pass_ha1, :pass, :scopes, :email, :send_alerts])
    |> update_change(:name, &normalize/1)
    |> update_change(:pass, &normalize_optional/1)
    |> update_change(:scopes, &normalize_list/1)
    |> update_change(:email, &normalize_optional/1)
    |> validate_required([:name, :scopes, :send_alerts])
    |> validate_password_required()
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/,
      message: "must be a valid email address"
    )
  end

  def from_map(user), do: struct!(__MODULE__, Map.take(user, __schema__(:fields)))

  defp validate_password_required(changeset) do
    if get_field(changeset, :pass_ha1) in [nil, ""] do
      validate_required(changeset, [:pass])
    else
      changeset
    end
  end

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
