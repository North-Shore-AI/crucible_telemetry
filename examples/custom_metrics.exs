# Custom Metrics Example for TelemetryResearch
#
# This example shows how to track custom events and metrics
# beyond the standard req_llm events

Application.ensure_all_started(:telemetry_research)

IO.puts("\n=== Custom Metrics Example ===\n")

# 1. Start experiment
{:ok, experiment} =
  CrucibleTelemetry.start_experiment(
    name: "custom_metrics_example",
    hypothesis: "Testing custom event tracking",
    condition: "custom",
    tags: ["custom", "advanced"]
  )

IO.puts("Experiment ID: #{experiment.id}\n")

# 2. Emit custom events
IO.puts("Emitting custom events...")

# Custom event: Causal trace (reasoning step)
:telemetry.execute(
  [:causal_trace, :event, :created],
  %{},
  %{
    trace_id: "trace-1",
    event_type: :hypothesis_formed,
    decision: "Use recursive approach",
    alternatives: ["Iterative", "Dynamic programming"],
    reasoning: "Clearer for tree structures",
    confidence: 0.85
  }
)

# Custom event: Altar tool invocation
:telemetry.execute(
  [:altar, :tool, :start],
  %{system_time: System.system_time()},
  %{
    tool_name: :web_search,
    query: "Elixir telemetry best practices",
    session_id: "session-1"
  }
)

Process.sleep(50)

:telemetry.execute(
  [:altar, :tool, :stop],
  %{duration: 250_000_000},
  %{
    tool_name: :web_search,
    results_count: 10,
    session_id: "session-1",
    cost: 0.005
  }
)

# Custom event: Hedging request
:telemetry.execute(
  [:hedging, :request, :start],
  %{system_time: System.system_time()},
  %{
    request_id: "hedge-1",
    primary_model: :gemini,
    backup_model: :mistral
  }
)

Process.sleep(30)

:telemetry.execute(
  [:hedging, :request, :duplicated],
  %{delay_ms: 50},
  %{
    request_id: "hedge-1",
    primary_model: :gemini,
    backup_model: :mistral,
    reason: :primary_timeout
  }
)

Process.sleep(20)

:telemetry.execute(
  [:hedging, :request, :stop],
  %{duration: 100_000_000},
  %{
    request_id: "hedge-1",
    winner: :backup,
    primary_latency: 1200,
    backup_latency: 450,
    duplication_cost: 0.00008
  }
)

IO.puts("Custom events emitted\n")

# 3. Stop and analyze
{:ok, _} = CrucibleTelemetry.stop_experiment(experiment.id)

metrics = CrucibleTelemetry.calculate_metrics(experiment.id)

IO.puts("Metrics Summary:")
IO.puts("- Total events: #{metrics.summary.total_events}")
IO.puts("\nEvent types:")

Enum.each(metrics.events, fn {event_type, data} ->
  IO.puts("  - #{event_type}: #{data.count} events")
end)

# 4. Query specific event types
IO.puts("\nQuerying specific events...")

altar_events =
  CrucibleTelemetry.Store.query(experiment.id, %{
    event_name: [:altar, :tool, :stop]
  })

IO.puts("- Altar tool events: #{length(altar_events)}")

if length(altar_events) > 0 do
  event = List.first(altar_events)
  IO.puts("  Tool: #{event.metadata[:tool_name]}")
  IO.puts("  Latency: #{event.latency_ms}ms")
  IO.puts("  Cost: $#{event.cost_usd}")
end

hedging_events =
  CrucibleTelemetry.Store.query(experiment.id, %{
    event_name: [:hedging, :request, :stop]
  })

IO.puts("\n- Hedging events: #{length(hedging_events)}")

if length(hedging_events) > 0 do
  event = List.first(hedging_events)
  IO.puts("  Winner: #{event.metadata[:winner]}")
  IO.puts("  Primary latency: #{event.metadata[:primary_latency]}ms")
  IO.puts("  Backup latency: #{event.metadata[:backup_latency]}ms")
end

# 5. Export with all custom data
IO.puts("\nExporting data...")

{:ok, path} =
  CrucibleTelemetry.export(experiment.id, :jsonl, path: "exports/custom_metrics.jsonl")

IO.puts("Exported to: #{path}")

# 6. Demonstrate filtering
IO.puts("\nDemonstrating time-based filtering...")

base_time = System.system_time(:microsecond)
now = System.system_time(:microsecond)

recent_events =
  CrucibleTelemetry.Store.query(experiment.id, %{
    time_range: {base_time, now}
  })

IO.puts("- Events in time range: #{length(recent_events)}")

# 7. Clean up
CrucibleTelemetry.Experiment.cleanup(experiment.id)

IO.puts("\n=== Custom Metrics Example Complete ===\n")
