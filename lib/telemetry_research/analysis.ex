defmodule CrucibleTelemetry.Analysis do
  @moduledoc """
  Statistical analysis and metrics calculation for experiments.

  Provides comprehensive metrics across multiple dimensions:
  - Latency (mean, median, percentiles)
  - Cost (total, per-request, projections)
  - Reliability (success rate, failure analysis)
  - Tokens (usage patterns, efficiency)
  - Model performance comparisons
  """

  alias CrucibleTelemetry.Store

  @doc """
  Calculate all metrics for an experiment.

  Returns a comprehensive map of metrics organized by category.

  ## Examples

      metrics = CrucibleTelemetry.Analysis.calculate_metrics("exp-123")

      metrics.latency.mean      # Average latency in ms
      metrics.latency.p95       # 95th percentile
      metrics.cost.total        # Total cost in USD
      metrics.reliability.success_rate  # Success rate (0.0-1.0)
  """
  def calculate_metrics(experiment_id) do
    events = Store.get_all(experiment_id)

    %{
      summary: summary_metrics(events),
      latency: latency_metrics(events),
      cost: cost_metrics(events),
      reliability: reliability_metrics(events),
      tokens: token_metrics(events),
      events: event_type_metrics(events)
    }
  end

  @doc """
  Compare metrics between two or more experiments.

  Useful for A/B testing analysis.

  ## Examples

      comparison = CrucibleTelemetry.Analysis.compare_experiments([
        "exp-control",
        "exp-treatment"
      ])

      comparison.latency_improvement  # % improvement
      comparison.cost_difference      # USD difference
  """
  def compare_experiments(experiment_ids) do
    metrics_list =
      experiment_ids
      |> Enum.map(&calculate_metrics/1)

    %{
      experiments: experiment_ids,
      individual: metrics_list,
      comparison: calculate_comparison(metrics_list)
    }
  end

  # Metrics calculation functions

  defp summary_metrics(events) do
    %{
      total_events: length(events),
      time_range: time_range(events),
      duration_seconds: experiment_duration(events),
      event_types: count_event_types(events)
    }
  end

  defp latency_metrics(events) do
    latencies =
      events
      |> Enum.map(& &1.latency_ms)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(latencies) do
      %{count: 0}
    else
      sorted = Enum.sort(latencies)

      %{
        count: length(latencies),
        mean: mean(latencies),
        median: median(sorted),
        std_dev: std_dev(latencies),
        min: Enum.min(latencies),
        max: Enum.max(latencies),
        p50: percentile(sorted, 50),
        p90: percentile(sorted, 90),
        p95: percentile(sorted, 95),
        p99: percentile(sorted, 99)
      }
    end
  end

  defp cost_metrics(events) do
    costs =
      events
      |> Enum.map(& &1.cost_usd)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(costs) do
      %{count: 0, total: 0.0}
    else
      total = Enum.sum(costs)
      count = length(costs)

      %{
        total: total,
        count: count,
        mean_per_request: mean(costs),
        median_per_request: median(Enum.sort(costs)),
        cost_per_1k_requests: total / count * 1000,
        cost_per_1m_requests: total / count * 1_000_000
      }
    end
  end

  defp reliability_metrics(events) do
    total = length(events)

    success_events =
      events
      |> Enum.filter(&(&1.success != nil))

    if Enum.empty?(success_events) do
      %{total_requests: total, success_rate: nil}
    else
      successes = Enum.count(success_events, &(&1.success == true))
      failures = Enum.count(success_events, &(&1.success == false))

      success_rate = successes / length(success_events)

      %{
        total_requests: total,
        successful: successes,
        failed: failures,
        success_rate: success_rate,
        failure_rate: failures / length(success_events),
        # SLA compliance
        sla_99: success_rate >= 0.99,
        sla_999: success_rate >= 0.999,
        sla_9999: success_rate >= 0.9999
      }
    end
  end

  defp token_metrics(events) do
    token_events =
      events
      |> Enum.map(&get_in(&1.metadata, [:tokens]))
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(token_events) do
      %{count: 0}
    else
      prompt_tokens = Enum.map(token_events, &(&1[:prompt] || 0))
      completion_tokens = Enum.map(token_events, &(&1[:completion] || 0))
      total_tokens = Enum.map(token_events, &(&1[:total] || 0))

      %{
        count: length(token_events),
        total_prompt: Enum.sum(prompt_tokens),
        total_completion: Enum.sum(completion_tokens),
        total: Enum.sum(total_tokens),
        mean_prompt: mean(prompt_tokens),
        mean_completion: mean(completion_tokens),
        mean_total: mean(total_tokens)
      }
    end
  end

  defp event_type_metrics(events) do
    events
    |> Enum.group_by(& &1.event_name)
    |> Enum.map(fn {event_name, event_list} ->
      {format_event_name(event_name), %{count: length(event_list)}}
    end)
    |> Enum.into(%{})
  end

  # Helper functions

  defp time_range(events) when length(events) == 0 do
    %{start: nil, end: nil}
  end

  defp time_range(events) do
    timestamps = Enum.map(events, & &1.timestamp)

    %{
      start: Enum.min(timestamps),
      end: Enum.max(timestamps)
    }
  end

  defp experiment_duration(events) when length(events) < 2 do
    0
  end

  defp experiment_duration(events) do
    timestamps = Enum.map(events, & &1.timestamp)
    (Enum.max(timestamps) - Enum.min(timestamps)) / 1_000_000
  end

  defp count_event_types(events) do
    events
    |> Enum.map(& &1.event_name)
    |> Enum.frequencies()
    |> Enum.map(fn {event_name, count} -> {format_event_name(event_name), count} end)
    |> Enum.into(%{})
  end

  defp format_event_name(event_name) when is_list(event_name) do
    Enum.join(event_name, ".")
  end

  defp format_event_name(event_name), do: to_string(event_name)

  # Statistical functions

  defp mean([]), do: nil

  defp mean(values) do
    Enum.sum(values) / length(values)
  end

  defp median([]), do: nil

  defp median(sorted_values) do
    count = length(sorted_values)
    middle = div(count, 2)

    if rem(count, 2) == 0 do
      # Even number of elements - average the two middle values
      (Enum.at(sorted_values, middle - 1) + Enum.at(sorted_values, middle)) / 2
    else
      # Odd number of elements - take the middle value
      Enum.at(sorted_values, middle)
    end
  end

  defp percentile([], _p), do: nil

  defp percentile(sorted_values, p) when p >= 0 and p <= 100 do
    count = length(sorted_values)
    index = p / 100 * (count - 1)

    lower = floor(index)
    upper = ceil(index)

    if lower == upper do
      Enum.at(sorted_values, round(index))
    else
      # Linear interpolation
      lower_value = Enum.at(sorted_values, lower)
      upper_value = Enum.at(sorted_values, upper)
      fraction = index - lower
      lower_value + (upper_value - lower_value) * fraction
    end
  end

  defp std_dev([]), do: nil
  defp std_dev([_single]), do: 0.0

  defp std_dev(values) do
    avg = mean(values)
    variance = Enum.map(values, fn x -> :math.pow(x - avg, 2) end) |> mean()
    :math.sqrt(variance)
  end

  defp calculate_comparison(metrics_list) when length(metrics_list) < 2 do
    %{error: "Need at least 2 experiments to compare"}
  end

  defp calculate_comparison([baseline | treatments]) do
    treatments
    |> Enum.with_index()
    |> Enum.map(fn {treatment, index} ->
      {
        "treatment_#{index + 1}",
        compare_two_metrics(baseline, treatment)
      }
    end)
    |> Enum.into(%{})
  end

  defp compare_two_metrics(baseline, treatment) do
    %{
      latency_improvement_pct: percent_change(baseline.latency.mean, treatment.latency.mean),
      cost_difference_usd: (treatment.cost.total || 0) - (baseline.cost.total || 0),
      success_rate_improvement_pct:
        percent_change(baseline.reliability.success_rate, treatment.reliability.success_rate),
      event_count_difference: treatment.summary.total_events - baseline.summary.total_events
    }
  end

  defp percent_change(nil, _new), do: nil
  defp percent_change(_old, nil), do: nil
  defp percent_change(old, _new) when old == 0, do: nil

  defp percent_change(old, new) do
    (new - old) / old * 100
  end
end
