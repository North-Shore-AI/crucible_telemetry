# CrucibleTelemetry Implementation Prompt

**Date:** 2025-12-25
**Target Version:** 0.3.0

## Overview

You are tasked with enhancing crucible_telemetry, a research-grade instrumentation and metrics collection library for AI/ML experiments in Elixir. This document provides everything you need to understand the codebase and implement the required enhancements.

---

## Required Reading (Full Paths)

### Core Source Files

Read these files in order to understand the current implementation:

1. **Main API and Configuration**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/mix.exs` (137 lines) - Project configuration, dependencies
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research.ex` (137 lines) - Main API module

2. **Experiment Lifecycle**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/experiment.ex` (368 lines) - Experiment management
   - Key functions: `start/1` (line 70), `stop/1` (line 106), `pause/1` (line 137), `resume/1` (line 179)

3. **Event Handling**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/handler.ex` (153 lines) - Telemetry event handler
   - Key functions: `handle_event/4` (line 18), `enrich_event/4` (line 39)

4. **Storage Layer**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/store.ex` (124 lines) - Storage interface/behavior
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/store/ets.ex` (289 lines) - ETS implementation
   - Key functions: `query_window/3` (line 73), `windowed_metrics/3` (line 105)

5. **Streaming Metrics**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/streaming_metrics.ex` (314 lines) - Real-time metrics GenServer
   - Uses Welford's algorithm: `update_streaming_stat/2` (line 217)

6. **Analysis**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/analysis.ex` (315 lines) - Metrics calculation
   - Key functions: `calculate_metrics/1` (line 29), `compare_experiments/1` (line 57)

7. **Export**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/export.ex` (81 lines) - Export coordinator
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/export/csv.ex` (176 lines) - CSV exporter
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/export/jsonl.ex` (53 lines) - JSONL exporter

8. **Application**
   - `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/application.ex` (29 lines) - OTP Application

### Test Files

Read tests to understand expected behavior:

- `/home/home/p/g/North-Shore-AI/crucible_telemetry/test/telemetry_research/analysis_test.exs` (218 lines)
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/test/telemetry_research/handler_test.exs` (133 lines)
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/test/telemetry_research/store/ets_test.exs` (189 lines)
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/test/telemetry_research/export_test.exs` (142 lines)
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/test/telemetry_research/pause_resume_test.exs` (171 lines)

### Design Documents

Read for enhancement requirements:

- `/home/home/p/g/North-Shore-AI/crucible_telemetry/docs/20251125/enhancements_design.md` (676 lines) - Detailed enhancement specifications
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/.implementation_summary.md` (246 lines) - Implementation history

### Examples

Read for usage patterns:

- `/home/home/p/g/North-Shore-AI/crucible_telemetry/examples/basic_usage.exs` (122 lines)
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/examples/ab_testing.exs` (185 lines)
- `/home/home/p/g/North-Shore-AI/crucible_telemetry/examples/custom_metrics.exs` (171 lines)

### Related Ecosystem Files

Read to understand integration points:

- `/home/home/p/g/North-Shore-AI/crucible_framework/mix.exs` (222 lines) - Framework dependencies
- `/home/home/p/g/North-Shore-AI/crucible_train/mix.exs` (110 lines) - Training dependencies
- `/home/home/p/g/North-Shore-AI/crucible_deployment/mix.exs` (50 lines) - Deployment dependencies

---

## Current Module Structure

```
lib/
  telemetry_research.ex                   # Main API (137 lines)
  telemetry_research/
    application.ex                        # OTP Application (29 lines)
    experiment.ex                         # Experiment lifecycle (368 lines)
    handler.ex                            # Event handling (153 lines)
    store.ex                              # Storage interface (124 lines)
    store/
      ets.ex                              # ETS backend (289 lines)
    streaming_metrics.ex                  # Real-time metrics (314 lines)
    analysis.ex                           # Metrics calculation (315 lines)
    export.ex                             # Export coordinator (81 lines)
    export/
      csv.ex                              # CSV exporter (176 lines)
      jsonl.ex                            # JSONL exporter (53 lines)
```

---

## Integration with Crucible Ecosystem

### crucible_framework Integration

crucible_framework is the main orchestration library. It currently does NOT include crucible_telemetry as a dependency. To integrate:

1. Add to crucible_framework's `mix.exs`:
```elixir
{:crucible_telemetry, "~> 0.3.0", optional: true}
```

2. Emit standard telemetry events from framework pipelines:
```elixir
# In CrucibleFramework.Pipeline
:telemetry.execute(
  [:crucible_framework, :pipeline, :start],
  %{system_time: System.system_time()},
  %{pipeline_id: id, config: config}
)
```

### crucible_train Integration

crucible_train manages ML training jobs. It has telemetry dependency but no integration. To integrate:

1. Add standard training events:
```elixir
[:crucible_train, :training, :start]    # Training job started
[:crucible_train, :training, :stop]     # Training job completed
[:crucible_train, :epoch, :start]       # Epoch started
[:crucible_train, :epoch, :stop]        # Epoch completed with metrics
[:crucible_train, :batch, :stop]        # Batch completed with loss
[:crucible_train, :checkpoint, :saved]  # Checkpoint saved
```

2. Add to crucible_telemetry's handler.ex attach list (line 296-309):
```elixir
events = [
  # ... existing events ...
  [:crucible_train, :training, :start],
  [:crucible_train, :training, :stop],
  [:crucible_train, :epoch, :stop],
  [:crucible_train, :batch, :stop],
  [:crucible_train, :checkpoint, :saved]
]
```

### crucible_deployment Integration

crucible_deployment manages model serving. To integrate:

1. Add inference events:
```elixir
[:crucible_deployment, :inference, :start]
[:crucible_deployment, :inference, :stop]
[:crucible_deployment, :inference, :exception]
[:crucible_deployment, :health_check, :completed]
[:crucible_deployment, :model, :loaded]
[:crucible_deployment, :model, :unloaded]
```

---

## Standard Telemetry Events

All crucible packages should emit standardized events. Define these in crucible_ir:

### Event Schema (propose for crucible_ir)

```elixir
defmodule CrucibleIR.Telemetry.Event do
  @type t :: %{
    event_name: list(atom()),
    measurements: map(),
    metadata: map(),
    timestamp: integer(),
    correlation_id: String.t() | nil
  }
end
```

### Standard Event Names

| Package | Event | Description |
|---------|-------|-------------|
| crucible_framework | `[:crucible_framework, :pipeline, :start\|stop]` | Pipeline execution |
| crucible_framework | `[:crucible_framework, :stage, :start\|stop]` | Stage execution |
| crucible_train | `[:crucible_train, :training, :start\|stop]` | Training jobs |
| crucible_train | `[:crucible_train, :epoch, :stop]` | Epoch completion |
| crucible_train | `[:crucible_train, :batch, :stop]` | Batch metrics |
| crucible_deployment | `[:crucible_deployment, :inference, :start\|stop]` | Inference requests |
| crucible_ensemble | `[:ensemble, :prediction, :start\|stop]` | Ensemble predictions |
| crucible_hedging | `[:hedging, :request, :start\|stop]` | Hedging requests |
| crucible_xai | `[:crucible_xai, :explanation, :generated]` | XAI explanations |
| crucible_adversary | `[:crucible_adversary, :attack, :executed]` | Adversarial attacks |

---

## TDD Approach

### Step 1: Write Tests First

For each new feature, write comprehensive tests before implementation:

```elixir
# test/telemetry_research/new_feature_test.exs
defmodule CrucibleTelemetry.NewFeatureTest do
  use ExUnit.Case, async: false

  setup do
    :ets.delete_all_objects(:crucible_telemetry_experiments)
    {:ok, experiment} = CrucibleTelemetry.Experiment.start(name: "test")

    on_exit(fn ->
      CrucibleTelemetry.Experiment.cleanup(experiment.id)
    end)

    %{experiment: experiment}
  end

  describe "new_feature/1" do
    test "does expected behavior", %{experiment: experiment} do
      # Arrange
      # Act
      # Assert
    end

    test "handles edge case", %{experiment: experiment} do
      # Arrange
      # Act
      # Assert
    end

    test "returns error for invalid input" do
      # Arrange
      # Act
      # Assert
    end
  end
end
```

### Step 2: Run Tests (Should Fail)

```bash
cd /home/home/p/g/North-Shore-AI/crucible_telemetry
mix test test/telemetry_research/new_feature_test.exs
```

### Step 3: Implement Feature

Implement the minimum code to pass tests.

### Step 4: Refactor and Document

Add @doc, @spec, and clean up code.

### Step 5: Verify Quality

```bash
mix format
mix credo --strict
mix dialyzer
mix test
```

---

## Quality Requirements

### All Code Must:

1. **Compile without warnings**
   ```bash
   mix compile --warnings-as-errors
   ```

2. **Pass Dialyzer**
   ```bash
   mix dialyzer
   ```
   - All public functions must have @spec
   - Custom types should be defined with @type

3. **Pass Credo strict**
   ```bash
   mix credo --strict
   ```
   - No code smells
   - Proper naming conventions
   - Documentation coverage

4. **Pass all tests**
   ```bash
   mix test
   ```
   - Maintain >90% coverage
   - Test edge cases
   - Test error conditions

5. **Be properly formatted**
   ```bash
   mix format --check-formatted
   ```

### Documentation Requirements

1. **@moduledoc** for every module
2. **@doc** for every public function
3. **@spec** for every public function
4. **Examples** in @doc where appropriate
5. **Update README.md** for new features

---

## Implementation Tasks

### Priority 1: Add Training Events Support

1. Update handler.ex to attach to training events (line 296-309)
2. Update enrich_event to extract training-specific metrics
3. Add tests for training event handling
4. Update README with training integration docs

### Priority 2: Add Standard Event Registry

1. Create `lib/telemetry_research/events.ex`:
   ```elixir
   defmodule CrucibleTelemetry.Events do
     @moduledoc """
     Standard telemetry event definitions for the Crucible ecosystem.
     """

     @standard_events [
       # req_llm
       [:req_llm, :request, :start],
       [:req_llm, :request, :stop],
       [:req_llm, :request, :exception],
       # ensemble
       [:ensemble, :prediction, :start],
       [:ensemble, :prediction, :stop],
       [:ensemble, :vote, :completed],
       # hedging
       [:hedging, :request, :start],
       [:hedging, :request, :duplicated],
       [:hedging, :request, :stop],
       # training
       [:crucible_train, :training, :start],
       [:crucible_train, :training, :stop],
       [:crucible_train, :epoch, :start],
       [:crucible_train, :epoch, :stop],
       [:crucible_train, :batch, :stop],
       [:crucible_train, :checkpoint, :saved],
       # deployment
       [:crucible_deployment, :inference, :start],
       [:crucible_deployment, :inference, :stop],
       [:crucible_deployment, :inference, :exception],
       # framework
       [:crucible_framework, :pipeline, :start],
       [:crucible_framework, :pipeline, :stop],
       [:crucible_framework, :stage, :start],
       [:crucible_framework, :stage, :stop],
       # trace
       [:causal_trace, :event, :created],
       # tools
       [:altar, :tool, :start],
       [:altar, :tool, :stop]
     ]

     def standard_events, do: @standard_events

     def training_events do
       Enum.filter(@standard_events, fn [prefix | _] ->
         prefix == :crucible_train
       end)
     end

     def deployment_events do
       Enum.filter(@standard_events, fn [prefix | _] ->
         prefix == :crucible_deployment
       end)
     end
   end
   ```

2. Update experiment.ex to use this registry

### Priority 3: PostgreSQL Backend

1. Create `lib/telemetry_research/store/postgres.ex`
2. Implement Store behaviour
3. Add migration for events table
4. Add configuration for connection
5. Add tests

### Priority 4: Parquet Export

1. Add {:parquet, "~> 0.x"} dependency
2. Create `lib/telemetry_research/export/parquet.ex`
3. Update Export.export/3 to handle :parquet format
4. Add tests

### Priority 5: Anomaly Detection

1. Create `lib/telemetry_research/anomaly_detection.ex`
2. Implement Z-score method
3. Implement IQR method
4. Implement streaming detection
5. Integrate with StreamingMetrics
6. Add tests

---

## File Templates

### New Module Template

```elixir
defmodule CrucibleTelemetry.NewModule do
  @moduledoc """
  Brief description of what this module does.

  ## Features

  - Feature 1
  - Feature 2

  ## Examples

      iex> CrucibleTelemetry.NewModule.function()
      :ok
  """

  @type t :: %{
    field: type()
  }

  @doc """
  Brief description.

  ## Parameters

  - `param1` - Description
  - `param2` - Description

  ## Returns

  - `{:ok, result}` - On success
  - `{:error, reason}` - On failure

  ## Examples

      iex> CrucibleTelemetry.NewModule.function(:param)
      {:ok, result}
  """
  @spec function(atom()) :: {:ok, term()} | {:error, term()}
  def function(param) do
    # Implementation
  end
end
```

### New Test Template

```elixir
defmodule CrucibleTelemetry.NewModuleTest do
  use ExUnit.Case, async: false

  alias CrucibleTelemetry.NewModule

  setup do
    # Common setup
    :ok
  end

  describe "function/1" do
    test "returns expected result" do
      assert {:ok, _} = NewModule.function(:param)
    end

    test "handles invalid input" do
      assert {:error, _} = NewModule.function(:invalid)
    end
  end
end
```

---

## Verification Checklist

Before submitting any changes:

- [ ] All tests pass: `mix test`
- [ ] No compiler warnings: `mix compile --warnings-as-errors`
- [ ] Dialyzer passes: `mix dialyzer`
- [ ] Credo strict passes: `mix credo --strict`
- [ ] Code is formatted: `mix format --check-formatted`
- [ ] New features have tests
- [ ] New functions have @doc and @spec
- [ ] README.md is updated
- [ ] Examples are updated if needed

---

## Commands Reference

```bash
# Navigate to project
cd /home/home/p/g/North-Shore-AI/crucible_telemetry

# Get dependencies
mix deps.get

# Compile
mix compile

# Run tests
mix test

# Run tests with coverage
mix test --cover

# Format code
mix format

# Check formatting
mix format --check-formatted

# Run credo
mix credo --strict

# Run dialyzer
mix dialyzer

# Generate docs
mix docs

# Run examples
mix run examples/basic_usage.exs
```

---

## Contact and Resources

- **Repository:** https://github.com/North-Shore-AI/crucible_telemetry
- **Design Docs:** `/home/home/p/g/North-Shore-AI/crucible_telemetry/docs/`
- **Related Projects:** `/home/home/p/g/North-Shore-AI/`
