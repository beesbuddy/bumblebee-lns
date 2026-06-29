defmodule BumblebeeLns.Devices do
  @moduledoc """
  Reads and updates device-related LNS records stored in Mnesia.
  """

  alias BumblebeeLns.Areas

  @group_fields [:name, :network, :subid, :admins, :slack_channel, :can_join]

  @profile_fields [
    :name,
    :group,
    :app,
    :appid,
    :join,
    :fcnt_check,
    :txwin,
    :adr_mode,
    :adr_set,
    :max_datr,
    :dcycle_set,
    :rxwin_set,
    :request_devstat
  ]

  @device_fields [
    :deveui,
    :profile,
    :appargs,
    :appeui,
    :appkey,
    :nwkkey,
    :desc,
    :last_joins,
    :node
  ]

  @node_fields [
    :devaddr,
    :profile,
    :appargs,
    :nwkskey,
    :appskey,
    :fnwksintkey,
    :snwksintkey,
    :nwksenckey,
    :desc,
    :location,
    :fcntup,
    :fcntdown,
    :first_reset,
    :last_reset,
    :reset_count,
    :last_rx,
    :gateways,
    :adr_flag,
    :adr_set,
    :adr_use,
    :adr_failed,
    :dcycle_use,
    :rxwin_use,
    :rxwin_failed,
    :last_qs,
    :average_qs,
    :devstat_time,
    :devstat_fcnt,
    :devstat,
    :health_alerts,
    :health_decay,
    :health_reported,
    :health_next
  ]

  def list_groups, do: list_records(:group, &group_from_record/1, &String.downcase(&1.name))
  def list_profiles, do: list_records(:profile, &profile_from_record/1, &String.downcase(&1.name))
  def list_devices, do: list_records(:device, &device_from_record/1, & &1.deveui)
  def list_nodes, do: list_records(:node, &node_from_record/1, & &1.devaddr)

  def list_ignored_nodes,
    do: list_records(:ignored_node, &ignored_node_from_record/1, & &1.devaddr)

  def get_group(name), do: get_record(:group, name, &group_from_record/1)
  def get_profile(name), do: get_record(:profile, name, &profile_from_record/1)
  def get_device(deveui), do: get_hex_record(:device, deveui, 16, &device_from_record/1)
  def get_node(devaddr), do: get_hex_record(:node, devaddr, 8, &node_from_record/1)

  def get_ignored_node(devaddr),
    do: get_hex_record(:ignored_node, devaddr, 8, &ignored_node_from_record/1)

  def list_network_options, do: option_keys(:network)
  def list_group_options, do: option_keys(:group)
  def list_profile_options, do: option_keys(:profile)
  def list_administrator_options, do: Enum.map(Areas.list_administrators(), &{&1, &1})

  def create_group(params), do: create(:group, params, &validate_group/1, &group_record/1)

  def update_group(name, params) do
    IO.inspect("Update group")

    with {:ok, original} <- read_raw(:group, name),
         {:ok, attributes} <- validate_group(Map.put(params, "name", name)) do
      write(
        :group,
        group_record(Map.put(attributes, :name, name), tuple_map(original, @group_fields)),
        &group_from_record/1
      )
    end
  end

  def delete_group(name), do: delete(:group, name, &group_from_record/1)

  def create_profile(params) do
    IO.inspect("Create profile")
    create(:profile, params, &validate_profile/1, &profile_record/1)
  end

  def update_profile(name, params) do
    IO.inspect("Update")

    update(
      :profile,
      name,
      params,
      &validate_profile/1,
      &profile_record/1,
      &profile_from_record/1
    )
  end

  def delete_profile(name), do: delete(:profile, name, &profile_from_record/1)

  def create_device(params), do: create(:device, params, &validate_device/1, &device_record/1)

  def update_device(deveui, params) do
    with {:ok, key} <- parse_hex(deveui, :deveui, 16),
         {:ok, original} <- read_raw(:device, key),
         {:ok, attributes} <- validate_device(Map.put(params, "deveui", deveui)) do
      write(
        :device,
        device_record(attributes, device_from_record(original)),
        &device_from_record/1
      )
    end
  end

  def delete_device(deveui), do: delete_hex(:device, deveui, 16, &device_from_record/1)

  def create_node(params), do: create(:node, params, &validate_node/1, &node_record/1)

  def update_node(devaddr, params) do
    with {:ok, key} <- parse_hex(devaddr, :devaddr, 8),
         {:ok, original} <- read_raw(:node, key),
         {:ok, attributes} <- validate_node(Map.put(params, "devaddr", devaddr)) do
      write(:node, node_record(attributes, node_from_record(original)), &node_from_record/1)
    end
  end

  def delete_node(devaddr), do: delete_hex(:node, devaddr, 8, &node_from_record/1)

  def create_ignored_node(params),
    do: create(:ignored_node, params, &validate_ignored_node/1, &ignored_node_record/1)

  def update_ignored_node(devaddr, params) do
    with {:ok, key} <- parse_hex(devaddr, :devaddr, 8),
         {:ok, _original} <- read_raw(:ignored_node, key),
         {:ok, attributes} <- validate_ignored_node(Map.put(params, "devaddr", devaddr)) do
      write(:ignored_node, ignored_node_record(attributes), &ignored_node_from_record/1)
    end
  end

  def delete_ignored_node(devaddr),
    do: delete_hex(:ignored_node, devaddr, 8, &ignored_node_from_record/1)

  defp list_records(table, mapper, sorter) do
    table
    |> :mnesia.dirty_all_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(table, key) do
        [record] -> [mapper.(record)]
        [] -> []
      end
    end)
    |> Enum.sort_by(sorter)
  end

  defp get_record(table, key, mapper), do: table |> read_raw(key) |> map_result(mapper)

  defp get_hex_record(table, key, size, mapper) do
    with {:ok, parsed} <- parse_hex(key, table, size) do
      get_record(table, parsed, mapper)
    end
  end

  defp read_raw(table, key) do
    case :mnesia.dirty_read(table, key) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  defp map_result({:ok, record}, mapper), do: {:ok, mapper.(record)}
  defp map_result(error, _mapper), do: error

  defp option_keys(table) do
    table
    |> :mnesia.dirty_all_keys()
    |> Enum.map(&to_string/1)
    |> Enum.sort_by(&String.downcase/1)
    |> Enum.map(&{&1, &1})
  end

  defp create(table, params, validator, record_builder) do
    with {:ok, attributes} <- validator.(params),
         :ok <- ensure_missing(table, primary_value(attributes)) do
      write(table, record_builder.(attributes), mapper_for(table))
    end
  end

  defp update(table, key, params, validator, record_builder, mapper) do
    with {:ok, _original} <- read_raw(table, key),
         {:ok, attributes} <- validator.(Map.put(params, "name", key)) do
      write(table, record_builder.(Map.put(attributes, :name, key)), mapper)
    end
  end

  defp write(_table, record, mapper) do
    case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
      {:atomic, :ok} -> {:ok, mapper.(record)}
      {:aborted, reason} -> {:error, %{base: "Could not save record: #{inspect(reason)}"}}
    end
  end

  defp delete(table, key, mapper) do
    with {:ok, record} <- read_raw(table, key) do
      :mnesia.dirty_delete(table, key)
      {:ok, mapper.(record)}
    end
  end

  defp delete_hex(table, key, size, mapper) do
    with {:ok, parsed} <- parse_hex(key, table, size) do
      delete(table, parsed, mapper)
    end
  end

  defp mapper_for(:group), do: &group_from_record/1
  defp mapper_for(:profile), do: &profile_from_record/1
  defp mapper_for(:device), do: &device_from_record/1
  defp mapper_for(:node), do: &node_from_record/1
  defp mapper_for(:ignored_node), do: &ignored_node_from_record/1

  defp primary_value(%{name: name}), do: name
  defp primary_value(%{deveui: deveui}), do: deveui
  defp primary_value(%{devaddr: devaddr}), do: devaddr

  defp ensure_missing(table, key) do
    case :mnesia.dirty_read(table, key) do
      [] -> :ok
      [_] -> {:error, %{base: "Record already exists"}}
    end
  end

  defp validate_group(params) do
    name = normalize_string(Map.get(params, "name"))
    network = normalize_string(Map.get(params, "network"))
    errors = %{} |> required(:name, name) |> required(:network, network)

    if map_size(errors) == 0 do
      {:ok,
       %{
         name: name,
         network: network,
         admins: normalize_list(Map.get(params, "admins", [])),
         slack_channel: normalize_optional(Map.get(params, "slack_channel")),
         can_join: truthy?(Map.get(params, "can_join"))
       }}
    else
      {:error, errors}
    end
  end

  defp validate_profile(params) do
    name = normalize_string(Map.get(params, "name"))
    group = normalize_string(Map.get(params, "group"))
    app = normalize_string(Map.get(params, "app"))

    base_errors =
      %{}
      |> required(:name, name)
      |> required(:group, group)
      |> required(:app, app)

    with {:ok, join} <- parse_integer(Map.get(params, "join", 1), :join),
         {:ok, adr_mode} <- parse_integer(Map.get(params, "adr_mode", 0), :adr_mode),
         {:ok, txwin} <- parse_optional_integer(Map.get(params, "txwin"), :txwin),
         {:ok, fcnt_check} <- parse_optional_integer(Map.get(params, "fcnt_check"), :fcnt_check),
         {:ok, max_datr} <- parse_optional_float(Map.get(params, "max_datr"), :max_datr),
         {:ok, dcycle_set} <- parse_optional_integer(Map.get(params, "dcycle_set"), :dcycle_set) do
      if map_size(base_errors) == 0 do
        {:ok,
         %{
           name: name,
           group: group,
           app: app,
           appid: normalize_optional(Map.get(params, "appid")),
           join: join,
           fcnt_check: fcnt_check,
           txwin: txwin,
           adr_mode: adr_mode,
           adr_set: :undefined,
           max_datr: max_datr,
           dcycle_set: dcycle_set,
           rxwin_set: :undefined,
           request_devstat: truthy?(Map.get(params, "request_devstat"))
         }}
      else
        {:error, base_errors}
      end
    else
      {:error, parse_errors} ->
        IO.inspect(Map.merge(base_errors, parse_errors))
        {:error, Map.merge(base_errors, parse_errors)}
    end
  end

  defp validate_device(params) do
    errors = %{} |> required(:profile, normalize_string(Map.get(params, "profile")))

    with {:ok, deveui} <- parse_hex(Map.get(params, "deveui"), :deveui, 16),
         {:ok, appeui} <- parse_optional_hex(Map.get(params, "appeui"), :appeui, 16),
         {:ok, appkey} <- parse_hex(Map.get(params, "appkey"), :appkey, 32),
         {:ok, nwkkey} <- parse_optional_hex(Map.get(params, "nwkkey"), :nwkkey, 32),
         {:ok, node} <- parse_optional_hex(Map.get(params, "node"), :node, 8) do
      if map_size(errors) == 0 do
        {:ok,
         %{
           deveui: deveui,
           profile: normalize_string(Map.get(params, "profile")),
           appargs: normalize_optional(Map.get(params, "appargs")),
           appeui: appeui,
           appkey: appkey,
           nwkkey: nwkkey,
           desc: normalize_optional(Map.get(params, "desc")),
           last_joins: [],
           node: node
         }}
      else
        {:error, errors}
      end
    end
  end

  defp validate_node(params) do
    errors = %{} |> required(:profile, normalize_string(Map.get(params, "profile")))

    with {:ok, devaddr} <- parse_hex(Map.get(params, "devaddr"), :devaddr, 8),
         {:ok, nwkskey} <- parse_hex(Map.get(params, "nwkskey"), :nwkskey, 32),
         {:ok, appskey} <- parse_hex(Map.get(params, "appskey"), :appskey, 32),
         {:ok, fcntup} <- parse_optional_integer(Map.get(params, "fcntup", 0), :fcntup),
         {:ok, fcntdown} <- parse_optional_integer(Map.get(params, "fcntdown", 0), :fcntdown),
         {:ok, adr_flag} <- parse_integer(Map.get(params, "adr_flag", 0), :adr_flag) do
      if map_size(errors) == 0 do
        {:ok,
         %{
           devaddr: devaddr,
           profile: normalize_string(Map.get(params, "profile")),
           appargs: normalize_optional(Map.get(params, "appargs")),
           nwkskey: nwkskey,
           appskey: appskey,
           desc: normalize_optional(Map.get(params, "desc")),
           location: normalize_optional(Map.get(params, "location")),
           fcntup: fcntup,
           fcntdown: fcntdown,
           adr_flag: adr_flag
         }}
      else
        {:error, errors}
      end
    end
  end

  defp validate_ignored_node(params) do
    with {:ok, devaddr} <- parse_hex(Map.get(params, "devaddr"), :devaddr, 8),
         {:ok, mask} <- parse_hex(Map.get(params, "mask"), :mask, 8) do
      {:ok, %{devaddr: devaddr, mask: mask}}
    end
  end

  defp group_record(attrs), do: group_record(attrs, %{})

  defp group_record(attrs, original) do
    {:group, attrs.name, attrs.network, Map.get(original, :subid, :undefined), attrs.admins,
     attrs.slack_channel, attrs.can_join}
  end

  defp profile_record(attrs) do
    {:profile, attrs.name, attrs.group, attrs.app, attrs.appid, attrs.join, attrs.fcnt_check,
     attrs.txwin, attrs.adr_mode, attrs.adr_set, attrs.max_datr, attrs.dcycle_set,
     attrs.rxwin_set, attrs.request_devstat}
  end

  defp device_record(attrs), do: device_record(attrs, %{})

  defp device_record(attrs, original) do
    {:device, attrs.deveui, attrs.profile, attrs.appargs, attrs.appeui, attrs.appkey,
     attrs.nwkkey, attrs.desc, Map.get(original, :last_joins, []), attrs.node}
  end

  defp node_record(attrs), do: node_record(attrs, %{})

  defp node_record(attrs, original) do
    now = :calendar.universal_time()

    {:node, attrs.devaddr, attrs.profile, attrs.appargs, attrs.nwkskey, attrs.appskey,
     Map.get(original, :fnwksintkey, :undefined), Map.get(original, :snwksintkey, :undefined),
     Map.get(original, :nwksenckey, :undefined), attrs.desc, attrs.location, attrs.fcntup,
     attrs.fcntdown, Map.get(original, :first_reset, now), Map.get(original, :last_reset, now),
     Map.get(original, :reset_count, 0), Map.get(original, :last_rx, :undefined),
     Map.get(original, :gateways, []), attrs.adr_flag, Map.get(original, :adr_set, :undefined),
     Map.get(original, :adr_use, {1, 0, [{0, 2}]}), Map.get(original, :adr_failed, []),
     Map.get(original, :dcycle_use, 0), Map.get(original, :rxwin_use, {0, 0, 869.525}),
     Map.get(original, :rxwin_failed, []), Map.get(original, :last_qs, []),
     Map.get(original, :average_qs, :undefined), Map.get(original, :devstat_time, :undefined),
     Map.get(original, :devstat_fcnt, :undefined), Map.get(original, :devstat, []),
     Map.get(original, :health_alerts, []), Map.get(original, :health_decay, 0),
     Map.get(original, :health_reported, 0), Map.get(original, :health_next, :undefined)}
  end

  defp ignored_node_record(attrs), do: {:ignored_node, attrs.devaddr, attrs.mask}

  defp group_from_record(record) do
    record
    |> tuple_map(@group_fields)
    |> stringify_map([:name, :network, :slack_channel])
    |> Map.update!(:can_join, &(&1 == true))
  end

  defp profile_from_record(record),
    do: record |> tuple_map(@profile_fields) |> stringify_map([:name, :group, :app, :appid])

  defp device_from_record(record) do
    record
    |> tuple_map(@device_fields)
    |> hex_map([:deveui, :appeui, :appkey, :nwkkey, :node])
    |> stringify_map([:profile, :appargs, :desc])
    |> Map.update!(:last_joins, fn joins -> if is_list(joins), do: joins, else: [] end)
  end

  defp node_from_record(record) do
    record
    |> tuple_map(@node_fields)
    |> hex_map([:devaddr, :nwkskey, :appskey])
    |> stringify_map([:profile, :appargs, :desc, :location])
    |> Map.update!(:last_rx, &format_datetime/1)
    |> Map.update!(:health_alerts, &health_alerts/1)
  end

  defp ignored_node_from_record({:ignored_node, devaddr, mask}) do
    %{devaddr: binary_to_hex(devaddr), mask: binary_to_hex(mask)}
  end

  defp tuple_map(record, fields) do
    values = record |> Tuple.to_list() |> tl()
    fields |> Enum.zip(values) |> Map.new()
  end

  defp hex_map(map, keys) do
    Enum.reduce(keys, map, fn key, acc -> Map.update(acc, key, "", &binary_to_hex/1) end)
  end

  defp stringify_map(map, keys) do
    Enum.reduce(keys, map, fn key, acc -> Map.update(acc, key, "", &optional_to_string/1) end)
  end

  defp required(errors, field, value),
    do: if(value in [nil, ""], do: Map.put(errors, field, "is required"), else: errors)

  defp parse_hex(nil, field, _size), do: {:error, %{field => "is required"}}

  defp parse_hex(value, field, size) do
    value = value |> to_string() |> String.trim() |> String.upcase()

    if String.match?(value, ~r/\A[0-9A-F]{#{size}}\z/) do
      {:ok, :bumblebee_utils.hex_to_binary(value)}
    else
      {:error, %{field => "must be #{size} hexadecimal characters"}}
    end
  end

  defp parse_optional_hex(value, _field, _size) when value in [nil, ""], do: {:ok, :undefined}
  defp parse_optional_hex(value, field, size), do: parse_hex(value, field, size)

  defp parse_integer(value, field) do
    case Integer.parse(to_string(value || "")) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, %{field => "must be an integer"}}
    end
  end

  defp parse_optional_integer(value, _field) when value in [nil, ""], do: {:ok, :undefined}
  defp parse_optional_integer(value, field), do: parse_integer(value, field)

  defp parse_optional_float(value, _field) when value in [nil, ""], do: {:ok, :undefined}

  defp parse_optional_float(value, field) do
    case Float.parse(to_string(value || "")) do
      {float, ""} -> {:ok, float}
      _ -> {:error, %{field => "must be a number"}}
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

  defp normalize_list(values) do
    values
    |> List.wrap()
    |> Enum.map(&normalize_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp truthy?(value), do: value in [true, "true", "on", "1", 1]

  defp optional_to_string(value) when value in [nil, :undefined], do: ""
  defp optional_to_string(value) when is_binary(value), do: to_string(value)
  defp optional_to_string(value), do: to_string(value)

  defp binary_to_hex(value) when value in [nil, :undefined], do: ""
  defp binary_to_hex(value) when is_binary(value), do: :bumblebee_utils.binary_to_hex(value)
  defp binary_to_hex(value), do: to_string(value)

  defp health_alerts(alerts) when is_list(alerts), do: Enum.map(alerts, &to_string/1)
  defp health_alerts(_alerts), do: []

  defp format_datetime(value) when value in [nil, :undefined], do: ""

  defp format_datetime({{year, month, day}, {hour, minute, second}}) do
    "#{pad(year, 4)}-#{pad(month, 2)}-#{pad(day, 2)} #{pad(hour, 2)}:#{pad(minute, 2)}:#{pad(second, 2)}"
  end

  defp format_datetime(value), do: to_string(value)

  defp pad(value, count), do: value |> Integer.to_string() |> String.pad_leading(count, "0")
end
