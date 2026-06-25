defmodule BumblebeeLns.Dashboard do
  @moduledoc """
  Read models for the admin dashboard.
  """

  require Record

  Record.defrecordp(
    :event,
    Record.extract(:event, from_lib: "bumblebee_lns/include/bumblebee.hrl")
  )

  Record.defrecordp(
    :server,
    Record.extract(:server, from_lib: "bumblebee_lns/include/bumblebee.hrl")
  )

  Record.defrecordp(
    :rxframe,
    Record.extract(:rxframe, from_lib: "bumblebee_lns/include/bumblebee_db.hrl")
  )

  @event_limit 7
  @frame_limit 7

  def summary do
    %{
      servers: list_servers(),
      events: list_recent_events(),
      frames: list_recent_frames(),
      timeline_items: list_timeline_items()
    }
  end

  def list_servers do
    :server
    |> table_keys()
    |> Kernel.++(schema_nodes())
    |> Enum.uniq()
    |> Enum.map(&server_summary/1)
    |> Enum.map(&normalize_server/1)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def list_recent_events(limit \\ @event_limit) do
    :event
    |> table_records()
    |> Enum.map(&normalize_event/1)
    |> Enum.sort_by(&datetime_sort_value(&1.last_rx), :desc)
    |> Enum.take(limit)
  end

  def list_recent_frames(limit \\ @frame_limit) do
    :rxframe
    |> table_records()
    |> Enum.map(&normalize_frame/1)
    |> Enum.sort_by(&datetime_sort_value(&1.datetime), :desc)
    |> Enum.take(limit)
  end

  def list_timeline_items do
    events =
      :event
      |> table_records()
      |> Enum.map(&normalize_event/1)
      |> Enum.map(fn event ->
        %{
          id: event.id,
          kind: :event,
          severity: event.severity,
          label: event.text,
          detail: event.args,
          started_at: event.first_rx,
          ended_at: event.last_rx
        }
      end)

    frames =
      :rxframe
      |> table_records()
      |> Enum.map(&normalize_frame/1)
      |> Enum.map(fn frame ->
        %{
          id: frame.id,
          kind: :frame,
          severity: frame.direction,
          label: frame.device,
          detail: frame.port,
          started_at: frame.datetime,
          ended_at: frame.datetime
        }
      end)

    (events ++ frames)
    |> Enum.sort_by(&datetime_sort_value(&1.started_at), :desc)
    |> Enum.take(24)
    |> Enum.reverse()
  end

  defp table_keys(table) do
    :mnesia.dirty_all_keys(table)
  catch
    :exit, _ -> []
  end

  defp schema_nodes do
    :mnesia.table_info(:schema, :disc_copies)
  catch
    :exit, _ -> []
  end

  defp table_records(table) do
    table
    |> table_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(table, key) do
        records when is_list(records) -> records
        _ -> []
      end
    end)
  end

  defp server_summary(node_name) do
    cond do
      node_name == node() ->
        :bumblebee_admin_servers.get_server()

      node_name in Node.list([:this, :connected]) ->
        :rpc.call(node_name, :bumblebee_admin_servers, :get_server, [])

      true ->
        %{
          sname: node_name,
          router_perf: node_name |> load_server() |> server(:router_perf),
          health_alerts: ["disconnected"],
          health_decay: 100
        }
    end
  end

  defp load_server(node_name) do
    case :mnesia.dirty_read(:server, node_name) do
      [record] -> record
      [] -> server(sname: node_name, router_perf: [])
    end
  end

  defp normalize_server(server) when is_map(server) do
    memory = Map.get(server, :memory, [])
    disks = Map.get(server, :disk, [])
    modules = Map.get(server, :modules, [])
    alerts = Map.get(server, :health_alerts, [])
    decay = Map.get(server, :health_decay)

    %{
      name: server |> Map.get(:sname) |> value_to_string(),
      version: module_version(modules, :bumblebee),
      memory: format_memory(memory),
      disk: format_disk(disks),
      status: server_status(decay, alerts)
    }
  end

  defp normalize_event(record) do
    %{
      id: record |> event(:evid) |> hex_or_string(),
      severity: record |> event(:severity) |> value_to_string(),
      first_rx: event(record, :first_rx),
      last_rx: event(record, :last_rx),
      count: event(record, :count),
      entity: record |> event(:entity) |> value_to_string(),
      eid: record |> event(:eid) |> hex_or_string(),
      text: record |> event(:text) |> value_to_string(),
      args: record |> event(:args) |> value_to_string()
    }
  end

  defp normalize_frame(record) do
    %{
      id: record |> rxframe(:frid) |> hex_or_string(),
      direction: record |> rxframe(:dir) |> value_to_string(),
      network: record |> rxframe(:network) |> value_to_string(),
      app: record |> rxframe(:app) |> value_to_string(),
      device: record |> rxframe(:devaddr) |> hex_or_string(),
      port: record |> rxframe(:port) |> value_to_string(),
      bytes: record |> rxframe(:data) |> byte_count(),
      datetime: rxframe(record, :datetime)
    }
  end

  defp module_version(modules, name) do
    Enum.find_value(modules, "-", fn
      {^name, version} ->
        value_to_string(version)

      {app, version} when is_binary(app) ->
        if app == to_string(name), do: value_to_string(version)

      _ ->
        nil
    end)
  end

  defp format_memory(memory) do
    free =
      numeric_value(memory, :free_memory) + numeric_value(memory, :buffered_memory) +
        numeric_value(memory, :cached_memory)

    total = numeric_value(memory, :total_memory)

    cond do
      total > 0 ->
        percent = free / total * 100
        "#{format_bytes(free)} (#{round(percent)}%)"

      free > 0 ->
        format_bytes(free)

      true ->
        "-"
    end
  end

  defp format_disk([]), do: "-"

  defp format_disk(disks) when is_list(disks) do
    disk =
      Enum.find(disks, fn disk -> value_from(disk, :id) == "/" end) ||
        List.first(disks)

    size_kb = numeric_value(disk, :size_kb)
    percent_used = numeric_value(disk, :percent_used)

    if size_kb > 0 and percent_used >= 0 do
      free_percent = max(0, min(100, 100 - percent_used))
      free_bytes = size_kb * 1024 * (free_percent / 100)
      "#{format_bytes(free_bytes)} (#{round(free_percent)}%)"
    else
      "-"
    end
  end

  defp server_status(decay, alerts) do
    decay = to_number(decay)
    alerts = if is_list(alerts), do: alerts, else: []

    cond do
      decay > 50 ->
        %{label: "Critical", class: "badge-error", icon: "hero-x-circle"}

      decay > 0 or alerts != [] ->
        %{label: "Warning", class: "badge-warning", icon: "hero-exclamation-triangle"}

      true ->
        %{label: "Online", class: "badge-success", icon: "hero-check-circle"}
    end
  end

  defp numeric_value(source, key), do: source |> value_from(key) |> to_number()

  defp value_from(source, key) when is_map(source),
    do: Map.get(source, key, Map.get(source, to_string(key)))

  defp value_from(source, key) when is_list(source), do: Keyword.get(source, key)
  defp value_from(_, _), do: nil

  defp to_number(value) when is_integer(value) or is_float(value), do: value

  defp to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end

  defp to_number(_), do: 0

  defp format_bytes(value) when value <= 0, do: "0 Bytes"

  defp format_bytes(value) do
    units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
    exponent = min(length(units) - 1, floor(:math.log(value) / :math.log(1024)))
    scaled = value / :math.pow(1024, exponent)
    rounded = if scaled >= 10, do: round(scaled), else: Float.round(scaled, 1)
    "#{rounded} #{Enum.at(units, exponent)}"
  end

  defp byte_count(value) when is_binary(value), do: byte_size(value)
  defp byte_count(_), do: 0

  defp datetime_sort_value({date, time}) when is_tuple(date) and is_tuple(time),
    do: :calendar.datetime_to_gregorian_seconds({date, time})

  defp datetime_sort_value(_), do: 0

  def format_datetime({date, time}) when is_tuple(date) and is_tuple(time) do
    {date, time}
    |> NaiveDateTime.from_erl!()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  def format_datetime(_), do: "-"

  def format_timeline_time(datetime) do
    datetime
    |> format_datetime()
    |> String.slice(11, 5)
  end

  defp hex_or_string(:undefined), do: "-"
  defp hex_or_string(nil), do: "-"

  defp hex_or_string(value) when is_binary(value),
    do: value |> :bumblebee_utils.binary_to_hex() |> value_to_string()

  defp hex_or_string(value), do: value_to_string(value)

  defp value_to_string(:undefined), do: "-"
  defp value_to_string(nil), do: "-"
  defp value_to_string(value) when is_binary(value), do: to_string(value)
  defp value_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp value_to_string(value) when is_list(value), do: inspect(value)
  defp value_to_string(value), do: to_string(value)
end
