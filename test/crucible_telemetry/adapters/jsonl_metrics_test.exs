defmodule CrucibleTelemetry.Adapters.JSONLMetricsTest do
  @moduledoc """
  Tests for the JSONL MetricsStore adapter.
  """
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.Adapters.JSONLMetrics
  alias CrucibleTelemetry.Ports.MetricsStore

  setup do
    path = Path.join(System.tmp_dir!(), "test_metrics_#{:rand.uniform(100_000)}.jsonl")
    on_exit(fn -> File.rm(path) end)
    {:ok, path: path}
  end

  describe "record/5" do
    test "appends a metric entry to the file", %{path: path} do
      adapter = {JSONLMetrics, [path: path]}

      assert :ok = MetricsStore.record(adapter, "run_123", :loss, 1.5, step: 0)

      assert File.exists?(path)
      content = File.read!(path)
      entry = Jason.decode!(content)

      assert entry["run_id"] == "run_123"
      assert entry["metric"] == "loss"
      assert entry["value"] == 1.5
      assert entry["step"] == 0
      assert entry["timestamp"]
    end

    test "appends multiple entries", %{path: path} do
      adapter = {JSONLMetrics, [path: path]}

      assert :ok = MetricsStore.record(adapter, "run_123", :loss, 2.0, step: 0)
      assert :ok = MetricsStore.record(adapter, "run_123", :loss, 1.5, step: 1)
      assert :ok = MetricsStore.record(adapter, "run_123", :loss, 1.2, step: 2)

      lines = File.read!(path) |> String.split("\n", trim: true)
      assert length(lines) == 3

      [first, second, third] = Enum.map(lines, &Jason.decode!/1)

      assert first["value"] == 2.0
      assert second["value"] == 1.5
      assert third["value"] == 1.2
    end

    test "records metrics with metadata", %{path: path} do
      adapter = {JSONLMetrics, [path: path]}

      assert :ok =
               MetricsStore.record(adapter, "run_123", :lr, 0.001,
                 step: 10,
                 metadata: %{epoch: 1, batch: 5}
               )

      content = File.read!(path)
      entry = Jason.decode!(content)

      assert entry["metadata"]["epoch"] == 1
      assert entry["metadata"]["batch"] == 5
    end
  end

  describe "flush/2" do
    test "returns :ok (JSONL writes are immediate)", %{path: path} do
      adapter = {JSONLMetrics, [path: path]}

      MetricsStore.record(adapter, "run_123", :loss, 1.0, step: 0)
      assert :ok = MetricsStore.flush(adapter, "run_123")
    end
  end

  describe "read/2" do
    test "returns empty list for non-existent file" do
      adapter = {JSONLMetrics, [path: "/tmp/does_not_exist_12345.jsonl"]}
      assert {:ok, []} = MetricsStore.read(adapter, "run_123")
    end

    test "returns all entries for a run_id", %{path: path} do
      adapter = {JSONLMetrics, [path: path]}

      MetricsStore.record(adapter, "run_1", :loss, 1.0, step: 0)
      MetricsStore.record(adapter, "run_1", :loss, 0.9, step: 1)
      MetricsStore.record(adapter, "run_2", :loss, 2.0, step: 0)

      {:ok, entries} = MetricsStore.read(adapter, "run_1")

      assert length(entries) == 2
      assert Enum.all?(entries, &(&1["run_id"] == "run_1"))
    end

    test "returns entries in order", %{path: path} do
      adapter = {JSONLMetrics, [path: path]}

      MetricsStore.record(adapter, "run_1", :loss, 3.0, step: 0)
      MetricsStore.record(adapter, "run_1", :loss, 2.0, step: 1)
      MetricsStore.record(adapter, "run_1", :loss, 1.0, step: 2)

      {:ok, entries} = MetricsStore.read(adapter, "run_1")

      values = Enum.map(entries, & &1["value"])
      assert values == [3.0, 2.0, 1.0]
    end
  end

  describe "behaviour compliance" do
    test "implements MetricsStore behaviour" do
      behaviours = JSONLMetrics.__info__(:attributes)[:behaviour] || []
      assert MetricsStore in behaviours
    end
  end
end
