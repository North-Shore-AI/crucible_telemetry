# Changelog

All notable changes to this project will be documented in this file.

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
