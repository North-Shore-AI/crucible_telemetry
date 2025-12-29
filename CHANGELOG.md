# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2025-12-28

### Added
- **MetricsStore Port**: New `CrucibleTelemetry.Ports.MetricsStore` behaviour for training metrics storage
  - `record/5` - Record a metric value at a step with optional metadata
  - `flush/2` - Ensure all buffered metrics are persisted
  - `read/2` - Read all metrics for a training run
  - Facade functions for easy adapter invocation via `{module, opts}` tuples
- **JSONLMetrics Adapter**: New `CrucibleTelemetry.Adapters.JSONLMetrics` for file-based metrics storage
  - Writes metrics as newline-delimited JSON for easy parsing
  - Compatible with Python, pandas, and other analysis tools
  - Each entry includes: run_id, metric name, value, step, timestamp, metadata
  - Immediate writes (no buffering) for data safety
  - Filter reads by run_id for multi-run files

### Changed
- Updated `crucible_ir` dependency from `~> 0.2.0` to `~> 0.2.1`

### Documentation
- Added comprehensive documentation for MetricsStore port and JSONLMetrics adapter

## [0.3.0] - 2025-12-25

### Added
- **Event Registry Module**: New `CrucibleTelemetry.Events` module provides centralized event definitions
  - `standard_events/0` - Get all standard telemetry events
  - `training_events/0`, `deployment_events/0`, `framework_events/0`, `llm_events/0` - Category-specific events
  - `events_by_category/0` - Events organized by category map
  - `event_info/1` - Get category and description for any event
- **Training Events (crucible_train)**: Full support for ML training job telemetry
  - `[:crucible_train, :training, :start|stop]` - Training job lifecycle
  - `[:crucible_train, :epoch, :start|stop]` - Epoch progress with metrics
  - `[:crucible_train, :batch, :stop]` - Batch completion with loss
  - `[:crucible_train, :checkpoint, :saved]` - Checkpoint persistence
  - Automatic enrichment with epoch, batch, loss, accuracy, learning_rate, gradient_norm
- **Deployment Events (crucible_deployment)**: Model inference telemetry
  - `[:crucible_deployment, :inference, :start|stop|exception]` - Inference lifecycle
  - Automatic enrichment with model_name, model_version, input_size, output_size, batch_size
- **Framework Events (crucible_framework)**: Pipeline execution telemetry
  - `[:crucible_framework, :pipeline, :start|stop]` - Pipeline lifecycle
  - `[:crucible_framework, :stage, :start|stop]` - Stage execution
  - Automatic enrichment with pipeline_id, stage_name, stage_index
- **Category-Specific Handler Enrichment**: Events are automatically enriched based on their category
- **Comprehensive Documentation**: Added implementation guides in `docs/20251225/`
  - `current_state.md` - Full architecture documentation
  - `gaps.md` - Gap analysis for future improvements
  - `implementation_prompt.md` - Implementation guide for contributors

### Changed
- Renamed `is_paused?/1` to `paused?/1` for Elixir naming conventions
- Experiment now uses centralized event registry instead of hardcoded event list
- Updated `crucible_ir` dependency from `~> 0.1.1` to `~> 0.2.0`
- Handler `enrich_event/4` now has proper @spec type specification
- Refactored CSV and JSONL exporters for better code organization

### Fixed
- Fixed `time_range/1` pattern matching for empty event list
- Fixed `experiment_duration/1` to handle single-event and empty lists correctly
- Improved code quality based on Credo recommendations

### Dependencies
- Added `credo` (~> 1.7) for code quality analysis
- Updated `crucible_ir` to 0.2.0

### Documentation
- Updated README with Event Registry and Training Integration sections
- Added comprehensive telemetry event documentation organized by category
- New professional SVG logo with modern data visualization theme

## [0.2.1] - 2025-11-26

### Added
- Added `crucible_ir` dependency (~> 0.1.1) for shared intermediate representation types

## [0.2.0] - 2025-11-25

### Added
- **Real-time Streaming Metrics**: New `CrucibleTelemetry.StreamingMetrics` module for online statistical calculations
  - Incremental mean, variance, min, max using Welford's algorithm
  - O(1) space complexity for basic metrics
  - Real-time updates without recomputing from scratch
  - Support for latency, cost, and reliability metrics
- **Experiment Pause/Resume**: Enhanced lifecycle management with `pause/1` and `resume/1` functions
  - Temporarily stop data collection without losing experiment state
  - Track pause count and timestamps for multi-phase experiments
  - Automatic handler attachment/detachment
- **Time-Window Queries**: Efficient time-based event filtering
  - Query last N minutes/seconds/hours with `{:last, n, unit}`
  - Query last N events with `{:last_n, n}`
  - Query specific time ranges with `{:range, start_time, end_time}`
  - Combine window queries with custom filter functions
- **Windowed Metrics**: Calculate metrics for sliding time windows
  - Support for overlapping and non-overlapping windows
  - Useful for time-series analysis and trend detection
  - Configurable window size and step size
- **Enhanced Status Types**: Added `:paused` status to experiment lifecycle
- **Comprehensive Documentation**: Design document in `docs/20251125/enhancements_design.md`

### Changed
- Experiment struct now includes `paused_at` timestamp and `pause_count` fields
- Store callbacks extended with `query_window/3` and `windowed_metrics/3`
- ETS backend implements efficient time-range queries using ordered_set properties

### Performance
- Time-window queries avoid full table scans for recent events
- Streaming metrics reduce memory footprint for large experiments
- Online algorithms provide real-time metrics with minimal overhead

## [0.1.0] - 2025-10-07

### Added
- Initial release
- Research-grade instrumentation and metrics collection for AI/ML experiments
- Experiment isolation for running multiple concurrent experiments without cross-contamination
- Rich metadata enrichment with experiment context, timestamps, and custom tags
- Multiple export formats (CSV, JSON Lines) for analysis in Python, R, Julia, Excel
- Complete event capture with no sampling for full reproducibility
- Built-in statistical analysis with descriptive statistics and metrics calculations
- Zero-cost abstraction with minimal overhead when not actively collecting data
- ETS-based storage for fast in-memory access and querying

### Documentation
- Comprehensive README with examples
- API documentation for experiment management and metrics
- Usage examples for A/B testing, benchmarking, and cost analysis
- Integration guide for research workflow telemetry
