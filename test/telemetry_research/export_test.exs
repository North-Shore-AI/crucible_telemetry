defmodule CrucibleTelemetry.ExportTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.{Experiment, Store, Export}

  setup do
    :ets.delete_all_objects(:crucible_telemetry_experiments)

    {:ok, experiment} = Experiment.start(name: "export_test")

    # Add some test data
    base_time = System.system_time(:microsecond)

    Enum.each(1..3, fn i ->
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
        model: "gpt-4",
        provider: :openai,
        metadata: %{tokens: %{total: 500}},
        measurements: %{duration: 100_000_000 * i}
      })
    end)

    on_exit(fn ->
      Experiment.cleanup(experiment.id)
      # Clean up export files
      File.rm_rf!("exports")
    end)

    %{experiment: experiment}
  end

  describe "export/3 CSV" do
    test "exports to CSV format", %{experiment: experiment} do
      {:ok, path} = Export.export(experiment.id, :csv, path: "exports/test.csv")

      assert File.exists?(path)
      content = File.read!(path)

      # Check header is present
      assert content =~ "event_id"
      assert content =~ "latency_ms"
      assert content =~ "cost_usd"

      # Check data is present
      assert content =~ "event-1"
      assert content =~ "event-2"
      assert content =~ "event-3"
    end

    test "creates properly formatted CSV", %{experiment: experiment} do
      {:ok, path} = Export.export(experiment.id, :csv, path: "exports/test_format.csv")

      lines = File.read!(path) |> String.split("\n", trim: true)

      # Should have header + 3 data rows
      assert length(lines) >= 4

      # Header should be comma-separated
      header = List.first(lines)
      assert String.contains?(header, ",")

      # Each data row should have same number of fields as header
      header_fields = String.split(header, ",")

      Enum.each(Enum.slice(lines, 1..-1//1), fn line ->
        # This is a simple check - in real CSV parsing we'd handle quoted fields
        fields = String.split(line, ",")
        assert length(fields) == length(header_fields)
      end)
    end

    test "returns error when no data", %{experiment: _experiment} do
      # Create new experiment with no data
      {:ok, empty_exp} = Experiment.start(name: "empty_test")

      assert {:error, :no_data} = Export.export(empty_exp.id, :csv)

      Experiment.cleanup(empty_exp.id)
    end
  end

  describe "export/3 JSONL" do
    test "exports to JSON Lines format", %{experiment: experiment} do
      {:ok, path} = Export.export(experiment.id, :jsonl, path: "exports/test.jsonl")

      assert File.exists?(path)
      content = File.read!(path)

      lines = String.split(content, "\n", trim: true)
      assert length(lines) == 3

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, _json} = Jason.decode(line)
      end)
    end

    test "each line contains complete event data", %{experiment: experiment} do
      {:ok, path} = Export.export(experiment.id, :jsonl, path: "exports/test_complete.jsonl")

      lines = File.read!(path) |> String.split("\n", trim: true)

      Enum.each(lines, fn line ->
        {:ok, event} = Jason.decode(line)

        assert Map.has_key?(event, "event_id")
        assert Map.has_key?(event, "timestamp")
        assert Map.has_key?(event, "latency_ms")
        assert Map.has_key?(event, "experiment_id")
      end)
    end

    test "returns error when no data", %{experiment: _experiment} do
      {:ok, empty_exp} = Experiment.start(name: "empty_jsonl_test")

      assert {:error, :no_data} = Export.export(empty_exp.id, :jsonl)

      Experiment.cleanup(empty_exp.id)
    end
  end

  describe "export/3 error handling" do
    test "returns error for unsupported format", %{experiment: experiment} do
      assert {:error, :unsupported_format} = Export.export(experiment.id, :xml)
    end

    test "returns error for non-existent experiment" do
      assert {:error, :not_found} = Export.export("nonexistent", :csv)
    end
  end
end
