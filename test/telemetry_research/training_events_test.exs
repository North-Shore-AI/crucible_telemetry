defmodule CrucibleTelemetry.TrainingEventsTest do
  @moduledoc """
  Tests for training event handling in CrucibleTelemetry.
  """
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, Handler, Store}

  setup do
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    {:ok, experiment} = Experiment.start(name: "training_test")

    on_exit(fn ->
      Experiment.cleanup(experiment.id)
    end)

    %{experiment: experiment}
  end

  describe "training event handling" do
    test "handles training start event", %{experiment: experiment} do
      event_name = [:crucible_train, :training, :start]
      measurements = %{system_time: System.system_time()}
      metadata = %{model_name: "bert-base", config: %{epochs: 10}}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == event_name
      assert event.experiment_id == experiment.id
    end

    test "handles training stop event", %{experiment: experiment} do
      event_name = [:crucible_train, :training, :stop]
      measurements = %{duration: 3_600_000_000_000, total_epochs: 10}
      metadata = %{model_name: "bert-base", final_loss: 0.05}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == event_name
      # Duration is in nanoseconds, converted to milliseconds
      assert event.latency_ms == 3_600_000.0
    end

    test "handles epoch stop event with metrics", %{experiment: experiment} do
      event_name = [:crucible_train, :epoch, :stop]

      measurements = %{
        duration: 360_000_000_000,
        loss: 0.25,
        accuracy: 0.85
      }

      metadata = %{
        epoch: 3,
        learning_rate: 0.001
      }

      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.event_name == event_name
      assert event.epoch == 3
      assert event.loss == 0.25
      assert event.accuracy == 0.85
      assert event.learning_rate == 0.001
    end

    test "handles batch stop event with loss", %{experiment: experiment} do
      event_name = [:crucible_train, :batch, :stop]

      measurements = %{
        duration: 100_000_000,
        loss: 0.35,
        gradient_norm: 1.5
      }

      metadata = %{
        epoch: 2,
        batch: 150
      }

      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.event_name == event_name
      assert event.epoch == 2
      assert event.batch == 150
      assert event.loss == 0.35
      assert event.gradient_norm == 1.5
    end

    test "handles checkpoint saved event", %{experiment: experiment} do
      event_name = [:crucible_train, :checkpoint, :saved]

      measurements = %{
        model_size_bytes: 500_000_000
      }

      metadata = %{
        epoch: 5,
        checkpoint_path: "/checkpoints/model_epoch_5.pt"
      }

      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.event_name == event_name
      assert event.epoch == 5
      assert event.checkpoint_path == "/checkpoints/model_epoch_5.pt"
    end
  end

  describe "training event enrichment" do
    test "enriches training events with training-specific fields", %{experiment: experiment} do
      event_name = [:crucible_train, :epoch, :stop]

      measurements = %{
        duration: 100_000_000,
        loss: 0.15,
        accuracy: 0.92
      }

      metadata = %{
        epoch: 7,
        learning_rate: 0.0001
      }

      enriched = Handler.enrich_event(event_name, measurements, metadata, experiment)

      # Base fields
      assert enriched.event_id != nil
      assert enriched.event_name == event_name
      assert enriched.experiment_id == experiment.id

      # Training-specific fields
      assert enriched.epoch == 7
      assert enriched.loss == 0.15
      assert enriched.accuracy == 0.92
      assert enriched.learning_rate == 0.0001
    end

    test "handles missing training fields gracefully", %{experiment: experiment} do
      event_name = [:crucible_train, :training, :start]
      measurements = %{}
      metadata = %{}

      enriched = Handler.enrich_event(event_name, measurements, metadata, experiment)

      # Training fields should be nil when not provided
      assert enriched.epoch == nil
      assert enriched.batch == nil
      assert enriched.loss == nil
      assert enriched.accuracy == nil
    end
  end

  describe "deployment event handling" do
    test "handles inference start event", %{experiment: experiment} do
      event_name = [:crucible_deployment, :inference, :start]
      measurements = %{system_time: System.system_time()}
      metadata = %{model_name: "gpt-4", model_version: "v1.0"}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == event_name
      assert event.model_name == "gpt-4"
      assert event.model_version == "v1.0"
    end

    test "handles inference stop event with metrics", %{experiment: experiment} do
      event_name = [:crucible_deployment, :inference, :stop]

      measurements = %{
        duration: 250_000_000,
        input_size: 512,
        output_size: 128
      }

      metadata = %{
        model_name: "bert-classifier",
        batch_size: 32
      }

      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.event_name == event_name
      assert event.latency_ms == 250.0
      assert event.input_size == 512
      assert event.output_size == 128
      assert event.batch_size == 32
    end
  end

  describe "framework event handling" do
    test "handles pipeline start event", %{experiment: experiment} do
      event_name = [:crucible_framework, :pipeline, :start]
      measurements = %{system_time: System.system_time()}
      metadata = %{pipeline_id: "pipe-123", stage_count: 5}
      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.event_name == event_name
      assert event.pipeline_id == "pipe-123"
    end

    test "handles stage stop event", %{experiment: experiment} do
      event_name = [:crucible_framework, :stage, :stop]

      measurements = %{
        duration: 50_000_000
      }

      metadata = %{
        pipeline_id: "pipe-123",
        stage_name: "preprocessing",
        stage_index: 0
      }

      config = %{experiment: experiment}

      :ok = Handler.handle_event(event_name, measurements, metadata, config)

      events = Store.get_all(experiment.id)
      event = List.first(events)

      assert event.event_name == event_name
      assert event.pipeline_id == "pipe-123"
      assert event.stage_name == "preprocessing"
      assert event.stage_index == 0
    end
  end

  describe "telemetry integration" do
    test "automatically captures training events via telemetry", %{experiment: experiment} do
      # Emit a training event via telemetry
      :telemetry.execute(
        [:crucible_train, :epoch, :stop],
        %{duration: 200_000_000, loss: 0.18, accuracy: 0.89},
        %{epoch: 4, learning_rate: 0.001}
      )

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == [:crucible_train, :epoch, :stop]
      assert event.epoch == 4
      assert event.loss == 0.18
      assert event.accuracy == 0.89
    end

    test "automatically captures deployment events via telemetry", %{experiment: experiment} do
      :telemetry.execute(
        [:crucible_deployment, :inference, :stop],
        %{duration: 100_000_000, input_size: 256},
        %{model_name: "classifier"}
      )

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == [:crucible_deployment, :inference, :stop]
      assert event.model_name == "classifier"
    end

    test "automatically captures framework events via telemetry", %{experiment: experiment} do
      :telemetry.execute(
        [:crucible_framework, :pipeline, :stop],
        %{duration: 500_000_000},
        %{pipeline_id: "test-pipe"}
      )

      events = Store.get_all(experiment.id)
      assert length(events) == 1

      event = List.first(events)
      assert event.event_name == [:crucible_framework, :pipeline, :stop]
      assert event.pipeline_id == "test-pipe"
    end
  end
end
