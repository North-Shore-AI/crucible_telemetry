defmodule CrucibleTelemetry.AnalysisTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, Store, Analysis}

  setup do
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    {:ok, experiment} = Experiment.start(name: "analysis_test")

    # Add test data with various metrics
    base_time = System.system_time(:microsecond)

    # 10 successful events with varying latencies
    Enum.each(1..10, fn i ->
      Store.insert(experiment.id, %{
        event_id: "event-#{i}",
        timestamp: base_time + i * 1000,
        event_name: [:req_llm, :request, :stop],
        experiment_id: experiment.id,
        experiment_name: experiment.name,
        condition: experiment.condition,
        tags: experiment.tags,
        latency_ms: 100.0 * i,
        cost_usd: 0.001 * i,
        success: true,
        metadata: %{
          tokens: %{
            prompt: 100 * i,
            completion: 200 * i,
            total: 300 * i
          }
        },
        measurements: %{}
      })
    end)

    # 2 failed events
    Enum.each(11..12, fn i ->
      Store.insert(experiment.id, %{
        event_id: "event-#{i}",
        timestamp: base_time + i * 1000,
        event_name: [:req_llm, :request, :exception],
        experiment_id: experiment.id,
        experiment_name: experiment.name,
        condition: experiment.condition,
        tags: experiment.tags,
        latency_ms: nil,
        cost_usd: nil,
        success: false,
        metadata: %{},
        measurements: %{}
      })
    end)

    on_exit(fn ->
      Experiment.cleanup(experiment.id)
    end)

    %{experiment: experiment}
  end

  describe "calculate_metrics/1" do
    test "calculates comprehensive metrics", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      assert Map.has_key?(metrics, :summary)
      assert Map.has_key?(metrics, :latency)
      assert Map.has_key?(metrics, :cost)
      assert Map.has_key?(metrics, :reliability)
      assert Map.has_key?(metrics, :tokens)
      assert Map.has_key?(metrics, :events)
    end

    test "calculates summary metrics correctly", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      assert metrics.summary.total_events == 12
      assert metrics.summary.duration_seconds > 0
    end

    test "calculates latency metrics correctly", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      # 10 events with latencies 100, 200, ..., 1000
      assert metrics.latency.count == 10
      assert metrics.latency.mean == 550.0
      assert metrics.latency.min == 100.0
      assert metrics.latency.max == 1000.0
      assert metrics.latency.median == 550.0
    end

    test "calculates cost metrics correctly", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      # 10 events with costs 0.001, 0.002, ..., 0.010
      assert metrics.cost.count == 10
      assert metrics.cost.total == 0.055
      assert_in_delta metrics.cost.mean_per_request, 0.0055, 0.0001
    end

    test "calculates reliability metrics correctly", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      assert metrics.reliability.total_requests == 12
      assert metrics.reliability.successful == 10
      assert metrics.reliability.failed == 2
      assert_in_delta metrics.reliability.success_rate, 0.8333, 0.01
      assert metrics.reliability.sla_99 == false
      assert metrics.reliability.sla_999 == false
    end

    test "calculates token metrics correctly", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      # 10 events with tokens: (100, 200, 300), (200, 400, 600), ..., (1000, 2000, 3000)
      assert metrics.tokens.count == 10
      assert metrics.tokens.total_prompt == 5500
      assert metrics.tokens.total_completion == 11000
      assert metrics.tokens.total == 16500
      assert metrics.tokens.mean_prompt == 550.0
      assert metrics.tokens.mean_completion == 1100.0
      assert metrics.tokens.mean_total == 1650.0
    end

    test "calculates event type metrics correctly", %{experiment: experiment} do
      metrics = Analysis.calculate_metrics(experiment.id)

      assert metrics.events["req_llm.request.stop"] == %{count: 10}
      assert metrics.events["req_llm.request.exception"] == %{count: 2}
    end
  end

  describe "compare_experiments/1" do
    test "compares multiple experiments" do
      # Create second experiment
      {:ok, exp2} = Experiment.start(name: "comparison_test")

      # Add data with better metrics
      base_time = System.system_time(:microsecond)

      Enum.each(1..10, fn i ->
        Store.insert(exp2.id, %{
          event_id: "event-#{i}",
          timestamp: base_time + i * 1000,
          event_name: [:req_llm, :request, :stop],
          experiment_id: exp2.id,
          experiment_name: exp2.name,
          condition: "treatment",
          tags: [],
          latency_ms: 50.0 * i,
          # Lower latency
          cost_usd: 0.0005 * i,
          # Lower cost
          success: true,
          metadata: %{},
          measurements: %{}
        })
      end)

      experiment_ids = [
        CrucibleTelemetry.Experiment.list() |> Enum.at(0) |> Map.get(:id),
        exp2.id
      ]

      comparison = Analysis.compare_experiments(experiment_ids)

      assert Map.has_key?(comparison, :experiments)
      assert Map.has_key?(comparison, :individual)
      assert Map.has_key?(comparison, :comparison)

      assert length(comparison.individual) == 2

      # Clean up
      Experiment.cleanup(exp2.id)
    end
  end

  describe "statistical functions" do
    test "calculates percentiles correctly" do
      # Test with known dataset
      {:ok, exp} = Experiment.start(name: "percentile_test")
      base_time = System.system_time(:microsecond)

      # Insert 100 events with latencies 1..100
      Enum.each(1..100, fn i ->
        Store.insert(exp.id, %{
          event_id: "event-#{i}",
          timestamp: base_time + i * 1000,
          event_name: [:test, :event],
          experiment_id: exp.id,
          experiment_name: exp.name,
          condition: "default",
          tags: [],
          latency_ms: i * 1.0,
          cost_usd: nil,
          success: true,
          metadata: %{},
          measurements: %{}
        })
      end)

      metrics = Analysis.calculate_metrics(exp.id)

      # P50 should be around 50
      assert_in_delta metrics.latency.p50, 50.5, 1.0

      # P95 should be around 95
      assert_in_delta metrics.latency.p95, 95.5, 1.0

      # P99 should be around 99
      assert_in_delta metrics.latency.p99, 99.5, 1.0

      Experiment.cleanup(exp.id)
    end
  end
end
