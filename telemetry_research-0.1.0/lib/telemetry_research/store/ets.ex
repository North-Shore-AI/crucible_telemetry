defmodule TelemetryResearch.Store.ETS do
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

  @behaviour TelemetryResearch.Store

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
end
