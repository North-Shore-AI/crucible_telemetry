defmodule CrucibleTelemetry.TimeWindowTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, Store}

  setup do
    # Clean state
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    # Start experiment
    {:ok, experiment} = Experiment.start(name: "window_test")

    # Insert test events with different timestamps
    base_time = System.system_time(:microsecond)

    events =
      Enum.map(1..20, fn i ->
        %{
          event_id: "event_#{i}",
          event_name: [:test, :event],
          timestamp: base_time + i * 60_000_000,
          # Events 1 minute apart
          experiment_id: experiment.id,
          experiment_name: experiment.name,
          condition: experiment.condition,
          tags: experiment.tags,
          measurements: %{},
          metadata: %{value: i},
          latency_ms: i * 10.0,
          cost_usd: 0.001 * i,
          success: true,
          session_id: nil,
          user_id: nil,
          sample_id: nil,
          cohort: nil,
          model: nil,
          provider: nil
        }
      end)

    Enum.each(events, &Store.insert(experiment.id, &1))

    on_exit(fn ->
      Experiment.cleanup(experiment.id)
    end)

    {:ok, experiment: experiment, base_time: base_time, events: events}
  end

  describe "query_window/3 with :last" do
    test "queries last N minutes of events", %{experiment: experiment, base_time: base_time} do
      # Query last 5 minutes
      now = base_time + 21 * 60_000_000
      events = Store.query_window(experiment.id, {:last, 5, :minutes}, now: now)

      # Should get events from minute 16-20 (5 events)
      assert length(events) == 5

      values = Enum.map(events, & &1.metadata.value)
      assert values == [16, 17, 18, 19, 20]
    end

    test "queries last N seconds of events", %{experiment: experiment, base_time: base_time} do
      # Query last 120 seconds (2 minutes)
      now = base_time + 21 * 60_000_000
      events = Store.query_window(experiment.id, {:last, 120, :seconds}, now: now)

      # Should get events from minute 19-20 (2 events)
      assert length(events) == 2
    end

    test "queries last N hours of events", %{experiment: experiment, base_time: base_time} do
      # Query last 1 hour (should get all events)
      now = base_time + 21 * 60_000_000
      events = Store.query_window(experiment.id, {:last, 1, :hours}, now: now)

      assert length(events) == 20
    end
  end

  describe "query_window/3 with :last_n" do
    test "queries last N events", %{experiment: experiment} do
      events = Store.query_window(experiment.id, {:last_n, 5})

      assert length(events) == 5

      # Should get the most recent events (16-20)
      values = Enum.map(events, & &1.metadata.value)
      assert values == [16, 17, 18, 19, 20]
    end

    test "handles request for more events than exist", %{experiment: experiment} do
      events = Store.query_window(experiment.id, {:last_n, 100})

      assert length(events) == 20
    end

    test "returns empty list for zero events", %{experiment: experiment} do
      events = Store.query_window(experiment.id, {:last_n, 0})

      assert events == []
    end

    test "returns empty list for invalid unit" do
      {:ok, experiment} = Experiment.start(name: "invalid_unit_test")
      now = System.system_time(:microsecond)

      events = Store.query_window(experiment.id, {:last, 5, :days}, now: now)

      assert events == []

      Experiment.cleanup(experiment.id)
    end
  end

  describe "query_window/3 with :range" do
    test "queries events in specific time range", %{experiment: experiment, base_time: base_time} do
      # Get events from minute 5 to minute 10
      start_time = base_time + 5 * 60_000_000
      end_time = base_time + 10 * 60_000_000

      events = Store.query_window(experiment.id, {:range, start_time, end_time})

      # Should get events 5-10 (6 events)
      assert length(events) == 6

      values = Enum.map(events, & &1.metadata.value)
      assert values == [5, 6, 7, 8, 9, 10]
    end

    test "returns empty list for range with no events", %{
      experiment: experiment,
      base_time: base_time
    } do
      # Query a range before all events
      start_time = base_time - 10 * 60_000_000
      end_time = base_time - 5 * 60_000_000

      events = Store.query_window(experiment.id, {:range, start_time, end_time})

      assert events == []
    end
  end

  describe "query_window/3 with filters" do
    test "combines window with additional filters", %{experiment: experiment} do
      # Get last 10 events where value > 15
      events =
        Store.query_window(experiment.id, {:last_n, 10}, fn event ->
          event.metadata.value > 15
        end)

      # Should get events 16-20 (5 events)
      assert length(events) == 5

      values = Enum.map(events, & &1.metadata.value)
      assert values == [16, 17, 18, 19, 20]
    end

    test "filters by success status", %{experiment: experiment} do
      # Add some failed events
      failed_event = %{
        event_id: "failed_1",
        event_name: [:test, :event],
        timestamp: System.system_time(:microsecond),
        experiment_id: experiment.id,
        experiment_name: experiment.name,
        condition: experiment.condition,
        tags: experiment.tags,
        measurements: %{},
        metadata: %{value: 100},
        latency_ms: 1000.0,
        cost_usd: 0.1,
        success: false,
        session_id: nil,
        user_id: nil,
        sample_id: nil,
        cohort: nil,
        model: nil,
        provider: nil
      }

      Store.insert(experiment.id, failed_event)

      # Query only successful events
      events =
        Store.query_window(experiment.id, {:last_n, 100}, fn event ->
          event.success == true
        end)

      assert length(events) == 20
      assert Enum.all?(events, &(&1.success == true))
    end
  end

  describe "windowed_metrics/3" do
    test "calculates metrics for time windows", %{experiment: experiment} do
      # Calculate metrics for 5-minute windows
      window_size = 5 * 60_000_000
      # 5 minutes in microseconds
      step_size = 5 * 60_000_000

      windows = Store.windowed_metrics(experiment.id, window_size, step_size)

      # Should get 4 windows: 1-5, 6-10, 11-15, 16-20
      assert length(windows) == 4

      # Check first window (events 1-5)
      first_window = hd(windows)
      assert first_window.event_count == 5
      assert first_window.mean_latency == 30.0
      # (10+20+30+40+50)/5
      assert first_window.total_cost == 0.015
      # 0.001+0.002+0.003+0.004+0.005
    end

    test "handles overlapping sliding windows", %{experiment: experiment} do
      # Sliding windows: 10-minute window, 5-minute step
      window_size = 10 * 60_000_000
      step_size = 5 * 60_000_000

      windows = Store.windowed_metrics(experiment.id, window_size, step_size)

      # Should get 3 windows: 1-10, 6-15, 11-20
      assert length(windows) == 3

      # Windows should overlap
      first_window = Enum.at(windows, 0)
      second_window = Enum.at(windows, 1)

      assert first_window.event_count == 10
      assert second_window.event_count == 10
    end

    test "returns empty list for empty experiment" do
      {:ok, empty_exp} = Experiment.start(name: "empty")

      windows = Store.windowed_metrics(empty_exp.id, 60_000_000, 60_000_000)

      assert windows == []

      Experiment.cleanup(empty_exp.id)
    end

    test "returns empty list for invalid window parameters", %{experiment: experiment} do
      assert Store.windowed_metrics(experiment.id, 0, 60_000_000) == []
      assert Store.windowed_metrics(experiment.id, 60_000_000, 0) == []
    end
  end
end
