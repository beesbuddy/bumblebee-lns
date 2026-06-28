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
  @chart_width 960
  @chart_height 340
  @chart_padding_left 56
  @chart_padding_right 24
  @chart_padding_top 24
  @chart_padding_bottom 76
  @traffic_windows [
    {"15m", "15m", 15 * 60},
    {"1h", "1h", 60 * 60},
    {"6h", "6h", 6 * 60 * 60},
    {"24h", "24h", 24 * 60 * 60},
    {"7d", "7d", 7 * 24 * 60 * 60},
    {"all", "All", :all}
  ]

  def summary(window_or_key \\ "1h", window_offset \\ 0)

  def summary(%{} = window, _window_offset) do
    summary_for_window(window)
  end

  def summary(window_key, window_offset) do
    window_key
    |> traffic_window(window_offset)
    |> summary_for_window()
  end

  defp summary_for_window(window) do
    traffic_points = list_router_traffic_points(window)
    observability_items = list_observability_items(window)

    %{
      servers: list_servers(),
      events: list_recent_events(),
      frames: list_recent_frames(),
      traffic_windows: traffic_windows(),
      traffic_window: window,
      traffic_chart: router_traffic_chart(traffic_points, observability_items, window)
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
    list_observability_items(%{start_at: nil, end_at: nil})
    |> Enum.sort_by(&datetime_sort_value(&1.started_at), :desc)
    |> Enum.take(24)
    |> Enum.reverse()
  end

  def list_observability_items(window) do
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
    |> Enum.filter(&in_window?(&1.started_at, window))
    |> Enum.sort_by(&datetime_sort_value(&1.started_at))
  end

  def list_router_traffic_points(window \\ %{start_at: nil, end_at: nil}) do
    :server
    |> table_keys()
    |> Kernel.++(schema_nodes())
    |> Enum.uniq()
    |> Enum.flat_map(fn node_name ->
      node_name
      |> load_server()
      |> router_perf()
      |> Enum.map(&normalize_router_perf(node_name, &1))
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&in_window?(&1.datetime, window))
    |> Enum.sort_by(&datetime_sort_value(&1.datetime))
  end

  def router_traffic_chart(points, observability_items, window) do
    points = Enum.sort_by(points, &datetime_sort_value(&1.datetime))
    observability_items = Enum.sort_by(observability_items, &datetime_sort_value(&1.started_at))
    max_value = points |> Enum.flat_map(&[&1.requests, &1.errors]) |> Enum.max(fn -> 0 end)
    y_max = chart_y_max(max_value)
    {range_start, range_end} = chart_range(points, observability_items, window)

    plot_width = @chart_width - @chart_padding_left - @chart_padding_right
    plot_height = @chart_height - @chart_padding_top - @chart_padding_bottom

    positioned_points =
      Enum.map(points, fn point ->
        point
        |> Map.put(:x, chart_x(point.datetime, range_start, range_end, plot_width))
        |> Map.put(:requests_y, chart_y(point.requests, y_max, plot_height))
        |> Map.put(:errors_y, chart_y(point.errors, y_max, plot_height))
      end)

    positioned_items =
      Enum.map(observability_items, fn item ->
        item
        |> Map.put(:x, chart_x(item.started_at, range_start, range_end, plot_width))
        |> Map.put(:y, marker_y(item))
        |> Map.put(:class, marker_class(item))
        |> Map.put(:icon, marker_icon(item))
      end)

    %{
      has_data?: positioned_points != [] or positioned_items != [],
      width: @chart_width,
      height: @chart_height,
      window: window,
      plot: %{
        x: @chart_padding_left,
        y: @chart_padding_top,
        width: plot_width,
        height: plot_height,
        bottom: @chart_padding_top + plot_height,
        right: @chart_padding_left + plot_width
      },
      y_ticks: y_ticks(y_max, plot_height),
      x_ticks: x_ticks(range_start, range_end, plot_width),
      points: positioned_points,
      observability_items: positioned_items,
      requests_path: line_path(positioned_points, :requests_y),
      errors_path: line_path(positioned_points, :errors_y),
      latest: List.last(positioned_points),
      vega_lite_spec: router_traffic_vega_lite_spec(points, observability_items)
    }
  end

  def traffic_windows,
    do: Enum.map(@traffic_windows, fn {key, label, _duration} -> {key, label} end)

  def traffic_window(key, offset \\ 0) do
    {key, label, duration} =
      Enum.find(@traffic_windows, List.last(@traffic_windows), fn {candidate, _label, _duration} ->
        candidate == key
      end)

    case duration do
      :all ->
        %{key: key, label: label, offset: 0, duration: :all, start_at: nil, end_at: nil}

      seconds ->
        end_at = shift_datetime(:calendar.universal_time(), offset * seconds)
        start_at = shift_datetime(end_at, -seconds)

        %{
          key: key,
          label: label,
          offset: offset,
          duration: seconds,
          start_at: start_at,
          end_at: end_at
        }
    end
  end

  def shift_traffic_window(%{duration: duration} = window, seconds)
      when is_integer(duration) or is_float(duration) do
    %{
      window
      | start_at: shift_datetime(window.start_at, seconds),
        end_at: shift_datetime(window.end_at, seconds)
    }
  end

  def shift_traffic_window(window, _seconds), do: window

  def zoom_traffic_interval(%{duration: :all} = window, _start_ratio, _end_ratio, _mode),
    do: window

  def zoom_traffic_interval(
        %{start_at: start_at, end_at: end_at} = window,
        start_ratio,
        end_ratio,
        mode
      ) do
    range_start = datetime_sort_value(start_at)
    range_end = datetime_sort_value(end_at)
    duration = max(60, range_end - range_start)
    {selection_start, selection_end} = normalized_ratio_range(start_ratio, end_ratio)
    selection_width = max(0.02, selection_end - selection_start)
    selection_center = (selection_start + selection_end) / 2

    {new_start, new_end} =
      case mode do
        "out" ->
          new_duration = duration / selection_width
          center = range_start + duration * selection_center
          {center - new_duration / 2, center + new_duration / 2}

        _ ->
          {
            range_start + duration * selection_start,
            range_start + duration * selection_end
          }
      end

    custom_traffic_window(new_start, new_end, window.offset)
  end

  defp custom_traffic_window(start_seconds, end_seconds, offset) do
    now = datetime_sort_value(:calendar.universal_time())
    duration = max(60, round(end_seconds - start_seconds))
    end_seconds = min(now, round(end_seconds))
    start_seconds = end_seconds - duration

    %{
      key: "custom",
      label: "Custom",
      offset: offset,
      duration: duration,
      start_at: :calendar.gregorian_seconds_to_datetime(start_seconds),
      end_at: :calendar.gregorian_seconds_to_datetime(end_seconds)
    }
  end

  defp normalized_ratio_range(start_ratio, end_ratio) do
    start_ratio = clamp_ratio(start_ratio)
    end_ratio = clamp_ratio(end_ratio)
    {min(start_ratio, end_ratio), max(start_ratio, end_ratio)}
  end

  defp clamp_ratio(value) when is_integer(value) or is_float(value), do: max(0.0, min(1.0, value))
  defp clamp_ratio(_), do: 0.0

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

  defp router_perf(source) when is_map(source), do: Map.get(source, :router_perf, [])
  defp router_perf(source) when is_tuple(source), do: server(source, :router_perf)
  defp router_perf(_), do: []

  defp normalize_router_perf(server_name, {datetime, {requests, errors}})
       when is_tuple(datetime) do
    %{
      id: "#{value_to_string(server_name)}-#{datetime_sort_value(datetime)}",
      server: value_to_string(server_name),
      datetime: datetime,
      timestamp: datetime_to_iso8601(datetime),
      label: format_datetime(datetime),
      short_label: format_timeline_time(datetime),
      requests: round_numeric(requests),
      errors: round_numeric(errors)
    }
  end

  defp normalize_router_perf(_server_name, _point), do: nil

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

  defp chart_y_max(value) when value <= 0, do: 1
  defp chart_y_max(value), do: max(1, value)

  defp chart_range(_points, _items, %{start_at: start_at, end_at: end_at})
       when not is_nil(start_at) and not is_nil(end_at),
       do: {datetime_sort_value(start_at), datetime_sort_value(end_at)}

  defp chart_range(points, items, _window) do
    values =
      Enum.map(points, &datetime_sort_value(&1.datetime)) ++
        Enum.map(items, &datetime_sort_value(&1.started_at))

    case values do
      [] ->
        now = datetime_sort_value(:calendar.universal_time())
        {now - 60 * 60, now}

      values ->
        min_value = Enum.min(values)
        max_value = Enum.max(values)

        if min_value == max_value do
          {min_value - 60, max_value + 60}
        else
          {min_value, max_value}
        end
    end
  end

  defp chart_x(datetime, range_start, range_end, plot_width) do
    value = datetime_sort_value(datetime)
    duration = max(1, range_end - range_start)
    x = @chart_padding_left + plot_width * (value - range_start) / duration
    Float.round(x, 2)
  end

  defp chart_y(value, y_max, plot_height) do
    y = @chart_padding_top + plot_height - plot_height * value / y_max
    Float.round(y, 2)
  end

  defp y_ticks(y_max, plot_height) do
    0..4
    |> Enum.map(fn index ->
      value = y_max * index / 4

      %{
        value: round_numeric(value),
        y: chart_y(value, y_max, plot_height)
      }
    end)
  end

  defp x_ticks(range_start, range_end, plot_width) do
    [range_start, div(range_start + range_end, 2), range_end]
    |> Enum.uniq()
    |> Enum.map(fn value ->
      datetime = :calendar.gregorian_seconds_to_datetime(value)

      %{
        x: chart_x(datetime, range_start, range_end, plot_width),
        short_label: format_timeline_time(datetime),
        label: format_datetime(datetime)
      }
    end)
  end

  defp line_path([], _key), do: ""

  defp line_path(points, y_key) do
    points
    |> Enum.map(fn point -> "#{point.x},#{Map.fetch!(point, y_key)}" end)
    |> Enum.join(" ")
  end

  defp round_numeric(value) when is_integer(value), do: value
  defp round_numeric(value) when is_float(value), do: round(value)
  defp round_numeric(_), do: 0

  defp datetime_to_iso8601({date, time}) when is_tuple(date) and is_tuple(time) do
    {date, time}
    |> NaiveDateTime.from_erl!()
    |> NaiveDateTime.to_iso8601()
  end

  defp datetime_to_iso8601(_), do: nil

  defp in_window?(_datetime, %{start_at: nil, end_at: nil}), do: true

  defp in_window?(datetime, %{start_at: start_at, end_at: end_at}) do
    value = datetime_sort_value(datetime)
    value >= datetime_sort_value(start_at) and value <= datetime_sort_value(end_at)
  end

  defp shift_datetime(datetime, seconds) do
    datetime
    |> datetime_sort_value()
    |> Kernel.+(round(seconds))
    |> :calendar.gregorian_seconds_to_datetime()
  end

  defp marker_y(%{kind: :event}), do: @chart_height - 46
  defp marker_y(%{kind: :frame}), do: @chart_height - 22

  defp marker_class(%{kind: :frame}), do: "fill-info stroke-info"
  defp marker_class(%{severity: "error"}), do: "fill-error stroke-error"
  defp marker_class(%{severity: "warning"}), do: "fill-warning stroke-warning"
  defp marker_class(_), do: "fill-base-content/70 stroke-base-content/70"

  defp marker_icon(%{kind: :frame}), do: "Frame"
  defp marker_icon(%{severity: "error"}), do: "Error"
  defp marker_icon(%{severity: "warning"}), do: "Warning"
  defp marker_icon(_), do: "Event"

  defp router_traffic_vega_lite_spec(points, observability_items) do
    values =
      Enum.flat_map(points, fn point ->
        [
          %{
            server: point.server,
            timestamp: point.timestamp,
            metric: "Requests per min",
            value: point.requests
          },
          %{
            server: point.server,
            timestamp: point.timestamp,
            metric: "Errors per min",
            value: point.errors
          }
        ]
      end)

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "description" => "Router requests and errors per minute",
      "data" => %{"values" => values},
      "observability" => %{
        "values" =>
          Enum.map(observability_items, fn item ->
            %{
              id: item.id,
              timestamp: datetime_to_iso8601(item.started_at),
              kind: value_to_string(item.kind),
              severity: item.severity,
              label: item.label,
              detail: item.detail
            }
          end)
      },
      "mark" => %{"type" => "line", "point" => true, "interpolate" => "monotone"},
      "encoding" => %{
        "x" => %{"field" => "timestamp", "type" => "temporal", "title" => "Timestamp"},
        "y" => %{"field" => "value", "type" => "quantitative", "title" => "Per minute"},
        "color" => %{"field" => "metric", "type" => "nominal", "title" => nil},
        "tooltip" => [
          %{"field" => "timestamp", "type" => "temporal", "title" => "Timestamp"},
          %{"field" => "server", "type" => "nominal", "title" => "Server"},
          %{"field" => "metric", "type" => "nominal", "title" => "Metric"},
          %{"field" => "value", "type" => "quantitative", "title" => "Value"}
        ]
      }
    }
  end

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
