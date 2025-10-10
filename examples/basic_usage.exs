# Basic Usage Example for TelemetryResearch
#
# This example demonstrates the core workflow:
# 1. Start an experiment
# 2. Emit some telemetry events
# 3. Stop the experiment
# 4. Export and analyze results

# Start the application if not already running
Application.ensure_all_started(:telemetry_research)

IO.puts("\n=== Basic TelemetryResearch Usage ===\n")

# 1. Start an experiment
IO.puts("1. Starting experiment...")

{:ok, experiment} =
  CrucibleTelemetry.start_experiment(
    name: "basic_example",
    hypothesis: "Testing the telemetry research library",
    condition: "example",
    tags: ["tutorial", "basic"]
  )

IO.puts("   Experiment ID: #{experiment.id}")
IO.puts("   Started at: #{experiment.started_at}")

# 2. Simulate some telemetry events
IO.puts("\n2. Emitting telemetry events...")

# Simulate 5 LLM requests
Enum.each(1..5, fn i ->
  # Start event
  :telemetry.execute(
    [:req_llm, :request, :start],
    %{system_time: System.system_time()},
    %{
      provider: :openai,
      model: "gpt-4",
      request_id: "req-#{i}"
    }
  )

  # Simulate processing time
  Process.sleep(10)

  # Stop event (success)
  :telemetry.execute(
    [:req_llm, :request, :stop],
    %{duration: 100_000_000 + :rand.uniform(50_000_000)},
    %{
      provider: :openai,
      model: "gpt-4",
      request_id: "req-#{i}",
      tokens: %{
        prompt: 100 + :rand.uniform(50),
        completion: 200 + :rand.uniform(100),
        total: 300 + :rand.uniform(150)
      },
      cost: 0.001 + :rand.uniform() * 0.002
    }
  )

  IO.puts("   Emitted event #{i}/5")
end)

# 3. Stop the experiment
IO.puts("\n3. Stopping experiment...")
{:ok, stopped_experiment} = CrucibleTelemetry.stop_experiment(experiment.id)
IO.puts("   Stopped at: #{stopped_experiment.stopped_at}")

# 4. Calculate metrics
IO.puts("\n4. Calculating metrics...")
metrics = CrucibleTelemetry.calculate_metrics(experiment.id)

IO.puts("\n   Summary:")
IO.puts("   - Total events: #{metrics.summary.total_events}")
IO.puts("   - Duration: #{Float.round(metrics.summary.duration_seconds, 2)}s")

if metrics.latency.count > 0 do
  IO.puts("\n   Latency:")
  IO.puts("   - Mean: #{Float.round(metrics.latency.mean, 2)}ms")
  IO.puts("   - Median: #{Float.round(metrics.latency.median, 2)}ms")
  IO.puts("   - P95: #{Float.round(metrics.latency.p95, 2)}ms")
  IO.puts("   - Min: #{Float.round(metrics.latency.min, 2)}ms")
  IO.puts("   - Max: #{Float.round(metrics.latency.max, 2)}ms")
end

if metrics.cost.count > 0 do
  IO.puts("\n   Cost:")
  IO.puts("   - Total: $#{Float.round(metrics.cost.total, 4)}")
  IO.puts("   - Mean per request: $#{Float.round(metrics.cost.mean_per_request, 4)}")
  IO.puts("   - Cost per 1K requests: $#{Float.round(metrics.cost.cost_per_1k_requests, 2)}")
end

if metrics.reliability.success_rate do
  IO.puts("\n   Reliability:")
  IO.puts("   - Success rate: #{Float.round(metrics.reliability.success_rate * 100, 2)}%")
  IO.puts("   - Successful: #{metrics.reliability.successful}")
  IO.puts("   - Failed: #{metrics.reliability.failed}")
end

# 5. Export to CSV
IO.puts("\n5. Exporting to CSV...")
{:ok, csv_path} = CrucibleTelemetry.export(experiment.id, :csv, path: "exports/basic_example.csv")
IO.puts("   Exported to: #{csv_path}")

# 6. Export to JSON Lines
IO.puts("\n6. Exporting to JSON Lines...")

{:ok, jsonl_path} =
  CrucibleTelemetry.export(experiment.id, :jsonl, path: "exports/basic_example.jsonl")

IO.puts("   Exported to: #{jsonl_path}")

# 7. Clean up
IO.puts("\n7. Cleaning up...")
:ok = CrucibleTelemetry.Experiment.cleanup(experiment.id)
IO.puts("   Cleanup complete")

IO.puts("\n=== Example Complete ===\n")
