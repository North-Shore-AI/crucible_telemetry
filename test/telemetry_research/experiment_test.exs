defmodule CrucibleTelemetry.ExperimentTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.Experiment

  setup do
    # Ensure clean state for each test
    :ets.delete_all_objects(:crucible_telemetry_experiments)
    :ok
  end

  describe "start/1" do
    test "creates a new experiment with required name" do
      {:ok, experiment} = Experiment.start(name: "test_experiment")

      assert experiment.name == "test_experiment"
      refute is_nil(experiment.id)
      assert experiment.status == :running
      refute is_nil(experiment.started_at)
      assert experiment.stopped_at == nil
    end

    test "creates experiment with all options" do
      {:ok, experiment} =
        Experiment.start(
          name: "full_experiment",
          hypothesis: "Testing hypothesis",
          condition: "treatment",
          tags: ["tag1", "tag2"],
          metadata: %{custom: "value"},
          sample_size: 1000
        )

      assert experiment.name == "full_experiment"
      assert experiment.hypothesis == "Testing hypothesis"
      assert experiment.condition == "treatment"
      assert experiment.tags == ["tag1", "tag2"]
      assert experiment.metadata == %{custom: "value"}
      assert experiment.sample_size == 1000
    end

    test "uses default values when options not provided" do
      {:ok, experiment} = Experiment.start(name: "defaults")

      assert experiment.condition == "default"
      assert experiment.tags == []
      assert experiment.metadata == %{}
      assert experiment.sample_size == nil
    end

    test "creates isolated ETS storage for experiment" do
      {:ok, experiment} = Experiment.start(name: "storage_test")

      table_name = :"telemetry_research_#{experiment.id}"
      info = :ets.info(table_name)

      assert info != :undefined
      assert info[:type] == :ordered_set
    end
  end

  describe "stop/1" do
    test "stops a running experiment" do
      {:ok, experiment} = Experiment.start(name: "stop_test")
      {:ok, stopped} = Experiment.stop(experiment.id)

      assert stopped.status == :stopped
      assert stopped.stopped_at != nil
    end

    test "detaches telemetry handlers" do
      {:ok, experiment} = Experiment.start(name: "handler_test")

      # Verify handler is attached
      handler_id = "research_#{experiment.id}"
      handlers = :telemetry.list_handlers([])
      assert Enum.any?(handlers, &(&1.id == handler_id))

      # Stop experiment
      {:ok, _stopped} = Experiment.stop(experiment.id)

      # Verify handler is detached
      handlers = :telemetry.list_handlers([])
      refute Enum.any?(handlers, &(&1.id == handler_id))
    end

    test "returns error for non-existent experiment" do
      assert {:error, :not_found} = Experiment.stop("nonexistent")
    end
  end

  describe "get/1" do
    test "retrieves an experiment by ID" do
      {:ok, experiment} = Experiment.start(name: "get_test")
      {:ok, retrieved} = Experiment.get(experiment.id)

      assert retrieved.id == experiment.id
      assert retrieved.name == experiment.name
    end

    test "returns error for non-existent experiment" do
      assert {:error, :not_found} = Experiment.get("nonexistent")
    end
  end

  describe "list/0" do
    test "returns empty list when no experiments" do
      assert Experiment.list() == []
    end

    test "returns all experiments" do
      {:ok, exp1} = Experiment.start(name: "exp1")
      {:ok, exp2} = Experiment.start(name: "exp2")

      experiments = Experiment.list()

      assert length(experiments) == 2
      assert Enum.any?(experiments, &(&1.id == exp1.id))
      assert Enum.any?(experiments, &(&1.id == exp2.id))
    end
  end

  describe "cleanup/2" do
    test "removes experiment from registry" do
      {:ok, experiment} = Experiment.start(name: "cleanup_test")

      :ok = Experiment.cleanup(experiment.id)

      assert {:error, :not_found} = Experiment.get(experiment.id)
    end

    test "deletes experiment data by default" do
      {:ok, experiment} = Experiment.start(name: "cleanup_data_test")
      table_name = :"telemetry_research_#{experiment.id}"

      :ok = Experiment.cleanup(experiment.id)

      assert :ets.info(table_name) == :undefined
    end

    test "keeps data when keep_data option is true" do
      {:ok, experiment} = Experiment.start(name: "keep_data_test")
      table_name = :"telemetry_research_#{experiment.id}"

      :ok = Experiment.cleanup(experiment.id, keep_data: true)

      assert :ets.info(table_name) != :undefined

      # Clean up
      :ets.delete(table_name)
    end
  end
end
