defmodule BumblebeeLns.Backpex.MnesiaAdapter do
  @moduledoc """
  Backpex data-layer adapter for contexts backed by Mnesia.

  Backpex still uses Ecto schemas and changesets for forms, but persistence stays
  in the existing Mnesia context.
  """

  @config_schema [
    schema: [type: :atom, required: true],
    list: [type: {:fun, 0}, required: true],
    get: [type: {:fun, 1}, required: true],
    update: [type: {:fun, 2}, required: true],
    create_changeset: [type: {:fun, 3}, required: true],
    update_changeset: [type: {:fun, 3}, required: true]
  ]

  use Backpex.Adapter, config_schema: @config_schema

  @impl Backpex.Adapter
  def get(primary_value, _fields, _assigns, live_resource) do
    case live_resource.adapter_config(:get).(primary_value) do
      {:ok, item} -> {:ok, to_schema(item, live_resource)}
      {:error, :not_found} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Backpex.Adapter
  def list(criteria, _fields, _assigns, live_resource) do
    items =
      live_resource.adapter_config(:list).()
      |> Enum.map(&to_schema(&1, live_resource))
      |> apply_search(criteria[:search])
      |> apply_order(criteria[:order])
      |> apply_pagination(criteria[:pagination])

    {:ok, items}
  end

  @impl Backpex.Adapter
  def count(criteria, _fields, _assigns, live_resource) do
    count =
      live_resource.adapter_config(:list).()
      |> Enum.map(&to_schema(&1, live_resource))
      |> apply_search(criteria[:search])
      |> length()

    {:ok, count}
  end

  @impl Backpex.Adapter
  def change(item, attrs, fields, assigns, live_resource, opts) do
    target = Keyword.get(opts, :target)
    action = Keyword.get(opts, :action, :validate)
    metadata = Backpex.Resource.build_changeset_metadata(assigns, target)
    changeset_function = changeset_function(assigns.live_action, live_resource)

    fields
    |> Enum.reduce(Ecto.Changeset.change(item), fn {_name, field_options} = field, changeset ->
      field_options.module.before_changeset(changeset, attrs, metadata, nil, field, assigns)
    end)
    |> changeset_function.(attrs, metadata)
    |> Map.put(:action, action)
  end

  @impl Backpex.Adapter
  def update(%Ecto.Changeset{} = changeset, live_resource) do
    if changeset.valid? do
      item = Ecto.Changeset.apply_changes(changeset)

      attrs =
        item
        |> Map.from_struct()
        |> Map.new(fn {key, value} -> {to_string(key), value} end)

      primary_value = Map.fetch!(item, live_resource.config(:primary_key))

      case live_resource.adapter_config(:update).(primary_value, attrs) do
        {:ok, updated} -> {:ok, to_schema(updated, live_resource)}
        {:error, errors} -> {:error, add_errors(changeset, errors)}
      end
    else
      {:error, changeset}
    end
  end

  @impl Backpex.Adapter
  def insert(changeset, _live_resource),
    do: {:error, Ecto.Changeset.add_error(changeset, :base, "creation is not supported")}

  @impl Backpex.Adapter
  def delete_all(_items, _live_resource), do: {:error, :not_supported}

  @impl Backpex.Adapter
  def update_all(_items, _updates, _live_resource), do: :error

  defp changeset_function(:new, live_resource),
    do: live_resource.adapter_config(:create_changeset)

  defp changeset_function(_, live_resource), do: live_resource.adapter_config(:update_changeset)

  defp to_schema(%schema{} = item, live_resource) do
    if schema == live_resource.adapter_config(:schema),
      do: item,
      else: raise(ArgumentError, "unexpected schema")
  end

  defp to_schema(item, live_resource), do: live_resource.adapter_config(:schema).from_map(item)

  defp apply_search(items, nil), do: items
  defp apply_search(items, {"", _fields}), do: items

  defp apply_search(items, {search, fields}) do
    search = String.downcase(search)
    names = Enum.map(fields, &elem(&1, 0))

    Enum.filter(items, fn item ->
      Enum.any?(names, fn name ->
        item
        |> Map.get(name)
        |> searchable_value()
        |> String.downcase()
        |> String.contains?(search)
      end)
    end)
  end

  defp searchable_value(nil), do: ""
  defp searchable_value(value) when is_list(value), do: Enum.join(value, " ")
  defp searchable_value(value), do: to_string(value)

  defp apply_order(items, nil), do: items

  defp apply_order(items, %{by: field, direction: direction}) do
    sorter = fn item -> item |> Map.get(field) |> searchable_value() |> String.downcase() end
    Enum.sort_by(items, sorter, if(direction == :desc, do: :desc, else: :asc))
  end

  defp apply_pagination(items, nil), do: items

  defp apply_pagination(items, %{page: page, size: size}) do
    Enum.slice(items, (page - 1) * size, size)
  end

  defp add_errors(changeset, errors) when is_map(errors) do
    Enum.reduce(errors, changeset, fn {field, message}, acc ->
      Ecto.Changeset.add_error(acc, field, message)
    end)
  end

  defp add_errors(changeset, reason),
    do: Ecto.Changeset.add_error(changeset, :base, inspect(reason))
end
