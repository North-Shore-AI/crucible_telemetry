defmodule CrucibleTelemetry.Store.ETSTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, Store}

  setup do
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    {:ok, experiment} = Experiment.start(name: "store_test")

    on_exit(fn ->
      Experiment.cleanup(experiment.id)
    end)

    %{experiment: experiment}
  end

  describe "init_experiment/1" do
    test "creates ETS table for experiment", %{experiment: experiment} do
      table_name = :"telemetry_research_#{experiment.id}"
      info = :ets.info(table_name)

      assert info != :undefined
      assert info[:named_table] == true
      assert info[:type] == :ordered_set
    end
  end

  describe "insert/2" do
    test "stores event in ETS", %{experiment: experiment} do
      event = %{
        event_id: "test-123",
        timestamp: System.system_time(:microsecond),
        event_name: [:test, :event],
        experiment_id: experiment.id,
        latency_ms: 100.0
      }

      :ok = Store.insert(experiment.id, event)

      events = Store.get_all(experiment.id)
      assert length(events) == 1
      assert List.first(events).event_id == "test-123"
    end

    test "maintains time-ordered storage", %{experiment: experiment} do
      base_time = System.system_time(:microsecond)

      # Insert events out of order
      Store.insert(experiment.id, %{
        event_id: "event-2",
        timestamp: base_time + 2000,
        event_name: [:test, :event]
      })

      Store.insert(experiment.id, %{
        event_id: "event-1",
        timestamp: base_time + 1000,
        event_name: [:test, :event]
      })

      Store.insert(experiment.id, %{
        event_id: "event-3",
        timestamp: base_time + 3000,
        event_name: [:test, :event]
      })

      events = Store.get_all(experiment.id)

      assert length(events) == 3
      assert Enum.at(events, 0).event_id == "event-1"
      assert Enum.at(events, 1).event_id == "event-2"
      assert Enum.at(events, 2).event_id == "event-3"
    end
  end

  describe "get_all/1" do
    test "returns all events in order", %{experiment: experiment} do
      base_time = System.system_time(:microsecond)

      Enum.each(1..5, fn i ->
        Store.insert(experiment.id, %{
          event_id: "event-#{i}",
          timestamp: base_time + i * 1000,
          event_name: [:test, :event]
        })
      end)

      events = Store.get_all(experiment.id)

      assert length(events) == 5

      assert Enum.map(events, & &1.event_id) == [
               "event-1",
               "event-2",
               "event-3",
               "event-4",
               "event-5"
             ]
    end

    test "returns empty list for experiment with no events", %{experiment: experiment} do
      events = Store.get_all(experiment.id)
      assert events == []
    end
  end

  describe "query/2" do
    setup %{experiment: experiment} do
      base_time = System.system_time(:microsecond)

      Store.insert(experiment.id, %{
        event_id: "event-1",
        timestamp: base_time + 1000,
        event_name: [:req_llm, :request, :stop],
        success: true,
        latency_ms: 100.0
      })

      Store.insert(experiment.id, %{
        event_id: "event-2",
        timestamp: base_time + 2000,
        event_name: [:ensemble, :prediction, :stop],
        success: true,
        latency_ms: 200.0
      })

      Store.insert(experiment.id, %{
        event_id: "event-3",
        timestamp: base_time + 3000,
        event_name: [:req_llm, :request, :stop],
        success: false,
        latency_ms: 50.0
      })

      %{base_time: base_time}
    end

    test "filters by event name", %{experiment: experiment} do
      events = Store.query(experiment.id, %{event_name: [:req_llm, :request, :stop]})

      assert length(events) == 2
      assert Enum.all?(events, &(&1.event_name == [:req_llm, :request, :stop]))
    end

    test "filters by success status", %{experiment: experiment} do
      events = Store.query(experiment.id, %{success: true})

      assert length(events) == 2
      assert Enum.all?(events, &(&1.success == true))
    end

    test "filters by time range", %{experiment: experiment, base_time: base_time} do
      events =
        Store.query(experiment.id, %{
          time_range: {base_time + 1500, base_time + 2500}
        })

      assert length(events) == 1
      assert List.first(events).event_id == "event-2"
    end

    test "combines multiple filters", %{experiment: experiment} do
      events =
        Store.query(experiment.id, %{
          event_name: [:req_llm, :request, :stop],
          success: true
        })

      assert length(events) == 1
      assert List.first(events).event_id == "event-1"
    end
  end

  describe "delete_experiment/1" do
    test "removes ETS table", %{experiment: experiment} do
      table_name = :"telemetry_research_#{experiment.id}"

      # Verify table exists
      assert :ets.info(table_name) != :undefined

      # Delete
      :ok = Store.delete_experiment(experiment.id)

      # Verify table is gone
      assert :ets.info(table_name) == :undefined
    end
  end
end
