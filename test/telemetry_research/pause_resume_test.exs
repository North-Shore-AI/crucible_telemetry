defmodule CrucibleTelemetry.PauseResumeTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.Experiment

  setup do
    # Clean state
    :ets.delete_all_objects(:crucible_telemetry_experiments)
    :ok
  end

  describe "pause/1" do
    test "pauses a running experiment" do
      {:ok, experiment} = Experiment.start(name: "pause_test")
      {:ok, paused} = Experiment.pause(experiment.id)

      assert paused.status == :paused
      refute is_nil(paused.paused_at)
      assert paused.pause_count == 1
    end

    test "detaches telemetry handlers when paused" do
      {:ok, experiment} = Experiment.start(name: "handler_pause_test")

      # Verify handler is attached
      handler_id = "research_#{experiment.id}"
      handlers = :telemetry.list_handlers([])
      assert Enum.any?(handlers, &(&1.id == handler_id))

      # Pause experiment
      {:ok, _paused} = Experiment.pause(experiment.id)

      # Verify handler is detached
      handlers = :telemetry.list_handlers([])
      refute Enum.any?(handlers, &(&1.id == handler_id))

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "returns error for non-existent experiment" do
      assert {:error, :not_found} = Experiment.pause("nonexistent")
    end

    test "returns error when pausing already paused experiment" do
      {:ok, experiment} = Experiment.start(name: "double_pause_test")
      {:ok, _paused} = Experiment.pause(experiment.id)

      assert {:error, :already_paused} = Experiment.pause(experiment.id)

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "returns error when pausing stopped experiment" do
      {:ok, experiment} = Experiment.start(name: "pause_stopped_test")
      {:ok, _stopped} = Experiment.stop(experiment.id)

      assert {:error, :not_running} = Experiment.pause(experiment.id)

      # Cleanup
      Experiment.cleanup(experiment.id)
    end
  end

  describe "resume/1" do
    test "resumes a paused experiment" do
      {:ok, experiment} = Experiment.start(name: "resume_test")
      {:ok, paused} = Experiment.pause(experiment.id)
      {:ok, resumed} = Experiment.resume(paused.id)

      assert resumed.status == :running
      assert resumed.paused_at == nil
      assert resumed.pause_count == 1
    end

    test "reattaches telemetry handlers when resumed" do
      {:ok, experiment} = Experiment.start(name: "handler_resume_test")
      {:ok, _paused} = Experiment.pause(experiment.id)

      # Verify handler is detached
      handler_id = "research_#{experiment.id}"
      handlers = :telemetry.list_handlers([])
      refute Enum.any?(handlers, &(&1.id == handler_id))

      # Resume experiment
      {:ok, _resumed} = Experiment.resume(experiment.id)

      # Verify handler is reattached
      handlers = :telemetry.list_handlers([])
      assert Enum.any?(handlers, &(&1.id == handler_id))

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "returns error for non-existent experiment" do
      assert {:error, :not_found} = Experiment.resume("nonexistent")
    end

    test "returns error when resuming non-paused experiment" do
      {:ok, experiment} = Experiment.start(name: "resume_running_test")

      assert {:error, :not_paused} = Experiment.resume(experiment.id)

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "handles multiple pause/resume cycles" do
      {:ok, experiment} = Experiment.start(name: "multiple_cycles_test")

      # First cycle
      {:ok, paused1} = Experiment.pause(experiment.id)
      assert paused1.pause_count == 1

      {:ok, resumed1} = Experiment.resume(experiment.id)
      assert resumed1.pause_count == 1

      # Second cycle
      {:ok, paused2} = Experiment.pause(experiment.id)
      assert paused2.pause_count == 2

      {:ok, resumed2} = Experiment.resume(experiment.id)
      assert resumed2.pause_count == 2

      # Third cycle
      {:ok, paused3} = Experiment.pause(experiment.id)
      assert paused3.pause_count == 3

      # Cleanup
      Experiment.cleanup(experiment.id)
    end
  end

  describe "is_paused?/1" do
    test "returns false for running experiment" do
      {:ok, experiment} = Experiment.start(name: "is_paused_test")

      refute Experiment.is_paused?(experiment.id)

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "returns true for paused experiment" do
      {:ok, experiment} = Experiment.start(name: "is_paused_true_test")
      {:ok, _paused} = Experiment.pause(experiment.id)

      assert Experiment.is_paused?(experiment.id)

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "returns false for stopped experiment" do
      {:ok, experiment} = Experiment.start(name: "is_paused_stopped_test")
      {:ok, _stopped} = Experiment.stop(experiment.id)

      refute Experiment.is_paused?(experiment.id)

      # Cleanup
      Experiment.cleanup(experiment.id)
    end

    test "returns false for non-existent experiment" do
      refute Experiment.is_paused?("nonexistent")
    end
  end
end
