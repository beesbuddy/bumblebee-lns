defmodule BumblebeeLns.Gateways do
  @moduledoc """
  Reads and updates LNS gateways stored in Mnesia.
  """

  alias BumblebeeLns.Areas

  @gateway_fields [
    :mac,
    :area,
    :tx_rfch,
    :ant_gain,
    :desc,
    :gpspos,
    :gpsalt,
    :ip_address,
    :last_alive,
    :last_gps,
    :last_report,
    :dwell,
    :delays,
    :health_alerts,
    :health_decay,
    :health_reported,
    :health_next
  ]

  def list_gateways do
    :gateway
    |> :mnesia.dirty_all_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(:gateway, key) do
        [record] -> [from_record(record)]
        [] -> []
      end
    end)
    |> Enum.sort_by(& &1.mac)
  end

  def get_gateway(mac) when is_binary(mac) do
    with {:ok, key} <- parse_mac(mac) do
      case :mnesia.dirty_read(:gateway, key) do
        [record] -> {:ok, from_record(record)}
        [] -> {:error, :not_found}
      end
    end
  end

  def list_area_options do
    Areas.list_areas()
    |> Enum.map(&{&1.name, &1.name})
  end

  def create_gateway(params) when is_map(params) do
    with {:ok, attributes} <- validate(params),
         :ok <- ensure_missing(attributes.mac) do
      record = gateway_record(attributes, %{})

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save gateway: #{inspect(reason)}"}}
      end
    end
  end

  def update_gateway(mac, params) when is_binary(mac) and is_map(params) do
    with {:ok, key} <- parse_mac(mac),
         {:ok, gateway} <- get_gateway(mac),
         {:ok, attributes} <- validate(Map.put(params, "mac", mac)) do
      attributes = Map.put(attributes, :mac, key)
      record = gateway_record(attributes, gateway)

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save gateway: #{inspect(reason)}"}}
      end
    end
  end

  defp validate(params) do
    errors =
      %{}
      |> add_error(blank?(Map.get(params, "mac")), :mac, "MAC is required")
      |> add_error(blank?(Map.get(params, "tx_rfch")), :tx_rfch, "TX RF chain is required")
      |> add_error(blank?(Map.get(params, "ant_gain")), :ant_gain, "Antenna gain is required")
      |> add_error(blank?(Map.get(params, "latitude")), :latitude, "Latitude is required")
      |> add_error(blank?(Map.get(params, "longitude")), :longitude, "Longitude is required")

    with {:ok, mac} <- parse_mac(Map.get(params, "mac")),
         {:ok, tx_rfch} <- parse_integer(Map.get(params, "tx_rfch"), :tx_rfch),
         {:ok, ant_gain} <- parse_integer(Map.get(params, "ant_gain"), :ant_gain),
         {:ok, latitude} <- parse_float(Map.get(params, "latitude"), :latitude),
         {:ok, longitude} <- parse_float(Map.get(params, "longitude"), :longitude),
         {:ok, gpsalt} <- parse_optional_float(Map.get(params, "gpsalt"), :gpsalt) do
      errors =
        errors
        |> add_error(
          latitude < -90 or latitude > 90,
          :latitude,
          "Latitude must be between -90 and 90"
        )
        |> add_error(
          longitude < -180 or longitude > 180,
          :longitude,
          "Longitude must be between -180 and 180"
        )

      if map_size(errors) == 0 do
        {:ok,
         %{
           mac: mac,
           area: normalize_optional(Map.get(params, "area")),
           tx_rfch: tx_rfch,
           ant_gain: ant_gain,
           desc: normalize_optional(Map.get(params, "desc")),
           gpspos: {latitude, longitude},
           gpsalt: gpsalt
         }}
      else
        {:error, errors}
      end
    else
      {:error, field, message} -> {:error, Map.put(errors, field, message)}
    end
  end

  defp gateway_record(attributes, original) do
    {:gateway, attributes.mac, attributes.area, attributes.tx_rfch, attributes.ant_gain,
     attributes.desc, attributes.gpspos, attributes.gpsalt,
     runtime_optional(Map.get(original, :ip_address)),
     runtime_optional(Map.get(original, :last_alive)),
     runtime_optional(Map.get(original, :last_gps)),
     runtime_optional(Map.get(original, :last_report)), Map.get(original, :dwell, []),
     Map.get(original, :delays, []), Map.get(original, :health_alerts, []),
     Map.get(original, :health_decay, 0), Map.get(original, :health_reported, 0),
     Map.get(original, :health_next)}
  end

  defp ensure_missing(mac) do
    case :mnesia.dirty_read(:gateway, mac) do
      [] -> :ok
      [_] -> {:error, %{mac: "Gateway already exists"}}
    end
  end

  defp parse_mac(nil), do: {:error, :mac, "MAC is required"}

  defp parse_mac(mac) do
    mac = mac |> to_string() |> String.trim() |> String.upcase()

    if String.match?(mac, ~r/\A[0-9A-F]{16}\z/) do
      {:ok, :bumblebee_utils.hex_to_binary(mac)}
    else
      {:error, :mac, "must be 16 hexadecimal characters"}
    end
  end

  defp parse_integer(value, _field) when is_integer(value), do: {:ok, value}

  defp parse_integer(value, field) do
    case Integer.parse(to_string(value || "")) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, field, "must be an integer"}
    end
  end

  defp parse_optional_float(value, _field) when value in [nil, ""], do: {:ok, :undefined}
  defp parse_optional_float(value, field), do: parse_float(value, field)

  defp parse_float(value, _field) when is_integer(value), do: {:ok, value / 1}
  defp parse_float(value, _field) when is_float(value), do: {:ok, value}

  defp parse_float(value, field) do
    case Float.parse(to_string(value || "")) do
      {float, ""} -> {:ok, float}
      _ -> {:error, field, "must be a number"}
    end
  end

  defp from_record(record) do
    values = record |> Tuple.to_list() |> tl()
    gateway = @gateway_fields |> Enum.zip(values) |> Map.new()
    {latitude, longitude} = gps_position(Map.get(gateway, :gpspos))

    %{
      mac: :bumblebee_utils.binary_to_hex(gateway.mac),
      area: optional_to_string(gateway.area),
      tx_rfch: gateway.tx_rfch,
      ant_gain: gateway.ant_gain,
      desc: optional_to_string(gateway.desc),
      latitude: optional_number(latitude),
      longitude: optional_number(longitude),
      gpsalt: optional_number(gateway.gpsalt),
      ip_address: gateway.ip_address,
      last_alive: format_datetime(gateway.last_alive),
      last_gps: format_datetime(gateway.last_gps),
      last_report: format_datetime(gateway.last_report),
      dwell: gateway.dwell,
      delays: gateway.delays,
      health_alerts: health_alerts(gateway.health_alerts),
      health_decay: gateway.health_decay,
      health_reported: gateway.health_reported,
      health_next: gateway.health_next
    }
  end

  defp add_error(errors, true, field, message), do: Map.put(errors, field, message)
  defp add_error(errors, false, _field, _message), do: errors

  defp blank?(value), do: value in [nil, ""]

  defp normalize_optional(value) when value in [nil, ""], do: :undefined

  defp normalize_optional(value) do
    case String.trim(to_string(value)) do
      "" -> :undefined
      trimmed -> trimmed
    end
  end

  defp optional_to_string(value) when value in [nil, :undefined], do: ""
  defp optional_to_string(value), do: to_string(value)

  defp optional_number(value) when value in [nil, :undefined], do: nil
  defp optional_number(value), do: value

  defp gps_position({latitude, longitude}), do: {latitude, longitude}
  defp gps_position(_value), do: {nil, nil}

  defp health_alerts(value) when value in [nil, :undefined], do: []
  defp health_alerts(value), do: Enum.map(List.wrap(value), &to_string/1)

  defp runtime_optional(value) when value in [nil, "", :undefined], do: :undefined
  defp runtime_optional(value), do: value

  defp format_datetime(value) when value in [nil, :undefined], do: ""
  defp format_datetime(value), do: value |> :iso8601.format() |> to_string()
end
