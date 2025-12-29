<p align="center">
  <img src="assets/crucible_telemetry.svg" alt="CrucibleTelemetry" width="150"/>
</p>

# CrucibleTelemetry

[![Hex.pm](https://img.shields.io/hexpm/v/crucible_telemetry.svg)](https://hex.pm/packages/crucible_telemetry)
[![Elixir](https://img.shields.io/badge/elixir-1.18+-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/otp-28+-blue.svg)](https://www.erlang.org)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/crucible_telemetry)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> **Research-grade instrumentation and metrics collection for AI/ML experiments in Elixir.**

CrucibleTelemetry provides specialized observability for rigorous scientific experimentation, going beyond standard production telemetry with features designed for AI/ML research workflows.

## Features

- **Experiment Isolation** — Run multiple experiments concurrently without cross-contamination
- **Centralized Event Registry** — Programmatic access to all telemetry event definitions
- **Rich Metadata Enrichment** — Automatic context, timestamps, and custom tags
- **ML Training Support** — Track epochs, batches, checkpoints, and training metrics
- **MetricsStore Port** — Pluggable adapter system for persisting training metrics
- **Inference Monitoring** — Model deployment and inference telemetry
- **Pipeline Tracking** — Framework stage execution observability
- **Streaming Metrics** — Real-time latency/cost/reliability stats with O(1) memory
- **Time-Window Queries** — Fetch last N events or ranges without full rescans
- **Multiple Export Formats** — CSV, JSON Lines for Python, R, Julia, Excel
- **Pause/Resume Lifecycle** — Temporarily halt collection without losing state

## Installation

```elixir
def deps do
  [
    {:crucible_telemetry, "~> 0.4.0"}
  ]
end
```

## Quick Start

```elixir
# Start an experiment
{:ok, experiment} = CrucibleTelemetry.start_experiment(
  name: "bert_finetuning",
  hypothesis: "Fine-tuned BERT achieves >95% accuracy",
  tags: ["training", "bert", "nlp"]
)

# Events are automatically collected via telemetry
# Your existing :telemetry.execute() calls work unchanged

# Stop and analyze
{:ok, _} = CrucibleTelemetry.stop_experiment(experiment.id)

metrics = CrucibleTelemetry.calculate_metrics(experiment.id)
# => %{latency: %{mean: 150.5, p95: 250.0}, cost: %{total: 0.025}, ...}

# Export for analysis
{:ok, path} = CrucibleTelemetry.export(experiment.id, :csv)
```

## Event Registry

CrucibleTelemetry provides a centralized registry of all supported telemetry events:

```elixir
# Get all standard events
CrucibleTelemetry.Events.standard_events()

# Get events by category
CrucibleTelemetry.Events.training_events()
CrucibleTelemetry.Events.deployment_events()
CrucibleTelemetry.Events.framework_events()
CrucibleTelemetry.Events.llm_events()

# Get events organized by category
CrucibleTelemetry.Events.events_by_category()
# => %{llm: [...], training: [...], deployment: [...], ...}

# Get info about a specific event
CrucibleTelemetry.Events.event_info([:crucible_train, :epoch, :stop])
# => %{category: :training, description: "Epoch completed with metrics"}
```

## Telemetry Events

### LLM Events (req_llm)

| Event | Description |
|-------|-------------|
| `[:req_llm, :request, :start]` | LLM request started |
| `[:req_llm, :request, :stop]` | LLM request completed |
| `[:req_llm, :request, :exception]` | LLM request failed |

### Training Events (crucible_train)

| Event | Description | Enriched Fields |
|-------|-------------|-----------------|
| `[:crucible_train, :training, :start]` | Training job started | — |
| `[:crucible_train, :training, :stop]` | Training job completed | — |
| `[:crucible_train, :epoch, :start]` | Epoch started | `epoch` |
| `[:crucible_train, :epoch, :stop]` | Epoch completed | `epoch`, `loss`, `accuracy`, `learning_rate` |
| `[:crucible_train, :batch, :stop]` | Batch completed | `epoch`, `batch`, `loss`, `gradient_norm` |
| `[:crucible_train, :checkpoint, :saved]` | Checkpoint saved | `epoch`, `checkpoint_path` |

### Deployment Events (crucible_deployment)

| Event | Description | Enriched Fields |
|-------|-------------|-----------------|
| `[:crucible_deployment, :inference, :start]` | Inference started | `model_name`, `model_version` |
| `[:crucible_deployment, :inference, :stop]` | Inference completed | `input_size`, `output_size`, `batch_size` |
| `[:crucible_deployment, :inference, :exception]` | Inference failed | — |

### Framework Events (crucible_framework)

| Event | Description | Enriched Fields |
|-------|-------------|-----------------|
| `[:crucible_framework, :pipeline, :start]` | Pipeline started | `pipeline_id` |
| `[:crucible_framework, :pipeline, :stop]` | Pipeline completed | `pipeline_id` |
| `[:crucible_framework, :stage, :start]` | Stage started | `stage_name`, `stage_index` |
| `[:crucible_framework, :stage, :stop]` | Stage completed | `stage_name`, `stage_index` |

### Other Events

- `[:ensemble, :prediction, :start|stop]` — Ensemble predictions
- `[:ensemble, :vote, :completed]` — Voting results
- `[:hedging, :request, :start|duplicated|stop]` — Request hedging
- `[:causal_trace, :event, :created]` — Reasoning traces
- `[:altar, :tool, :start|stop]` — Tool invocations

## Training Integration

Track ML training jobs by emitting standard training events:

```elixir
defmodule MyTrainer do
  def train(model, data, epochs) do
    :telemetry.execute(
      [:crucible_train, :training, :start],
      %{system_time: System.system_time()},
      %{model_name: "bert-base", config: %{epochs: epochs}}
    )

    for epoch <- 1..epochs do
      :telemetry.execute(
        [:crucible_train, :epoch, :start],
        %{system_time: System.system_time()},
        %{epoch: epoch}
      )

      {loss, accuracy} = train_epoch(model, data)

      :telemetry.execute(
        [:crucible_train, :epoch, :stop],
        %{duration: epoch_duration, loss: loss, accuracy: accuracy},
        %{epoch: epoch, learning_rate: get_lr()}
      )
    end

    :telemetry.execute(
      [:crucible_train, :training, :stop],
      %{duration: total_duration},
      %{final_loss: final_loss}
    )
  end
end
```

## MetricsStore Port

The MetricsStore port provides a pluggable adapter system for persisting training metrics to various backends.

### Basic Usage

```elixir
alias CrucibleTelemetry.Ports.MetricsStore
alias CrucibleTelemetry.Adapters.JSONLMetrics

# Create an adapter reference
adapter = {JSONLMetrics, [path: "/tmp/training/metrics.jsonl"]}

# Record metrics during training
MetricsStore.record(adapter, "run_123", :loss, 2.5, step: 0)
MetricsStore.record(adapter, "run_123", :loss, 1.8, step: 100)
MetricsStore.record(adapter, "run_123", :lr, 0.001, step: 100, metadata: %{epoch: 1})

# Flush any buffered data
MetricsStore.flush(adapter, "run_123")

# Read metrics back
{:ok, entries} = MetricsStore.read(adapter, "run_123")
```

### JSONLMetrics Adapter

The built-in JSONL adapter writes metrics as newline-delimited JSON:

```json
{"run_id":"run_123","metric":"loss","value":2.5,"step":0,"timestamp":"2025-12-28T10:30:00Z","metadata":{}}
{"run_id":"run_123","metric":"loss","value":1.8,"step":100,"timestamp":"2025-12-28T10:31:00Z","metadata":{}}
```

### Custom Adapters

Implement the `CrucibleTelemetry.Ports.MetricsStore` behaviour:

```elixir
defmodule MyApp.Adapters.PostgresMetrics do
  @behaviour CrucibleTelemetry.Ports.MetricsStore

  @impl true
  def record(opts, run_id, metric_name, value, record_opts) do
    # Insert into database
    :ok
  end

  @impl true
  def flush(opts, run_id), do: :ok

  @impl true
  def read(opts, run_id) do
    # Query database
    {:ok, entries}
  end
end
```

## Metrics & Analysis

```elixir
metrics = CrucibleTelemetry.calculate_metrics(experiment.id)

# Latency
metrics.latency.mean       # Average latency
metrics.latency.p95        # 95th percentile
metrics.latency.p99        # 99th percentile

# Cost
metrics.cost.total                  # Total cost in USD
metrics.cost.cost_per_1m_requests   # Projected cost for 1M requests

# Reliability
metrics.reliability.success_rate    # Success rate (0.0-1.0)
metrics.reliability.sla_99          # Meets 99% SLA?

# Tokens
metrics.tokens.total_prompt         # Total prompt tokens
metrics.tokens.mean_total           # Average tokens per request
```

## Streaming Metrics

Real-time metrics update on every collected event:

```elixir
# Get live metrics
metrics = CrucibleTelemetry.StreamingMetrics.get_metrics(experiment.id)

# Reset accumulators
CrucibleTelemetry.StreamingMetrics.reset(experiment.id)

# Stop streaming
CrucibleTelemetry.StreamingMetrics.stop(experiment.id)
```

## Time-Window Queries

```elixir
alias CrucibleTelemetry.Store

# Last 5 minutes
Store.query_window(experiment.id, {:last, 5, :minutes})

# Last 200 events
Store.query_window(experiment.id, {:last_n, 200})

# Specific time range with filter
Store.query_window(experiment.id, {:range, t_start, t_end}, &(&1.success))

# Sliding window metrics (5-min windows, 1-min step)
Store.windowed_metrics(experiment.id, 5 * 60_000_000, 60_000_000)
```

## Pause & Resume

```elixir
{:ok, paused} = CrucibleTelemetry.pause_experiment(experiment.id)
# ... maintenance ...
{:ok, resumed} = CrucibleTelemetry.resume_experiment(experiment.id)

CrucibleTelemetry.paused?(experiment.id)  # => true/false
```

## Export Formats

### CSV

```elixir
{:ok, path} = CrucibleTelemetry.export(experiment.id, :csv,
  path: "results/experiment.csv"
)
```

### JSON Lines

```elixir
{:ok, path} = CrucibleTelemetry.export(experiment.id, :jsonl,
  path: "results/experiment.jsonl"
)
```

## A/B Testing Example

```elixir
# Control group
{:ok, control} = CrucibleTelemetry.start_experiment(
  name: "control_single_model",
  condition: "control",
  tags: ["ab_test"]
)

# Treatment group
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

## API Reference

### CrucibleTelemetry

| Function | Description |
|----------|-------------|
| `start_experiment/1` | Start a new experiment |
| `stop_experiment/1` | Stop an experiment |
| `pause_experiment/1` | Pause data collection |
| `resume_experiment/1` | Resume data collection |
| `paused?/1` | Check if experiment is paused |
| `get_experiment/1` | Get experiment details |
| `list_experiments/0` | List all experiments |
| `export/3` | Export data to file |
| `calculate_metrics/1` | Calculate comprehensive metrics |

### CrucibleTelemetry.Events

| Function | Description |
|----------|-------------|
| `standard_events/0` | All standard telemetry events |
| `training_events/0` | Training-related events |
| `deployment_events/0` | Deployment-related events |
| `framework_events/0` | Framework-related events |
| `llm_events/0` | LLM-related events |
| `events_by_category/0` | Events organized by category |
| `event_info/1` | Get info about a specific event |

### CrucibleTelemetry.Store

| Function | Description |
|----------|-------------|
| `get_all/1` | Get all events |
| `query/2` | Query with filters |
| `query_window/3` | Time-window queries |
| `windowed_metrics/3` | Sliding window metrics |

### CrucibleTelemetry.Ports.MetricsStore

| Function | Description |
|----------|-------------|
| `record/5` | Record a metric value at a step |
| `flush/2` | Flush buffered metrics to storage |
| `read/2` | Read all metrics for a run |

## Performance

- **Event handling**: <1μs per event (in-memory ETS insert)
- **Storage**: Up to 1M events in memory (~100-500MB)
- **Query**: Fast filtering with ETS ordered_set
- **Export**: Streaming to avoid memory spikes
- **Streaming metrics**: O(1) space using online algorithms

## Testing

```bash
mix test
mix test --cover
```

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

MIT License — see [LICENSE](LICENSE) for details.
