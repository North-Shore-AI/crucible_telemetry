defmodule CrucibleTelemetry.StreamingMetrics do
  @moduledoc """
  Real-time streaming metrics with online statistical algorithms.

  Maintains rolling statistics without storing all events in memory.
  Uses efficient online algorithms for mean, variance, min, max, and counts.

  ## Features

  - **Online Statistics**: Incremental mean, variance, min, max
  - **Low Memory**: O(1) space complexity for basic metrics
  - **Real-time Updates**: Metrics available immediately after each event
  - **Thread-safe**: Uses GenServer for concurrent access

  ## Example

      # Start streaming metrics for an experiment
      {:ok, _pid} = CrucibleTelemetry.StreamingMetrics.start(experiment_id)

      # Metrics update automatically as events are inserted
      metrics = CrucibleTelemetry.StreamingMetrics.get_metrics(experiment_id)

      # Stop when done
      CrucibleTelemetry.StreamingMetrics.stop(experiment_id)
  """

  use GenServer

  alias CrucibleTelemetry.Experiment

  @type state :: %{
          experiment_id: String.t(),
          latency: streaming_stat(),
          cost: streaming_stat(),
          reliability: reliability_stat(),
          event_counts: map()
        }

  @type streaming_stat :: %{
          count: non_neg_integer(),
          sum: float(),
          sum_squares: float(),
          mean: float(),
          variance: float(),
          std_dev: float(),
          min: float() | nil,
          max: float() | nil
        }

  @type reliability_stat :: %{
          total_requests: non_neg_integer(),
          successful: non_neg_integer(),
          failed: non_neg_integer(),
          success_rate: float()
        }

  ## Client API

  @doc """
  Start streaming metrics collection for an experiment.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start(String.t()) :: {:ok, pid()} | {:error, term()}
  def start(experiment_id) do
    case Process.whereis(via_tuple(experiment_id)) do
      nil -> do_start(experiment_id)
      pid -> {:ok, pid}
    end
  end

  defp do_start(experiment_id) do
    # Verify experiment exists
    case Experiment.get(experiment_id) do
      {:ok, _experiment} ->
        GenServer.start(__MODULE__, experiment_id, name: via_tuple(experiment_id))

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get current streaming metrics for an experiment.

  Returns a map with real-time metrics calculated from observed events.
  """
  @spec get_metrics(String.t()) :: map()
  def get_metrics(experiment_id) do
    with {:ok, _pid} <- ensure_server(experiment_id) do
      GenServer.call(via_tuple(experiment_id), :get_metrics)
    end
  end

  @doc """
  Update streaming metrics with a new event.

  This is called automatically by the event handler for experiments
  with streaming metrics enabled.
  """
  @spec update(String.t(), map()) :: :ok
  def update(experiment_id, event) do
    GenServer.cast(via_tuple(experiment_id), {:update, event})
  end

  @doc """
  Reset streaming metrics to initial state.

  Useful for clearing metrics without stopping the GenServer.
  """
  @spec reset(String.t()) :: :ok
  def reset(experiment_id) do
    with {:ok, _pid} <- ensure_server(experiment_id) do
      GenServer.call(via_tuple(experiment_id), :reset)
    end
  end

  @doc """
  Stop streaming metrics collection for an experiment.
  """
  @spec stop(String.t()) :: :ok
  def stop(experiment_id) do
    case Process.whereis(via_tuple(experiment_id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  ## Server Callbacks

  @impl true
  def init(experiment_id) do
    state = %{
      experiment_id: experiment_id,
      latency: init_streaming_stat(),
      cost: init_streaming_stat(),
      reliability: init_reliability_stat(),
      event_counts: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      latency: finalize_streaming_stat(state.latency),
      cost: finalize_cost_stat(state.cost),
      reliability: finalize_reliability_stat(state.reliability),
      event_counts: state.event_counts
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | latency: init_streaming_stat(),
        cost: init_streaming_stat(),
        reliability: init_reliability_stat(),
        event_counts: %{}
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:update, event}, state) do
    new_state =
      state
      |> update_latency_stat(event)
      |> update_cost_stat(event)
      |> update_reliability_stat(event)
      |> update_event_counts(event)

    {:noreply, new_state}
  end

  ## Private Functions

  defp via_tuple(experiment_id) do
    :"streaming_metrics_#{experiment_id}"
  end

  defp init_streaming_stat do
    %{
      count: 0,
      sum: 0.0,
      sum_squares: 0.0,
      mean: 0.0,
      variance: 0.0,
      std_dev: 0.0,
      min: nil,
      max: nil
    }
  end

  defp init_reliability_stat do
    %{
      total_requests: 0,
      successful: 0,
      failed: 0,
      success_rate: 0.0
    }
  end

  defp ensure_server(experiment_id) do
    case Process.whereis(via_tuple(experiment_id)) do
      nil -> start(experiment_id)
      pid -> {:ok, pid}
    end
  end

  # Online algorithm for updating streaming statistics (Welford's method)
  defp update_streaming_stat(stat, value) when is_number(value) do
    new_count = stat.count + 1
    delta = value - stat.mean
    new_mean = stat.mean + delta / new_count
    delta2 = value - new_mean
    new_sum_squares = stat.sum_squares + delta * delta2

    %{
      count: new_count,
      sum: stat.sum + value,
      sum_squares: new_sum_squares,
      mean: new_mean,
      variance: if(new_count > 1, do: new_sum_squares / (new_count - 1), else: 0.0),
      std_dev: if(new_count > 1, do: :math.sqrt(new_sum_squares / (new_count - 1)), else: 0.0),
      min: if(stat.min == nil, do: value, else: min(stat.min, value)),
      max: if(stat.max == nil, do: value, else: max(stat.max, value))
    }
  end

  defp update_latency_stat(state, %{latency_ms: latency}) when is_number(latency) do
    %{state | latency: update_streaming_stat(state.latency, latency)}
  end

  defp update_latency_stat(state, _event), do: state

  defp update_cost_stat(state, %{cost_usd: cost}) when is_number(cost) do
    %{state | cost: update_streaming_stat(state.cost, cost)}
  end

  defp update_cost_stat(state, _event), do: state

  defp update_reliability_stat(state, %{success: success}) when is_boolean(success) do
    rel = state.reliability
    new_total = rel.total_requests + 1
    new_successful = if success, do: rel.successful + 1, else: rel.successful
    new_failed = if success, do: rel.failed, else: rel.failed + 1
    new_success_rate = new_successful / new_total

    new_rel = %{
      total_requests: new_total,
      successful: new_successful,
      failed: new_failed,
      success_rate: new_success_rate
    }

    %{state | reliability: new_rel}
  end

  defp update_reliability_stat(state, _event), do: state

  defp update_event_counts(state, %{event_name: event_name}) do
    event_key = format_event_name(event_name)
    new_counts = Map.update(state.event_counts, event_key, 1, &(&1 + 1))
    %{state | event_counts: new_counts}
  end

  defp update_event_counts(state, _event), do: state

  defp format_event_name(event_name) when is_list(event_name) do
    Enum.join(event_name, ".")
  end

  defp format_event_name(event_name), do: to_string(event_name)

  defp finalize_streaming_stat(stat) do
    if stat.count == 0 do
      %{count: 0}
    else
      Map.take(stat, [:count, :mean, :std_dev, :min, :max])
    end
  end

  defp finalize_cost_stat(stat) do
    if stat.count == 0 do
      %{count: 0, total: 0.0}
    else
      %{
        count: stat.count,
        total: stat.sum,
        mean_per_request: stat.mean,
        cost_per_1k_requests: stat.mean * 1000,
        cost_per_1m_requests: stat.mean * 1_000_000
      }
    end
  end

  defp finalize_reliability_stat(rel) do
    if rel.total_requests == 0 do
      %{total_requests: 0, successful: 0, failed: 0, success_rate: nil}
    else
      Map.merge(rel, %{
        sla_99: rel.success_rate >= 0.99,
        sla_999: rel.success_rate >= 0.999,
        sla_9999: rel.success_rate >= 0.9999
      })
    end
  end
end
