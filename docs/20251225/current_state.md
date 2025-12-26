# CrucibleTelemetry Current State Documentation

**Date:** 2025-12-25
**Version:** 0.2.1
**Package:** crucible_telemetry (formerly telemetry_research)

## Overview

CrucibleTelemetry is a research-grade instrumentation and metrics collection library for AI/ML experiments in Elixir. It provides specialized observability for rigorous scientific experimentation with features designed for AI/ML research.

## Architecture

```
+---------------------------------------------------------------+
|                      CrucibleTelemetry                        |
|                                                               |
|  +---------------+  +---------------+  +-----------------+    |
|  |  Experiment   |  |    Handler    |  |      Store      |    |
|  |   Manager     |  |    Pipeline   |  |       ETS       |    |
|  +---------------+  +---------------+  +-----------------+    |
|         |                 |                    |              |
|         +--------+--------+--------------------+              |
|                  |                                            |
|         +--------v----------+  +-------------------+          |
|         | StreamingMetrics  |  |     Analysis      |          |
|         |  (GenServer)      |  |     Metrics       |          |
|         +-------------------+  +-------------------+          |
|                  |                     |                      |
|         +--------v---------+-----------+                      |
|         |     Export       |                                  |
|         |   CSV / JSONL    |                                  |
|         +------------------+                                  |
+---------------------------------------------------------------+
```

## Module Structure

### Core Modules

| Module | File | Purpose | Lines |
|--------|------|---------|-------|
| `CrucibleTelemetry` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research.ex` | Main API facade, delegates to submodules | 1-137 |
| `CrucibleTelemetry.Application` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/application.ex` | OTP Application, ETS table initialization | 1-29 |
| `CrucibleTelemetry.Experiment` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/experiment.ex` | Experiment lifecycle (start/stop/pause/resume) | 1-368 |
| `CrucibleTelemetry.Handler` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/handler.ex` | Telemetry event handler, event enrichment | 1-153 |
| `CrucibleTelemetry.Store` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/store.ex` | Storage interface, backend selection | 1-124 |
| `CrucibleTelemetry.Store.ETS` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/store/ets.ex` | ETS storage backend implementation | 1-289 |
| `CrucibleTelemetry.StreamingMetrics` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/streaming_metrics.ex` | Real-time streaming metrics (GenServer) | 1-314 |
| `CrucibleTelemetry.Analysis` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/analysis.ex` | Metrics calculation, experiment comparison | 1-315 |
| `CrucibleTelemetry.Export` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/export.ex` | Export coordinator | 1-81 |
| `CrucibleTelemetry.Export.CSV` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/export/csv.ex` | CSV export format | 1-176 |
| `CrucibleTelemetry.Export.JSONL` | `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/export/jsonl.ex` | JSON Lines export format | 1-53 |

## Key Functions by Module

### CrucibleTelemetry (Main API)

| Function | Description | Line |
|----------|-------------|------|
| `start_experiment/1` | Start a new experiment | 64 |
| `stop_experiment/1` | Stop an experiment | 69 |
| `get_experiment/1` | Get experiment by ID | 74 |
| `list_experiments/0` | List all experiments | 79 |
| `export/3` | Export experiment data | 95-97 |
| `calculate_metrics/1` | Calculate metrics | 111-113 |
| `pause_experiment/1` | Pause data collection | 121 |
| `resume_experiment/1` | Resume data collection | 128 |
| `is_paused?/1` | Check if experiment is paused | 135 |

### CrucibleTelemetry.Experiment

| Function | Description | Line |
|----------|-------------|------|
| `start/1` | Create isolated experiment with handlers | 70-101 |
| `stop/1` | Stop experiment, detach handlers | 106-122 |
| `pause/1` | Pause experiment, detach handlers | 137-167 |
| `resume/1` | Resume experiment, reattach handlers | 179-208 |
| `is_paused?/1` | Check pause status | 222-227 |
| `get/1` | Retrieve experiment by ID | 232-237 |
| `list/0` | List all experiments | 242-245 |
| `archive/2` | Archive to file | 250-268 |
| `cleanup/2` | Clean up resources | 273-291 |

### CrucibleTelemetry.Handler

| Function | Description | Line |
|----------|-------------|------|
| `handle_event/4` | Main telemetry event handler | 18-34 |
| `enrich_event/4` | Add experiment context to events | 39-69 |

### CrucibleTelemetry.Store

| Function | Description | Line |
|----------|-------------|------|
| `init_experiment/1` | Initialize storage for experiment | 30-33 |
| `insert/2` | Insert event | 38-41 |
| `get_all/1` | Get all events | 46-49 |
| `query/2` | Query with filters | 54-57 |
| `query_window/3` | Time-window queries | 81-84 |
| `windowed_metrics/3` | Sliding window metrics | 96-99 |
| `delete_experiment/1` | Delete experiment data | 104-107 |

### CrucibleTelemetry.Store.ETS

| Function | Description | Line |
|----------|-------------|------|
| `init_experiment/1` | Create ETS table | 22-35 |
| `insert/2` | Insert with timestamp key | 38-52 |
| `get_all/1` | Get all, sorted by timestamp | 55-64 |
| `query/2` | Filter events | 67-70 |
| `query_window/3` | Time/count based queries | 73-102 |
| `windowed_metrics/3` | Sliding window aggregations | 105-120 |
| `delete_experiment/1` | Delete ETS table | 123-130 |

### CrucibleTelemetry.StreamingMetrics

| Function | Description | Line |
|----------|-------------|------|
| `start/1` | Start streaming metrics server | 64-70 |
| `get_metrics/1` | Get current streaming metrics | 88-93 |
| `update/2` | Update with new event | 101-104 |
| `reset/1` | Reset metrics to initial state | 112-116 |
| `stop/1` | Stop streaming metrics server | 122-127 |

### CrucibleTelemetry.Analysis

| Function | Description | Line |
|----------|-------------|------|
| `calculate_metrics/1` | Comprehensive metrics calculation | 29-40 |
| `compare_experiments/1` | Compare multiple experiments | 57-67 |

## Telemetry Events Captured

The library attaches handlers to these standard telemetry events:

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

## Experiment Data Structure

```elixir
%CrucibleTelemetry.Experiment{
  id: String.t(),                    # Unique experiment ID
  name: String.t(),                  # Human-readable name
  hypothesis: String.t() | nil,      # What you're testing
  condition: String.t(),             # Experimental condition
  metadata: map(),                   # Custom metadata
  tags: list(String.t()),            # Tags for categorization
  started_at: DateTime.t(),          # Start timestamp
  stopped_at: DateTime.t() | nil,    # Stop timestamp
  paused_at: DateTime.t() | nil,     # Pause timestamp
  status: :running | :paused | :stopped | :archived,
  sample_size: integer() | nil,      # Target sample size
  metrics_config: map(),             # Metrics to collect
  storage_backend: atom(),           # :ets or :postgres
  pause_count: non_neg_integer()     # Number of pause/resume cycles
}
```

## Enriched Event Structure

```elixir
%{
  # Event identity
  event_id: String.t(),              # Unique event ID
  event_name: list(atom()),          # Telemetry event name
  timestamp: integer(),              # Microsecond timestamp

  # Experiment context
  experiment_id: String.t(),
  experiment_name: String.t(),
  condition: String.t(),
  tags: list(String.t()),

  # Original data
  measurements: map(),
  metadata: map(),

  # Computed fields
  latency_ms: float() | nil,         # Calculated from duration
  cost_usd: float() | nil,           # Calculated from tokens/model
  success: boolean() | nil,          # Determined from response/error

  # Additional enrichment
  session_id: String.t() | nil,
  user_id: String.t() | nil,
  sample_id: String.t() | nil,
  cohort: String.t() | nil,
  model: String.t() | nil,
  provider: atom() | nil
}
```

## Metrics Calculated

### Summary Metrics
- Total events
- Time range (start/end)
- Duration in seconds
- Event types count

### Latency Metrics
- Count, mean, median
- Standard deviation
- Min, max
- Percentiles: p50, p90, p95, p99

### Cost Metrics
- Total cost
- Count
- Mean per request
- Median per request
- Cost per 1K/1M requests

### Reliability Metrics
- Total requests
- Successful/failed counts
- Success/failure rate
- SLA compliance (99%, 99.9%, 99.99%)

### Token Metrics
- Count
- Total prompt/completion/all tokens
- Mean prompt/completion/all tokens

### Event Type Metrics
- Count per event type

## Streaming Metrics (Real-time)

Uses Welford's online algorithm for:
- Mean, variance, std_dev (O(1) memory)
- Min, max
- Count
- Success rate

## Export Formats

### CSV
- Flattened nested structures
- Proper CSV escaping
- Suitable for Excel, pandas, R

### JSON Lines
- One JSON object per line
- Streaming-friendly
- Perfect for jq processing

## Dependencies

```elixir
{:crucible_ir, "~> 0.1.1"},     # Shared IR definitions
{:jason, "~> 1.4"},              # JSON encoding
{:telemetry, "~> 1.3"},          # Core telemetry
```

## Test Coverage

| Test File | Purpose | Tests |
|-----------|---------|-------|
| `test/telemetry_research/analysis_test.exs` | Metrics calculation | ~15 |
| `test/telemetry_research/handler_test.exs` | Event handling | ~8 |
| `test/telemetry_research/store/ets_test.exs` | ETS storage | ~12 |
| `test/telemetry_research/export_test.exs` | Export formats | ~10 |
| `test/telemetry_research/pause_resume_test.exs` | Pause/resume lifecycle | ~15 |

## Examples

| Example | Purpose |
|---------|---------|
| `examples/basic_usage.exs` | Complete workflow walkthrough |
| `examples/ab_testing.exs` | A/B testing with two experiments |
| `examples/custom_metrics.exs` | Custom event tracking |

## Performance Characteristics

- **Event handling**: <1us per event (in-memory ETS insert)
- **Storage**: Up to 1M events in memory (~100-500MB)
- **Query**: Fast filtering with ETS ordered_set
- **Export**: Streaming to avoid memory spikes
- **Streaming metrics**: O(1) space using online algorithms

## Configuration Options

### Experiment Start Options
- `:name` (required) - Experiment name
- `:hypothesis` - What you're testing
- `:condition` - Experimental condition (default: "default")
- `:tags` - List of tags (default: [])
- `:metadata` - Additional context (default: %{})
- `:sample_size` - Target sample size
- `:metrics_config` - Which metrics to collect
- `:storage_backend` - Storage backend (:ets, default: :ets)

### Export Options
- `:path` - Output file path (default: auto-generated)
- `:flatten` - Flatten nested structures (default: true, CSV only)
- `:pretty` - Pretty print JSON (default: false, JSONL only)
