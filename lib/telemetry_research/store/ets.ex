defmodule CrucibleTelemetry.Store.ETS do
  @moduledoc """
  Fast in-memory storage for real-time experiments using ETS.

  ## Advantages

  - Zero latency writes
  - No serialization overhead
  - Perfect for short experiments (<1M events)
  - Simple setup, no external dependencies

  ## Limitations

  - Limited by available memory
  - Lost on node restart
  - No distributed queries
  """

  @behaviour CrucibleTelemetry.Store

  @impl true
  def init_experiment(experiment) do
    table_name = table_name(experiment.id)

    :ets.new(table_name, [
      :named_table,
      :ordered_set,
      # Time-series optimized
      :public,
      {:write_concurrency, true},
      {:read_concurrency, true}
    ])

    :ok
  end

  @impl true
  def insert(experiment_id, event) do
    table = table_name(experiment_id)

    # Use timestamp as key for ordered storage
    # Include event_id to handle multiple events with same timestamp
    key = {event.timestamp, event.event_id}

    :ets.insert(table, {key, event})

    :ok
  rescue
    ArgumentError ->
      # Table doesn't exist - experiment may have been cleaned up
      {:error, :experiment_not_found}
  end

  @impl true
  def get_all(experiment_id) do
    table = table_name(experiment_id)

    :ets.tab2list(table)
    |> Enum.map(fn {_key, event} -> event end)
    |> Enum.sort_by(& &1.timestamp)
  rescue
    ArgumentError ->
      []
  end

  @impl true
  def query(experiment_id, filters) do
    get_all(experiment_id)
    |> apply_filters(filters)
  end

  @impl true
  def query_window(experiment_id, window_spec, opts_or_filter \\ nil) do
    table = table_name(experiment_id)

    # Handle both opts (for :now) and filter_fn
    {opts, filter_fn} = parse_query_window_args(opts_or_filter)

    events =
      case window_spec do
        {:last, n, unit} when n > 0 ->
          query_last_time_window(table, n, unit, opts)

        {:last_n, n} when n > 0 ->
          query_last_n_events(table, n)

        {:range, start_time, end_time} ->
          query_time_range(table, start_time, end_time)

        _ ->
          []
      end

    if filter_fn do
      Enum.filter(events, filter_fn)
    else
      events
    end
  rescue
    ArgumentError ->
      []
  end

  @impl true
  def windowed_metrics(experiment_id, window_size, step_size)
      when window_size > 0 and step_size > 0 do
    # Get all events ordered by time
    all_events = get_all(experiment_id)

    if Enum.empty?(all_events) do
      []
    else
      build_windowed_metrics(all_events, window_size, step_size)
    end
  rescue
    ArgumentError ->
      []
  end

  def windowed_metrics(_experiment_id, _window_size, _step_size), do: []

  @impl true
  def delete_experiment(experiment_id) do
    table = table_name(experiment_id)
    :ets.delete(table)
    :ok
  rescue
    ArgumentError ->
      :ok
  end

  # Private functions

  defp table_name(experiment_id) do
    :"telemetry_research_#{experiment_id}"
  end

  defp apply_filters(events, filters) when filters == %{} do
    events
  end

  defp apply_filters(events, filters) do
    Enum.filter(events, fn event ->
      Enum.all?(filters, fn {key, value} ->
        filter_matches?(event, key, value)
      end)
    end)
  end

  defp filter_matches?(event, :event_name, value) do
    event.event_name == value
  end

  defp filter_matches?(event, :success, value) do
    event.success == value
  end

  defp filter_matches?(event, :time_range, {start_time, end_time}) do
    event.timestamp >= start_time and event.timestamp <= end_time
  end

  defp filter_matches?(event, :condition, value) do
    event.condition == value
  end

  defp filter_matches?(event, key, value) do
    # Try metadata first, then top-level
    get_in(event.metadata, [key]) == value or Map.get(event, key) == value
  end

  # Time window query helpers

  defp parse_query_window_args(nil), do: {[], nil}
  defp parse_query_window_args(opts) when is_list(opts), do: {opts, nil}
  defp parse_query_window_args(filter_fn) when is_function(filter_fn), do: {[], filter_fn}

  defp query_last_time_window(table, n, unit, opts) do
    now = Keyword.get(opts, :now, System.system_time(:microsecond))
    duration_us = convert_to_microseconds(n, unit)
    start_time = now - duration_us

    query_time_range(table, start_time, now)
  end

  defp query_last_n_events(table, n) when n > 0 do
    last_key = :ets.last(table)

    last_key
    |> collect_prev(table, n, [])
  end

  defp query_last_n_events(_table, _n), do: []

  defp query_time_range(table, start_time, end_time) do
    match_spec = [
      {
        {{:"$1", :"$2"}, :"$3"},
        [
          {:>=, :"$1", start_time},
          {:"=<", :"$1", end_time}
        ],
        [:"$3"]
      }
    ]

    try do
      case :ets.select(table, match_spec) do
        [] -> []
        results -> Enum.sort_by(results, & &1.timestamp)
      end
    rescue
      ArgumentError ->
        # Fallback to linear scan if match spec fails (e.g., on unsupported OTP versions)
        :ets.tab2list(table)
        |> Enum.map(fn {_key, event} -> event end)
        |> Enum.filter(fn event ->
          event.timestamp >= start_time and event.timestamp <= end_time
        end)
        |> Enum.sort_by(& &1.timestamp)
    end
  end

  defp convert_to_microseconds(n, :seconds) when n > 0, do: n * 1_000_000
  defp convert_to_microseconds(n, :minutes) when n > 0, do: n * 60 * 1_000_000
  defp convert_to_microseconds(n, :hours) when n > 0, do: n * 60 * 60 * 1_000_000

  defp convert_to_microseconds(_n, unit),
    do: raise(ArgumentError, "unsupported or non-positive window unit #{inspect(unit)}")

  defp collect_prev(:"$end_of_table", _table, _remaining, acc), do: acc

  defp collect_prev(_key, _table, 0, acc), do: acc

  defp collect_prev(key, table, remaining, acc) do
    case :ets.lookup(table, key) do
      [{^key, event}] ->
        prev_key = :ets.prev(table, key)
        collect_prev(prev_key, table, remaining - 1, [event | acc])

      _ ->
        acc
    end
  end

  defp build_windowed_metrics(events, window_size, step_size) do
    first_time = hd(events).timestamp
    last_time = List.last(events).timestamp

    do_windowed_metrics(events, first_time, last_time, window_size, step_size, [])
    |> Enum.reverse()
  end

  defp do_windowed_metrics(_events, start_time, last_time, window_size, step_size, acc)
       when start_time + window_size > last_time + step_size,
       do: acc

  defp do_windowed_metrics(events, start_time, last_time, window_size, step_size, acc) do
    window_end = start_time + window_size

    # Drop events that are now out of range for future windows
    active_events = Enum.drop_while(events, &(&1.timestamp < start_time))
    {window_events, _rest} = Enum.split_while(active_events, &(&1.timestamp < window_end))

    metrics = calculate_window_metrics(start_time, window_end, window_events)

    next_start = start_time + step_size
    next_events = Enum.drop_while(active_events, &(&1.timestamp < next_start))

    new_acc = if metrics.event_count == 0, do: acc, else: [metrics | acc]

    do_windowed_metrics(next_events, next_start, last_time, window_size, step_size, new_acc)
  end

  defp calculate_window_metrics(window_start, window_end, events) do
    latencies = Enum.map(events, & &1.latency_ms) |> Enum.reject(&is_nil/1)
    costs = Enum.map(events, & &1.cost_usd) |> Enum.reject(&is_nil/1)

    %{
      window_start: window_start,
      window_end: window_end,
      event_count: length(events),
      mean_latency:
        if(Enum.empty?(latencies), do: nil, else: Enum.sum(latencies) / length(latencies)),
      total_cost: if(Enum.empty?(costs), do: 0.0, else: Enum.sum(costs)),
      success_count: Enum.count(events, &(&1.success == true)),
      failure_count: Enum.count(events, &(&1.success == false))
    }
  end
end
