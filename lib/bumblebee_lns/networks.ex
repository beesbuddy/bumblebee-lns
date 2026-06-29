defmodule BumblebeeLns.Networks do
  @moduledoc """
  Reads and updates LoRaWAN network records stored in Mnesia.
  """

  @network_fields [
    :name,
    :netid,
    :region,
    :tx_codr,
    :join1_delay,
    :join2_delay,
    :rx1_delay,
    :rx2_delay,
    :gw_power,
    :max_eirp,
    :max_power,
    :min_power,
    :max_datr,
    :dcycle_init,
    :rxwin_init,
    :init_chans,
    :cflist
  ]

  def coding_rate_options, do: [{"4/5", "4/5"}, {"4/6", "4/6"}, {"4/7", "4/7"}, {"4/8", "4/8"}]

  def power_options do
    Enum.map(0..10, fn
      0 -> {"Max", 0}
      value -> {"Max - #{value * 2} dB", value}
    end)
  end

  def duty_cycle_options do
    [
      {"1 (100%)", 0},
      {"1/2 (50%)", 1},
      {"1/4 (25%)", 2},
      {"1/8 (12.5%)", 3},
      {"1/16 (6.25%)", 4},
      {"1/32 (3.125%)", 5},
      {"1/64 (1.563%)", 6},
      {"1/128 (0.781%)", 7},
      {"1/256 (0.391%)", 8},
      {"1/512 (0.195%)", 9},
      {"1/1024 (0.098%)", 10},
      {"1/2048 (0.049%)", 11},
      {"1/4096 (0.024%)", 12},
      {"1/8192 (0.012%)", 13},
      {"1/16384 (0.006%)", 14},
      {"1/32768 (0.003%)", 15}
    ]
  end

  def list_networks do
    :network
    |> :mnesia.dirty_all_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(:network, key) do
        [record] -> [from_record(record)]
        [] -> []
      end
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def get_network(name) when is_binary(name) do
    case :mnesia.dirty_read(:network, name) do
      [record] -> {:ok, from_record(record)}
      [] -> {:error, :not_found}
    end
  end

  def create_network(params) when is_map(params) do
    with {:ok, attrs} <- validate(params),
         :ok <- ensure_missing(attrs.name) do
      record = network_record(attrs)

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save network: #{inspect(reason)}"}}
      end
    end
  end

  def update_network(name, params) when is_binary(name) and is_map(params) do
    with {:ok, _network} <- get_network(name),
         {:ok, attrs} <- validate(Map.put(params, "name", name)) do
      record = network_record(Map.put(attrs, :name, name))

      case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
        {:atomic, :ok} -> {:ok, from_record(record)}
        {:aborted, reason} -> {:error, %{base: "Could not save network: #{inspect(reason)}"}}
      end
    end
  end

  def delete_network(name) when is_binary(name) do
    with {:ok, network} <- get_network(name) do
      :mnesia.dirty_delete(:network, name)
      {:ok, network}
    end
  end

  def parse_intervals(value) do
    value = value |> to_string() |> String.trim()

    if value == "" do
      {:error, "is required"}
    else
      value
      |> String.split([",", ";"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reduce_while({:ok, []}, fn text, {:ok, intervals} ->
        case parse_interval(text) do
          {:ok, interval} -> {:cont, {:ok, [interval | intervals]}}
          {:error, message} -> {:halt, {:error, message}}
        end
      end)
      |> case do
        {:ok, intervals} -> {:ok, Enum.reverse(intervals)}
        {:error, message} -> {:error, message}
      end
    end
  end

  def parse_cflist(value) do
    value = value |> to_string() |> String.trim()

    if value == "" do
      {:ok, []}
    else
      value
      |> String.split(["\n", ";"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reduce_while({:ok, []}, fn line, {:ok, channels} ->
        case parse_cflist_line(line) do
          {:ok, channel} -> {:cont, {:ok, [channel | channels]}}
          {:error, message} -> {:halt, {:error, message}}
        end
      end)
      |> case do
        {:ok, channels} -> {:ok, Enum.reverse(channels)}
        {:error, message} -> {:error, message}
      end
    end
  end

  defp validate(params) do
    with {:ok, netid} <- parse_hex(Map.get(params, "netid"), :netid, 6),
         {:ok, init_chans} <- parse_intervals(Map.get(params, "init_chans")),
         {:ok, cflist} <- parse_cflist(Map.get(params, "cflist")) do
      {:ok,
       %{
         name: string_param(params, "name"),
         netid: netid,
         region: string_param(params, "region"),
         tx_codr: string_param(params, "tx_codr"),
         join1_delay: Map.get(params, "join1_delay"),
         join2_delay: Map.get(params, "join2_delay"),
         rx1_delay: Map.get(params, "rx1_delay"),
         rx2_delay: Map.get(params, "rx2_delay"),
         gw_power: Map.get(params, "gw_power"),
         max_eirp: Map.get(params, "max_eirp"),
         max_power: Map.get(params, "max_power"),
         min_power: Map.get(params, "min_power"),
         max_datr: Map.get(params, "max_datr"),
         dcycle_init: Map.get(params, "dcycle_init"),
         rx1_dr_offset: Map.get(params, "rx1_dr_offset"),
         rx2_dr: Map.get(params, "rx2_dr"),
         rx2_freq: Map.get(params, "rx2_freq"),
         init_chans: init_chans,
         cflist: cflist
       }}
    else
      {:error, {field, message}} -> {:error, %{field => message}}
      {:error, message} -> {:error, %{base: message}}
    end
  end

  defp network_record(attrs) do
    {:network, attrs.name, attrs.netid, attrs.region, attrs.tx_codr, attrs.join1_delay,
     attrs.join2_delay, attrs.rx1_delay, attrs.rx2_delay, attrs.gw_power, attrs.max_eirp,
     attrs.max_power, attrs.min_power, attrs.max_datr, attrs.dcycle_init,
     {attrs.rx1_dr_offset, attrs.rx2_dr, attrs.rx2_freq}, attrs.init_chans, attrs.cflist}
  end

  defp from_record(record) do
    record
    |> tuple_map()
    |> Map.update!(:name, &to_string/1)
    |> Map.update!(:netid, &:bumblebee_utils.binary_to_hex/1)
    |> Map.update!(:region, &to_string/1)
    |> Map.update!(:tx_codr, &to_string/1)
    |> Map.update!(:init_chans, &intervals_to_text/1)
    |> Map.update!(:cflist, &cflist_to_text/1)
    |> flatten_rxwin()
  end

  defp tuple_map(record) do
    values = record |> Tuple.to_list() |> tl()
    @network_fields |> Enum.zip(values) |> Map.new()
  end

  defp flatten_rxwin(%{rxwin_init: {rx1_dr_offset, rx2_dr, rx2_freq}} = network) do
    network
    |> Map.delete(:rxwin_init)
    |> Map.put(:rx1_dr_offset, rx1_dr_offset)
    |> Map.put(:rx2_dr, rx2_dr)
    |> Map.put(:rx2_freq, rx2_freq)
  end

  defp flatten_rxwin(network) do
    network
    |> Map.delete(:rxwin_init)
    |> Map.put(:rx1_dr_offset, nil)
    |> Map.put(:rx2_dr, nil)
    |> Map.put(:rx2_freq, nil)
  end

  defp ensure_missing(name) do
    case :mnesia.dirty_read(:network, name) do
      [] -> :ok
      [_] -> {:error, %{name: "Network already exists"}}
    end
  end

  defp parse_hex(nil, field, _size), do: {:error, {field, "is required"}}

  defp parse_hex(value, field, size) do
    value = value |> to_string() |> String.trim() |> String.upcase()

    if String.match?(value, ~r/\A[0-9A-F]{#{size}}\z/) do
      {:ok, :bumblebee_utils.hex_to_binary(value)}
    else
      {:error, {field, "must be #{size} hexadecimal characters"}}
    end
  end

  defp parse_interval(text) do
    case text |> String.replace(" ", "") |> String.split("-", parts: 2) do
      [from] -> parse_interval_bounds(from, from)
      [from, to] -> parse_interval_bounds(from, to)
    end
  end

  defp parse_interval_bounds(from, to) do
    with {from, ""} <- Integer.parse(from),
         {to, ""} <- Integer.parse(to),
         true <- from <= to do
      {:ok, {from, to}}
    else
      _ -> {:error, "must be channel intervals like 0-2, 5-7"}
    end
  end

  defp parse_cflist_line(line) do
    case String.split(line, [",", " "], trim: true) do
      [freq, min_datr, max_datr] ->
        parse_cflist_values(freq, min_datr, max_datr)

      _other ->
        {:error,
         "must use one CFList channel per line as: frequency, min data rate, max data rate"}
    end
  end

  defp parse_cflist_values(freq, min_datr, max_datr) do
    with {freq, ""} <- Float.parse(freq),
         {min_datr, ""} <- Integer.parse(min_datr),
         {max_datr, ""} <- Integer.parse(max_datr) do
      {:ok, {freq, min_datr, max_datr}}
    else
      _ -> {:error, "must use numeric CFList values"}
    end
  end

  defp intervals_to_text(intervals) when is_list(intervals) do
    intervals
    |> Enum.map(fn
      {value, value} -> Integer.to_string(value)
      {from, to} -> "#{from}-#{to}"
    end)
    |> Enum.join(", ")
  end

  defp intervals_to_text(_value), do: "0-2"

  defp cflist_to_text(value) when value in [nil, :undefined], do: ""

  defp cflist_to_text(channels) when is_list(channels) do
    channels
    |> Enum.map(fn
      {freq, min_datr, max_datr} -> "#{freq}, #{min_datr}, #{max_datr}"
      freq -> to_string(freq)
    end)
    |> Enum.join("\n")
  end

  defp cflist_to_text(value), do: to_string(value)

  defp string_param(params, key), do: params |> Map.get(key, "") |> to_string() |> String.trim()
end
