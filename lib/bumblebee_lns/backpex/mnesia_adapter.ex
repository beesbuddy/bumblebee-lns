defmodule BumblebeeLns.Backpex.MnesiaAdapter do
  @moduledoc """
  Backpex data-layer adapter for contexts backed by Mnesia.
  """

  @config_schema [
    schema: [type: :atom, required: true],
    list: [type: {:fun, 0}, required: true],
    get: [type: {:fun, 1}, required: true],
    create: [type: {:fun, 1}],
    update: [type: {:fun, 2}, required: true],
    delete: [type: {:fun, 1}],
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
    |> with_action(action)
  end

  @impl Backpex.Adapter
  def update(%Ecto.Changeset{} = changeset, live_resource) do
    changeset = with_action(changeset, :update)

    if changeset.valid? do
      item = Ecto.Changeset.apply_changes(changeset)

      attrs =
        item
        |> Map.from_struct()
        |> Map.new(fn {key, value} -> {to_string(key), value} end)

      primary_value = Map.fetch!(item, live_resource.config(:primary_key))

      case live_resource.adapter_config(:update).(primary_value, attrs) do
        {:ok, updated} ->
          {:ok, to_schema(updated, live_resource)}

        {:error, errors} ->
          {:error, add_errors(changeset, errors)}
      end
    else
      {:error, mark_error_fields_used(changeset)}
    end
  end

  @impl Backpex.Adapter
  def insert(%Ecto.Changeset{} = changeset, live_resource) do
    changeset = with_action(changeset, :insert)
    create = live_resource.adapter_config(:create)

    cond do
      is_nil(create) ->
        {:error, Ecto.Changeset.add_error(changeset, :base, "creation is not supported")}

      changeset.valid? ->
        attrs =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.from_struct()
          |> Map.new(fn {key, value} -> {to_string(key), value} end)

        case create.(attrs) do
          {:ok, created} ->
            {:ok, to_schema(created, live_resource)}

          {:error, errors} ->
            {:error, add_errors(changeset, errors)}
        end

      true ->
        {:error, mark_error_fields_used(changeset)}
    end
  end

  @impl Backpex.Adapter
  def delete_all(items, live_resource) do
    delete = live_resource.adapter_config(:delete)
    primary_key = live_resource.config(:primary_key)

    if is_nil(delete) do
      {:error, :not_supported}
    else
      deleted_items =
        Enum.flat_map(items, fn item ->
          primary_value = Map.fetch!(item, primary_key)

          case delete.(primary_value) do
            {:ok, deleted} -> [to_schema(deleted, live_resource)]
            {:error, :not_found} -> []
            {:error, reason} -> raise "Could not delete item: #{inspect(reason)}"
          end
        end)

      {:ok, deleted_items}
    end
  end

  @impl Backpex.Adapter
  def update_all(_items, _updates, _live_resource), do: :error

  defp changeset_function(:new, live_resource),
    do: live_resource.adapter_config(:create_changeset)

  defp changeset_function(_, live_resource),
    do: live_resource.adapter_config(:update_changeset)

  defp with_action(%Ecto.Changeset{} = changeset, action) do
    %{changeset | action: changeset.action || action}
  end

  defp add_errors(%Ecto.Changeset{} = changeset, errors) when is_map(errors) do
    Enum.reduce(errors, changeset, fn {field, message}, acc ->
      add_field_error(acc, field, message)
    end)
  end

  defp add_errors(%Ecto.Changeset{} = changeset, errors) when is_list(errors) do
    cond do
      keyword_errors?(errors) ->
        Enum.reduce(errors, changeset, fn {field, message}, acc ->
          add_field_error(acc, field, message)
        end)

      charlist?(errors) ->
        Ecto.Changeset.add_error(changeset, :base, normalize_error_message(errors))

      true ->
        Enum.reduce(errors, changeset, fn message, acc ->
          Ecto.Changeset.add_error(acc, :base, normalize_error_message(message))
        end)
    end
  end

  defp add_errors(%Ecto.Changeset{} = changeset, reason) do
    Ecto.Changeset.add_error(changeset, :base, normalize_error_message(reason))
  end

  defp mark_error_fields_used(%Ecto.Changeset{} = changeset) do
    Enum.reduce(changeset.errors, changeset, fn
      {:base, _error}, acc -> acc
      {field, _error}, acc -> mark_field_used(acc, field)
    end)
  end

  defp add_field_error(%Ecto.Changeset{} = changeset, field, messages) when is_list(messages) do
    if charlist?(messages) do
      add_field_error(changeset, field, normalize_error_message(messages))
    else
      Enum.reduce(messages, changeset, fn message, acc ->
        add_field_error(acc, field, message)
      end)
    end
  end

  defp add_field_error(%Ecto.Changeset{} = changeset, field, message) do
    message = normalize_error_message(message)

    case normalize_error_field(field, known_fields(changeset)) do
      {:ok, field} ->
        changeset
        |> mark_field_used(field)
        |> Ecto.Changeset.add_error(field, message)

      :error ->
        Ecto.Changeset.add_error(changeset, :base, "#{normalize_error_label(field)}: #{message}")
    end
  end

  defp mark_field_used(%Ecto.Changeset{params: nil} = changeset, _field), do: changeset

  defp mark_field_used(%Ecto.Changeset{params: params} = changeset, field) when is_map(params) do
    %{changeset | params: Map.delete(params, "_unused_#{field}")}
  end

  defp normalize_error_field(field, known_fields) when is_atom(field) do
    if field in known_fields, do: {:ok, field}, else: :error
  end

  defp normalize_error_field(field, known_fields) when is_binary(field) do
    Enum.find_value(known_fields, :error, fn known_field ->
      if Atom.to_string(known_field) == field, do: {:ok, known_field}
    end)
  end

  defp normalize_error_field(field, known_fields) when is_list(field) do
    if charlist?(field), do: normalize_error_field(to_string(field), known_fields), else: :error
  end

  defp normalize_error_field(_field, _known_fields), do: :error

  defp normalize_error_label(field) when is_atom(field), do: Atom.to_string(field)
  defp normalize_error_label(field) when is_binary(field), do: field

  defp normalize_error_label(field) when is_list(field) do
    if charlist?(field), do: to_string(field), else: inspect(field)
  end

  defp normalize_error_label(field), do: inspect(field)

  defp known_fields(%Ecto.Changeset{data: data}) do
    data.__struct__.__schema__(:fields) ++ data.__struct__.__schema__(:virtual_fields)
  end

  defp keyword_errors?(errors), do: Enum.all?(errors, &field_error?/1)

  defp field_error?({field, _message})
       when is_atom(field) or is_binary(field) or is_list(field),
       do: true

  defp field_error?(_error), do: false

  defp charlist?([]), do: false
  defp charlist?(value), do: List.ascii_printable?(value)

  defp normalize_error_message(message) when is_binary(message), do: message

  defp normalize_error_message(message) when is_list(message) do
    if charlist?(message), do: to_string(message), else: inspect(message)
  end

  defp normalize_error_message(message), do: inspect(message)

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
    sorter = fn item ->
      item
      |> Map.get(field)
      |> searchable_value()
      |> String.downcase()
    end

    Enum.sort_by(items, sorter, if(direction == :desc, do: :desc, else: :asc))
  end

  defp apply_pagination(items, nil), do: items

  defp apply_pagination(items, %{page: page, size: size}) do
    Enum.slice(items, (page - 1) * size, size)
  end
end
