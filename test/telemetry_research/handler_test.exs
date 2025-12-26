defmodule CrucibleTelemetry.HandlerTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, Handler, Store}

  setup do
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    {:ok, experiment} = Experiment.start(name: "handler_test")

    on_exit(fn ->
      Experiment.cleanup(experiment.id)
    end)

    %{experiment: experiment}
  end

  describe "handle_event/4" do
    test "stores enriched event", %{experiment: experiment} do
      event_name = [:req_llm, :request, :stop]
      measurements = %{duration: 150_000_000}
      metadata = %{model: "gpt-4", provider: :openai}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == event_name
      assert event.experiment_id == experiment.id
      assert event.latency_ms == 150.0
    end

    test "enriches event with experiment context", %{experiment: experiment} do
      event_name = [:test, :event]
      measurements = %{}
      metadata = %{}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.experiment_id == experiment.id
      assert event.experiment_name == experiment.name
      assert event.condition == experiment.condition
      assert event.tags == experiment.tags
    end

    test "calculates latency from duration", %{experiment: experiment} do
      event_name = [:test, :latency]
      measurements = %{duration: 250_000_000}
      metadata = %{}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.latency_ms == 250.0
    end

    test "determines success from metadata", %{experiment: experiment} do
      config = %{experiment: experiment}

      # Success case
      Handler.handle_event([:test, :success], %{}, %{response: "ok"}, config)

      # Failure case
      Handler.handle_event([:test, :failure], %{}, %{error: "timeout"}, config)

      events = Store.get_all(experiment.id)
      assert length(events) == 2

      success_event = Enum.find(events, &(&1.event_name == [:test, :success]))
      failure_event = Enum.find(events, &(&1.event_name == [:test, :failure]))

      assert success_event.success == true
      assert failure_event.success == false
    end
  end

  describe "enrich_event/4" do
    test "creates properly structured event", %{experiment: experiment} do
      event_name = [:test, :event]
      measurements = %{duration: 100_000_000}

      metadata = %{
        model: "gpt-4",
        provider: :openai,
        session_id: "session-123"
      }

      enriched = Handler.enrich_event(event_name, measurements, metadata, experiment)

      assert enriched.event_id != nil
      assert enriched.event_name == event_name
      assert enriched.timestamp != nil
      assert enriched.experiment_id == experiment.id
      assert enriched.latency_ms == 100.0
      assert enriched.model == "gpt-4"
      assert enriched.provider == :openai
      assert enriched.session_id == "session-123"
    end

    test "calculates cost from tokens and model", %{experiment: experiment} do
      event_name = [:test, :cost]
      measurements = %{}

      metadata = %{
        model: "gpt-4",
        tokens: %{prompt: 100, completion: 200, total: 300}
      }

      enriched = Handler.enrich_event(event_name, measurements, metadata, experiment)

      assert enriched.cost_usd != nil
      assert enriched.cost_usd > 0
    end
  end
end
