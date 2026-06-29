defmodule BumblebeeLns.Backpex.MnesiaAdapterTest.Item do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field(:group, :string)
    field(:app, :string)
  end

  def changeset(item, attrs) do
    cast(item, attrs, [:name, :group, :app])
    |> validate_required([:name, :group, :app])
  end
end

defmodule BumblebeeLns.Backpex.MnesiaAdapterTest.Resource do
  @moduledoc false

  def adapter_config(:create) do
    fn _attrs ->
      {:error,
       %{
         "group" => ~c"does not exist",
         <<"app">> => ["is invalid", ~c"is unavailable"],
         :unknown => "is not mapped"
       }}
    end
  end

  def adapter_config(:schema), do: BumblebeeLns.Backpex.MnesiaAdapterTest.Item
end

defmodule BumblebeeLns.Backpex.MnesiaAdapterTest do
  use ExUnit.Case, async: true

  alias BumblebeeLns.Backpex.MnesiaAdapter
  alias BumblebeeLns.Backpex.MnesiaAdapterTest.Item
  alias BumblebeeLns.Backpex.MnesiaAdapterTest.Resource

  test "insert maps adapter errors to known changeset fields" do
    changeset =
      Item.changeset(%Item{}, %{
        "name" => "profile",
        "group" => "missing",
        "app" => "app",
        "_unused_group" => "",
        "_unused_app" => ""
      })

    assert {:error, changeset} = MnesiaAdapter.insert(changeset, Resource)

    assert {"does not exist", []} in Keyword.get_values(changeset.errors, :group)
    assert {"is invalid", []} in Keyword.get_values(changeset.errors, :app)
    assert {"is unavailable", []} in Keyword.get_values(changeset.errors, :app)
    assert {"unknown: is not mapped", []} in Keyword.get_values(changeset.errors, :base)

    form = Phoenix.Component.to_form(changeset, as: :change)

    assert Phoenix.Component.used_input?(form[:group])
    assert Phoenix.Component.used_input?(form[:app])
  end

  test "insert marks local validation error fields as used" do
    changeset =
      Item.changeset(%Item{}, %{
        "name" => "profile",
        "group" => "",
        "app" => "app",
        "_unused_group" => ""
      })

    assert {:error, changeset} = MnesiaAdapter.insert(changeset, Resource)

    assert {"can't be blank", [validation: :required]} in Keyword.get_values(
             changeset.errors,
             :group
           )

    form = Phoenix.Component.to_form(changeset, as: :change)

    assert Phoenix.Component.used_input?(form[:group])
  end
end
