defmodule BumblebeeLns.Connectors do
  @moduledoc """
  Reads and updates backend connector records stored in Mnesia.
  """

  @connector_fields [
    :connid,
    :app,
    :format,
    :uri,
    :publish_qos,
    :publish_uplinks,
    :publish_events,
    :subscribe_qos,
    :subscribe,
    :received,
    :enabled,
    :failed,
    :client_id,
    :auth,
    :name,
    :pass,
    :certfile,
    :keyfile,
    :health_alerts,
    :health_decay,
    :health_reported,
    :health_next
  ]

  def list_connectors do
    :connector
    |> :mnesia.dirty_all_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(:connector, key) do
        [record] -> [from_record(record)]
        [] -> []
      end
    end)
    |> Enum.sort_by(&String.downcase(&1.connid))
  end

  def get_connector(connid) do
    case :mnesia.dirty_read(:connector, normalize_string(connid)) do
      [record] -> {:ok, from_record(record)}
      [] -> {:error, :not_found}
    end
  end

  def create_connector(params) when is_map(params) do
    with {:ok, attributes} <- validate(params),
         :ok <- ensure_missing(attributes.connid) do
      record = connector_record(attributes, %{})

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save connector: #{inspect(reason)}"}}
      end
    end
  end

  def update_connector(connid, params) when is_map(params) do
    with {:ok, original} <- read_raw(connid),
         {:ok, attributes} <- validate(Map.put(params, "connid", connid)) do
      record = connector_record(attributes, tuple_map(original, @connector_fields))

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save connector: #{inspect(reason)}"}}
      end
    end
  end

  def delete_connector(connid) do
    with {:ok, record} <- read_raw(connid) do
      :mnesia.dirty_delete(:connector, normalize_string(connid))
      {:ok, from_record(record)}
    end
  end

  defp read_raw(connid) do
    case :mnesia.dirty_read(:connector, normalize_string(connid)) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  defp validate(params) do
    connid = normalize_string(Map.get(params, "connid"))
    app = normalize_string(Map.get(params, "app"))
    format = normalize_string(Map.get(params, "format", "json"))
    uri = normalize_string(Map.get(params, "uri"))

    base_errors =
      %{}
      |> required(:connid, connid)
      |> required(:app, app)
      |> required(:format, format)
      |> required(:uri, uri)

    with {:ok, publish_qos} <- parse_qos(Map.get(params, "publish_qos", 0), :publish_qos),
         {:ok, subscribe_qos} <- parse_qos(Map.get(params, "subscribe_qos", 0), :subscribe_qos) do
      errors =
        if format in ["json", "raw"] do
          base_errors
        else
          Map.put(base_errors, :format, "must be json or raw")
        end

      if map_size(errors) == 0 do
        {:ok,
         %{
           connid: connid,
           app: app,
           format: format,
           uri: uri,
           publish_qos: publish_qos,
           publish_uplinks: normalize_optional(Map.get(params, "publish_uplinks")),
           publish_events: normalize_optional(Map.get(params, "publish_events")),
           subscribe_qos: subscribe_qos,
           subscribe: normalize_optional(Map.get(params, "subscribe")),
           received: normalize_optional(Map.get(params, "received")),
           enabled: truthy?(Map.get(params, "enabled", true)),
           client_id: normalize_optional(Map.get(params, "client_id")),
           auth: normalize_optional(Map.get(params, "auth")) || "basic",
           name: normalize_optional(Map.get(params, "name")),
           pass: normalize_optional(Map.get(params, "pass")),
           certfile: normalize_optional(Map.get(params, "certfile")),
           keyfile: normalize_optional(Map.get(params, "keyfile"))
         }}
      else
        {:error, errors}
      end
    else
      {:error, parse_errors} -> {:error, Map.merge(base_errors, parse_errors)}
    end
  end

  defp connector_record(attrs, original) do
    {:connector, attrs.connid, attrs.app, attrs.format, attrs.uri, attrs.publish_qos,
     attrs.publish_uplinks, attrs.publish_events, attrs.subscribe_qos, attrs.subscribe,
     attrs.received, attrs.enabled, Map.get(original, :failed, []), attrs.client_id, attrs.auth,
     attrs.name, attrs.pass, attrs.certfile, attrs.keyfile, Map.get(original, :health_alerts, []),
     Map.get(original, :health_decay, 0), Map.get(original, :health_reported, 0),
     Map.get(original, :health_next, :undefined)}
  end

  defp from_record(record) do
    record
    |> tuple_map(@connector_fields)
    |> stringify_map([
      :connid,
      :app,
      :format,
      :uri,
      :publish_uplinks,
      :publish_events,
      :subscribe,
      :received,
      :client_id,
      :auth,
      :name,
      :pass,
      :certfile,
      :keyfile
    ])
    |> Map.update!(:enabled, &(&1 == true))
    |> Map.update!(:failed, &string_list/1)
    |> Map.update!(:health_alerts, &string_list/1)
  end

  defp tuple_map(record, fields) do
    values = record |> Tuple.to_list() |> tl()
    fields |> Enum.zip(values) |> Map.new()
  end

  defp stringify_map(map, keys) do
    Enum.reduce(keys, map, fn key, acc -> Map.update(acc, key, "", &optional_to_string/1) end)
  end

  defp ensure_missing(connid) do
    case :mnesia.dirty_read(:connector, connid) do
      [] -> :ok
      [_record] -> {:error, %{connid: "Connector already exists"}}
    end
  end

  defp required(errors, field, value) when value in [nil, ""],
    do: Map.put(errors, field, "is required")

  defp required(errors, _field, _value), do: errors

  defp parse_qos(value, field) do
    case Integer.parse(to_string(value || "")) do
      {qos, ""} when qos in 0..2 -> {:ok, qos}
      {_qos, ""} -> {:error, %{field => "must be 0, 1, or 2"}}
      _ -> {:error, %{field => "must be an integer"}}
    end
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(value), do: value |> to_string() |> String.trim()

  defp normalize_optional(value) when value in [nil, ""], do: :undefined

  defp normalize_optional(value) do
    case normalize_string(value) do
      "" -> :undefined
      value -> value
    end
  end

  defp truthy?(value), do: value in [true, "true", "on", "1", 1]

  defp optional_to_string(value) when value in [nil, :undefined], do: ""
  defp optional_to_string(value), do: to_string(value)

  defp string_list(value) when is_list(value), do: Enum.map(value, &to_string/1)
  defp string_list(_value), do: []
end
