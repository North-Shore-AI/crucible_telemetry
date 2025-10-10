<p align="center">
  <img src="assets/crucible_telemetry.svg" alt="Telemetry" width="150"/>
</p>

# CrucibleTelemetry

**Research-grade instrumentation and metrics collection for AI/ML experiments in Elixir.**

## Overview

**TelemetryResearch** provides specialized observability for rigorous scientific experimentation, going beyond standard production telemetry with features designed for AI/ML research:

- **Experiment Isolation**: Run multiple experiments concurrently without cross-contamination
- **Rich Metadata**: Automatic enrichment with experiment context, timestamps, and custom tags
- **Multiple Export Formats**: CSV, JSON Lines for analysis in Python, R, Julia, Excel
- **Complete Event Capture**: No sampling by default - full reproducibility
- **Statistical Analysis**: Built-in descriptive statistics and metrics calculations
- **Zero-Cost Abstraction**: Minimal overhead when not actively collecting data

## Why TelemetryResearch?

Standard production telemetry libraries focus on monitoring and alerting, but research experiments have different requirements:

| Production Telemetry | Research Telemetry (this library) |
|---------------------|-----------------------------------|
| Real-time dashboards | Statistical analysis and exports |
| Sampling for efficiency | Complete capture for reproducibility |
| Fixed metrics | Rich, experiment-specific metadata |
| Single workload tracking | Multiple concurrent experiments |
| JSON/logs output | CSV, JSON Lines, Parquet for analysis tools |

## Installation

Add `telemetry_research` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crucible_telemetry, "~> 0.1.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
    {:crucible_telemetry, github: "nshkrdotcom/elixir_ai_research", sparse: "apps/telemetry_research"}
  ]
end
```

## Quick Start

```elixir
# 1. Start an experiment
{:ok, experiment} = CrucibleTelemetry.start_experiment(
  name: "ensemble_vs_single",
  hypothesis: "5-model ensemble achieves >99% reliability",
  condition: "treatment",
  tags: ["accuracy", "reliability"]
)

# 2. Run your AI workload - events are automatically collected
# Your existing code with :telemetry.execute() calls works unchanged

# 3. Stop and analyze
{:ok, experiment} = CrucibleTelemetry.stop_experiment(experiment.id)

metrics = CrucibleTelemetry.calculate_metrics(experiment.id)
# => %{
#   latency: %{mean: 150.5, p95: 250.0, ...},
#   cost: %{total: 0.025, mean_per_request: 0.0025, ...},
#   reliability: %{success_rate: 0.99, ...}
# }

# 4. Export for analysis
{:ok, path} = CrucibleTelemetry.export(experiment.id, :csv)
# Now analyze in Python: pd.read_csv(path)
```

## Core Concepts

### Experiments

An **experiment** is an isolated collection session with its own:
- Unique ID and metadata
- Dedicated storage (ETS table)
- Telemetry event handlers
- Tags and conditions for comparison

```elixir
{:ok, experiment} = CrucibleTelemetry.start_experiment(
  name: "gpt4_baseline",
  hypothesis: "Single GPT-4 achieves 90% accuracy on benchmark",
  condition: "control",
  tags: ["h1", "baseline", "gpt4"],
  sample_size: 1000,
  metadata: %{
    researcher: "alice",
    benchmark: "mmlu",
    version: "v1"
  }
)
```

### Event Collection

TelemetryResearch automatically attaches to standard telemetry events:

- `[:req_llm, :request, :start|stop|exception]` - LLM API calls
- `[:ensemble, :prediction, :start|stop]` - Ensemble predictions
- `[:ensemble, :vote, :completed]` - Voting results
- `[:hedging, :request, :*]` - Request hedging events
- `[:causal_trace, :event, :created]` - Reasoning traces
- `[:altar, :tool, :*]` - Tool invocations

Events are enriched with:
- Experiment context (ID, name, condition, tags)
- Computed metrics (latency, cost, success)
- Timestamps (microsecond precision)
- Custom metadata

### Storage

Events are stored in **ETS tables** for fast in-memory access:

```elixir
# Query events by filters
events = CrucibleTelemetry.Store.query(experiment.id, %{
  event_name: [:req_llm, :request, :stop],
  success: true,
  time_range: {start_time, end_time}
})
```

ETS storage is ideal for experiments with <1M events. For longer experiments or persistent storage, PostgreSQL backend support is planned.

### Metrics & Analysis

Calculate comprehensive metrics automatically:

```elixir
metrics = CrucibleTelemetry.calculate_metrics(experiment.id)

# Latency metrics
metrics.latency.mean      # Average latency
metrics.latency.median    # Median latency
metrics.latency.p50       # 50th percentile
metrics.latency.p95       # 95th percentile
metrics.latency.p99       # 99th percentile
metrics.latency.std_dev   # Standard deviation

# Cost metrics
metrics.cost.total                  # Total cost in USD
metrics.cost.mean_per_request       # Average cost per request
metrics.cost.cost_per_1k_requests   # Projected cost for 1K requests
metrics.cost.cost_per_1m_requests   # Projected cost for 1M requests

# Reliability metrics
metrics.reliability.success_rate    # Success rate (0.0-1.0)
metrics.reliability.successful      # Count of successful requests
metrics.reliability.failed          # Count of failed requests
metrics.reliability.sla_99          # Meets 99% SLA?
metrics.reliability.sla_999         # Meets 99.9% SLA?

# Token metrics (if available)
metrics.tokens.total_prompt         # Total prompt tokens
metrics.tokens.total_completion     # Total completion tokens
metrics.tokens.mean_total           # Average tokens per request
```

### Export Formats

Export data for analysis in your preferred tool:

#### CSV (Excel, pandas, R)

```elixir
{:ok, path} = CrucibleTelemetry.export(experiment.id, :csv,
  path: "results/experiment.csv"
)

# Then in Python:
# import pandas as pd
# df = pd.read_csv("results/experiment.csv")
# df.groupby('condition')['latency_ms'].describe()
```

#### JSON Lines (streaming, jq)

```elixir
{:ok, path} = CrucibleTelemetry.export(experiment.id, :jsonl,
  path: "results/experiment.jsonl"
)

# Then with jq:
# cat results/experiment.jsonl | jq '.latency_ms' | jq -s 'add/length'
```

## Use Cases

### 1. A/B Testing

Compare two approaches side-by-side:

```elixir
# Control: Single model
{:ok, control} = CrucibleTelemetry.start_experiment(
  name: "control_single_model",
  condition: "control",
  tags: ["ab_test"]
)

# Treatment: Ensemble
{:ok, treatment} = CrucibleTelemetry.start_experiment(
  name: "treatment_ensemble",
  condition: "treatment",
  tags: ["ab_test"]
)

# ... run workloads ...

# Compare results
comparison = CrucibleTelemetry.Analysis.compare_experiments([
  control.id,
  treatment.id
])
```

### 2. Performance Benchmarking

Track performance over time:

```elixir
{:ok, exp} = CrucibleTelemetry.start_experiment(
  name: "gemini_2_flash_benchmark",
  tags: ["benchmark", "latency", "2024-12"]
)

# Run benchmark suite
Enum.each(benchmark_queries, fn query ->
  # Make LLM calls - automatically tracked
end)

{:ok, _} = CrucibleTelemetry.stop_experiment(exp.id)

# Export for historical tracking
CrucibleTelemetry.export(exp.id, :csv,
  path: "benchmarks/gemini_2_flash_#{Date.utc_today()}.csv"
)
```

### 3. Hypothesis Testing

Test specific hypotheses about your system:

```elixir
{:ok, exp} = CrucibleTelemetry.start_experiment(
  name: "ensemble_reliability",
  hypothesis: "5-model ensemble achieves >99% reliability",
  condition: "ensemble_5x",
  tags: ["h1", "reliability"],
  sample_size: 1000
)

# ... collect 1000 samples ...

metrics = CrucibleTelemetry.calculate_metrics(exp.id)

# Test hypothesis
hypothesis_confirmed = metrics.reliability.success_rate > 0.99
IO.puts("Hypothesis #{if hypothesis_confirmed, do: "CONFIRMED", else: "REJECTED"}")
IO.puts("Success rate: #{metrics.reliability.success_rate * 100}%")
```

### 4. Cost Analysis

Track and optimize costs:

```elixir
{:ok, exp} = CrucibleTelemetry.start_experiment(
  name: "cost_optimization",
  tags: ["cost", "optimization"]
)

# ... run workload ...

metrics = CrucibleTelemetry.calculate_metrics(exp.id)

IO.puts("Total cost: $#{metrics.cost.total}")
IO.puts("Cost per 1M requests: $#{metrics.cost.cost_per_1m_requests}")

# Identify expensive requests
expensive_events = CrucibleTelemetry.Store.query(exp.id, %{})
  |> Enum.filter(&(&1.cost_usd > 0.01))
  |> Enum.sort_by(&(&1.cost_usd), :desc)
```

## API Reference

### TelemetryResearch

Main module with convenience functions.

- `start_experiment(opts)` - Start a new experiment
- `stop_experiment(experiment_id)` - Stop an experiment
- `get_experiment(experiment_id)` - Get experiment details
- `list_experiments()` - List all experiments
- `export(experiment_id, format, opts)` - Export data
- `calculate_metrics(experiment_id)` - Calculate metrics

### CrucibleTelemetry.Experiment

Experiment lifecycle management.

- `start(opts)` - Start experiment with options
- `stop(experiment_id)` - Stop experiment
- `get(experiment_id)` - Get experiment
- `list()` - List experiments
- `archive(experiment_id, opts)` - Archive to file/S3
- `cleanup(experiment_id, opts)` - Clean up resources

### CrucibleTelemetry.Store

Data storage and querying.

- `get_all(experiment_id)` - Get all events
- `query(experiment_id, filters)` - Query with filters
- `insert(experiment_id, event)` - Insert event (internal)
- `delete_experiment(experiment_id)` - Delete all data

### CrucibleTelemetry.Export

Export to various formats.

- `export(experiment_id, format, opts)` - Export data
- `export_multiple(experiment_ids, format, opts)` - Export multiple

### CrucibleTelemetry.Analysis

Statistical analysis and metrics.

- `calculate_metrics(experiment_id)` - Calculate all metrics
- `compare_experiments(experiment_ids)` - Compare experiments

## Examples

See the `examples/` directory for complete examples:

- `basic_usage.exs` - Basic workflow walkthrough
- `ab_testing.exs` - A/B testing with two experiments
- `custom_metrics.exs` - Custom event tracking

Run examples with:

```bash
cd apps/telemetry_research
mix run examples/basic_usage.exs
```

## Testing

Run the test suite:

```bash
cd apps/telemetry_research
mix test
```

Run with coverage:

```bash
mix test --cover
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│              TelemetryResearch                   │
│                                                  │
│  ┌────────────┐  ┌─────────┐  ┌──────────────┐ │
│  │ Experiment │  │ Handler │  │    Store     │ │
│  │  Manager   │  │ Pipeline│  │     ETS      │ │
│  └────────────┘  └─────────┘  └──────────────┘ │
│         │             │              │          │
│         └─────────────┴──────────────┘          │
│                       │                         │
│         ┌─────────────▼─────────────┐           │
│         │  Export      │  Analysis  │           │
│         │  CSV/JSON    │  Metrics   │           │
│         └──────────────┴────────────┘           │
└─────────────────────────────────────────────────┘
```

## Telemetry Events

TelemetryResearch listens for these standard events:

### req_llm Events

- `[:req_llm, :request, :start]` - LLM request started
- `[:req_llm, :request, :stop]` - LLM request completed
- `[:req_llm, :request, :exception]` - LLM request failed

### Ensemble Events

- `[:ensemble, :prediction, :start]` - Ensemble prediction started
- `[:ensemble, :prediction, :stop]` - Ensemble prediction completed
- `[:ensemble, :vote, :completed]` - Voting completed

### Hedging Events

- `[:hedging, :request, :start]` - Hedging request started
- `[:hedging, :request, :duplicated]` - Request duplicated
- `[:hedging, :request, :stop]` - Hedging request completed

### Causal Trace Events

- `[:causal_trace, :event, :created]` - Reasoning event created

### Altar Tool Events

- `[:altar, :tool, :start]` - Tool invocation started
- `[:altar, :tool, :stop]` - Tool invocation completed

## Performance

TelemetryResearch is designed for minimal overhead:

- **Event handling**: <1μs per event (in-memory ETS insert)
- **Storage**: Up to 1M events in memory (~100-500MB depending on metadata)
- **Query**: Fast filtering with ETS ordered_set
- **Export**: Streaming to avoid memory spikes

## Roadmap

- [ ] PostgreSQL backend for persistent storage
- [ ] TimescaleDB support for time-series optimization
- [ ] Parquet export format
- [ ] LiveView dashboard for real-time monitoring
- [ ] Statistical hypothesis testing (t-test, chi-square)
- [ ] Continuous aggregates
- [ ] S3 archival support
- [ ] Multi-node distributed experiments

## License

MIT License - see [LICENSE](https://github.com/North-Shore-AI/crucible_telemetry/blob/main/LICENSE) file for details

