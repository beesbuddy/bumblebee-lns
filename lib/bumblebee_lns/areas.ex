defmodule BumblebeeLns.Areas do
  @moduledoc """
  Reads and updates LNS areas stored in Mnesia.
  """

  @regions [
    {"EU868", "EU 863-870MHz"},
    {"US902", "US 902-928MHz"},
    {"US902-PR", "US 902-928MHz (Private Hybrid)"},
    {"CN779", "China 779-787MHz"},
    {"EU433", "EU 433MHz"},
    {"AU915", "Australia 915-928MHz"},
    {"CN470", "China 470-510MHz"},
    {"AS923", "Asia 923MHz"},
    {"KR920", "South Korea 920-923MHz"},
    {"IN865", "India 865-867MHz"},
    {"RU868", "Russia 864-870MHz"}
  ]

  def regions, do: @regions

  def list_areas do
    :area
    |> :mnesia.dirty_all_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(:area, key) do
        [record] -> [from_record(record)]
        [] -> []
      end
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def get_area(name) when is_binary(name) do
    case :mnesia.dirty_read(:area, name) do
      [record] -> {:ok, from_record(record)}
      [] -> {:error, :not_found}
    end
  end

  def list_administrators do
    :user
    |> :mnesia.dirty_all_keys()
    |> Enum.map(&to_string/1)
    |> Enum.sort_by(&String.downcase/1)
  end

  def create_area(params) when is_map(params) do
    with {:ok, attributes} <- validate(params),
         :ok <- ensure_missing(attributes.name) do
      record = area_record(attributes)

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save area: #{inspect(reason)}"}}
      end
    end
  end

  def update_area(name, params) when is_binary(name) and is_map(params) do
    with {:ok, area} <- get_area(name),
         {:ok, attributes} <- validate(params) do
      record = area_record(Map.put(attributes, :name, name))

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, Map.merge(area, attributes)}
        {:aborted, reason} -> {:error, %{base: "Could not save area: #{inspect(reason)}"}}
      end
    end
  end

  defp validate(params) do
    name = params |> Map.get("name", "") |> String.trim()
    region = params |> Map.get("region", "") |> String.trim()
    valid_regions = Enum.map(@regions, &elem(&1, 0))

    errors =
      %{}
      |> add_error(name == "", :name, "Name is required")
      |> add_error(region == "", :region, "Region is required")
      |> add_error(region != "" and region not in valid_regions, :region, "Region is invalid")

    if map_size(errors) == 0 do
      {:ok,
       %{
         name: name,
         region: region,
         admins: normalize_admins(Map.get(params, "admins", [])),
         slack_channel: normalize_optional(Map.get(params, "slack_channel")),
         log_ignored: Map.get(params, "log_ignored") in [true, "true", "on", "1"]
       }}
    else
      {:error, errors}
    end
  end

  defp area_record(attributes) do
    {:area, attributes.name, attributes.region, attributes.admins, attributes.slack_channel,
     attributes.log_ignored}
  end

  defp ensure_missing(name) do
    case :mnesia.dirty_read(:area, name) do
      [] -> :ok
      [_] -> {:error, %{name: "Area already exists"}}
    end
  end

  defp add_error(errors, true, field, message), do: Map.put(errors, field, message)
  defp add_error(errors, false, _field, _message), do: errors

  defp normalize_admins(admins) do
    admins
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_optional(value) when value in [nil, ""], do: :undefined

  defp normalize_optional(value) do
    case String.trim(to_string(value)) do
      "" -> :undefined
      trimmed -> trimmed
    end
  end

  defp from_record({:area, name, region, admins, slack_channel, log_ignored}) do
    %{
      name: to_string(name),
      region: to_string(region),
      admins: Enum.map(admins, &to_string/1),
      slack_channel: optional_to_string(slack_channel),
      log_ignored: log_ignored == true
    }
  end

  defp optional_to_string(value) when value in [nil, :undefined], do: ""
  defp optional_to_string(value), do: to_string(value)
end
