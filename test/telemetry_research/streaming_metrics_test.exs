defmodule CrucibleTelemetry.StreamingMetricsTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, StreamingMetrics}
  alias CrucibleTelemetry.Store

  setup do
    # Clean state
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    # Start experiment
    {:ok, experiment} = Experiment.start(name: "streaming_test")

    on_exit(fn ->
      StreamingMetrics.stop(experiment.id)
      Experiment.cleanup(experiment.id)
    end)

    {:ok, experiment: experiment}
  end

  describe "start/1" do
    test "starts streaming metrics for experiment", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      assert Process.whereis(:"streaming_metrics_#{experiment.id}") != nil
    end

    test "returns error if experiment doesn't exist" do
      assert {:error, :not_found} = StreamingMetrics.start("nonexistent")
    end
  end

  describe "get_metrics/1" do
    test "returns initial empty metrics", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      metrics = StreamingMetrics.get_metrics(experiment.id)

      assert metrics.latency.count == 0
      assert metrics.cost.total == 0.0
      assert metrics.reliability.total_requests == 0
    end

    test "updates metrics as events are added", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      # Insert some test events
      Enum.each(1..10, fn i ->
        event = %{
          event_id: "event_#{i}",
          event_name: [:test, :event],
          timestamp: System.system_time(:microsecond),
          experiment_id: experiment.id,
          experiment_name: experiment.name,
          condition: experiment.condition,
          tags: experiment.tags,
          measurements: %{duration: i * 1_000_000},
          metadata: %{},
          latency_ms: i * 1.0,
          cost_usd: 0.001 * i,
          success: true,
          session_id: nil,
          user_id: nil,
          sample_id: nil,
          cohort: nil,
          model: nil,
          provider: nil
        }

        Store.insert(experiment.id, event)
        StreamingMetrics.update(experiment.id, event)
      end)

      # Small delay to allow updates
      Process.sleep(10)

      metrics = StreamingMetrics.get_metrics(experiment.id)

      assert metrics.latency.count == 10
      assert metrics.latency.mean == 5.5
      assert metrics.latency.min == 1.0
      assert metrics.latency.max == 10.0
      assert metrics.cost.total == 0.055
      assert metrics.reliability.total_requests == 10
      assert metrics.reliability.successful == 10
      assert metrics.reliability.success_rate == 1.0
    end

    test "handles mixed success/failure events", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      # 8 successes, 2 failures
      Enum.each(1..10, fn i ->
        event = %{
          event_id: "event_#{i}",
          event_name: [:test, :event],
          timestamp: System.system_time(:microsecond),
          experiment_id: experiment.id,
          experiment_name: experiment.name,
          condition: experiment.condition,
          tags: experiment.tags,
          measurements: %{},
          metadata: %{},
          latency_ms: 100.0,
          cost_usd: 0.01,
          success: i <= 8,
          session_id: nil,
          user_id: nil,
          sample_id: nil,
          cohort: nil,
          model: nil,
          provider: nil
        }

        StreamingMetrics.update(experiment.id, event)
      end)

      Process.sleep(10)

      metrics = StreamingMetrics.get_metrics(experiment.id)

      assert metrics.reliability.total_requests == 10
      assert metrics.reliability.successful == 8
      assert metrics.reliability.failed == 2
      assert metrics.reliability.success_rate == 0.8
    end
  end

  describe "update/2" do
    test "incrementally updates statistics", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      event1 = create_test_event(experiment, latency: 10.0, cost: 0.01, success: true)
      StreamingMetrics.update(experiment.id, event1)

      metrics1 = StreamingMetrics.get_metrics(experiment.id)
      assert metrics1.latency.mean == 10.0

      event2 = create_test_event(experiment, latency: 20.0, cost: 0.02, success: true)
      StreamingMetrics.update(experiment.id, event2)

      metrics2 = StreamingMetrics.get_metrics(experiment.id)
      assert metrics2.latency.mean == 15.0
      assert metrics2.latency.min == 10.0
      assert metrics2.latency.max == 20.0
      assert metrics2.cost.total == 0.03
    end

    test "handles nil values gracefully", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      event = create_test_event(experiment, latency: nil, cost: nil, success: nil)
      StreamingMetrics.update(experiment.id, event)

      metrics = StreamingMetrics.get_metrics(experiment.id)
      assert metrics.latency.count == 0
      assert metrics.cost.count == 0
    end
  end

  describe "reset/1" do
    test "resets all streaming metrics", %{experiment: experiment} do
      {:ok, _pid} = StreamingMetrics.start(experiment.id)

      # Add some events
      event = create_test_event(experiment, latency: 100.0, cost: 0.1, success: true)
      StreamingMetrics.update(experiment.id, event)

      # Verify metrics exist
      metrics_before = StreamingMetrics.get_metrics(experiment.id)
      assert metrics_before.latency.count > 0

      # Reset
      :ok = StreamingMetrics.reset(experiment.id)

      # Verify metrics are reset
      metrics_after = StreamingMetrics.get_metrics(experiment.id)
      assert metrics_after.latency.count == 0
      assert metrics_after.cost.total == 0.0
    end
  end

  describe "stop/1" do
    test "stops streaming metrics GenServer", %{experiment: experiment} do
      {:ok, pid} = StreamingMetrics.start(experiment.id)
      assert Process.alive?(pid)

      :ok = StreamingMetrics.stop(experiment.id)

      # Small delay for process to stop
      Process.sleep(10)

      refute Process.alive?(pid)
    end
  end

  # Helper functions

  defp create_test_event(experiment, opts) do
    %{
      event_id: Keyword.get(opts, :event_id, generate_id()),
      event_name: [:test, :event],
      timestamp: System.system_time(:microsecond),
      experiment_id: experiment.id,
      experiment_name: experiment.name,
      condition: experiment.condition,
      tags: experiment.tags,
      measurements: %{},
      metadata: %{},
      latency_ms: Keyword.get(opts, :latency),
      cost_usd: Keyword.get(opts, :cost),
      success: Keyword.get(opts, :success),
      session_id: nil,
      user_id: nil,
      sample_id: nil,
      cohort: nil,
      model: nil,
      provider: nil
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
