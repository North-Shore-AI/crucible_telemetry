# CrucibleTelemetry Enhancements - Design Document
**Date:** 2025-11-25
**Version:** 0.2.0
**Author:** Claude Code Analysis

## Executive Summary

This document outlines enhancements to the CrucibleTelemetry project to improve its research-grade instrumentation capabilities. The proposed changes focus on real-time streaming metrics, advanced sampling strategies, experiment lifecycle management, time-windowed analysis, and anomaly detection.

## Current State Analysis

### Strengths
- **Solid Foundation**: Well-architected with clear separation of concerns (Experiment, Handler, Store, Export, Analysis)
- **Complete Event Capture**: No sampling by default ensures reproducibility
- **Multiple Export Formats**: CSV and JSON Lines support for various analysis tools
- **ETS-based Storage**: Fast, in-memory storage with low latency
- **Comprehensive Metrics**: Latency, cost, reliability, and token metrics
- **Isolation**: Multiple concurrent experiments without cross-contamination

### Identified Gaps

#### 1. **Real-Time Metrics**
- **Current**: Metrics calculated only after experiment stops (post-hoc analysis)
- **Gap**: No ability to monitor experiment progress in real-time
- **Impact**: Researchers cannot detect issues early or adjust experiments dynamically

#### 2. **Sampling Strategies**
- **Current**: Simple probabilistic sampling (single rate)
- **Gap**: No adaptive or intelligent sampling strategies
- **Impact**: Cannot balance storage/performance with data quality for long-running experiments

#### 3. **Experiment Lifecycle**
- **Current**: Only start/stop operations
- **Gap**: Cannot pause/resume experiments for debugging or resource management
- **Impact**: Difficult to handle interruptions or multi-phase experiments

#### 4. **Time-Window Queries**
- **Current**: Full table scans with post-hoc filtering
- **Gap**: No efficient time-windowed aggregations
- **Impact**: Poor performance for streaming analysis and large experiments

#### 5. **Anomaly Detection**
- **Current**: No built-in anomaly detection
- **Gap**: Researchers must manually analyze data for outliers
- **Impact**: Miss important anomalies during experiments

#### 6. **Statistical Testing**
- **Current**: Basic descriptive statistics only
- **Gap**: No hypothesis testing, confidence intervals, or effect sizes
- **Impact**: Cannot make statistically rigorous conclusions from experiments

## Proposed Enhancements

### Enhancement 1: Real-Time Streaming Metrics

#### Rationale
Research experiments often run for extended periods. Real-time metrics allow researchers to:
- Monitor experiment health and progress
- Detect issues early (cost overruns, latency spikes, errors)
- Make informed decisions about continuing or stopping experiments
- Validate hypotheses before experiment completion

#### Design

**Architecture Change**: Add `CrucibleTelemetry.StreamingMetrics` module

```elixir
defmodule CrucibleTelemetry.StreamingMetrics do
  @moduledoc """
  Real-time streaming metrics with windowed aggregations.

  Maintains rolling statistics without storing all events in memory.
  Uses efficient online algorithms for mean, variance, percentiles.
  """
end
```

**Key Features**:
1. **Online Statistics**: Calculate mean, variance, min, max incrementally
2. **T-Digest for Percentiles**: Approximate percentiles (P50, P95, P99) with bounded memory
3. **Sliding Windows**: Support for time-based windows (last 1min, 5min, 1hour)
4. **Low Memory Footprint**: O(1) space complexity for most metrics

**Implementation Approach**:
- Use GenServer to maintain streaming state per experiment
- Update metrics on each event insertion
- Provide `get_streaming_metrics(experiment_id)` API
- Support configurable window sizes

**Testing Strategy**:
- Test accuracy against exact calculations for small datasets
- Test memory usage stays bounded for large event streams
- Test concurrent access patterns
- Property-based tests for statistical correctness

#### Benefits
- **Early Detection**: Catch cost overruns or errors before experiment completion
- **Memory Efficient**: No need to store all events for basic metrics
- **Low Latency**: Real-time updates without recomputing from scratch

---

### Enhancement 2: Advanced Sampling Strategies

#### Rationale
For long-running experiments with millions of events, storing every event becomes impractical. Intelligent sampling can:
- Reduce storage requirements by 10-100x
- Maintain statistical validity for most analyses
- Adaptively increase sampling during interesting periods

#### Design

**Architecture Change**: Add `CrucibleTelemetry.Sampler` module

```elixir
defmodule CrucibleTelemetry.Sampler do
  @moduledoc """
  Adaptive sampling strategies for experiments.

  Supports multiple sampling strategies:
  - Uniform: Random sampling with fixed probability
  - Reservoir: Guaranteed fixed sample size
  - Stratified: Sample proportionally from different event types
  - Adaptive: Increase sampling during anomalies
  - Importance: Prioritize rare or expensive events
  """

  @callback should_sample?(event, state) :: {boolean(), state}
end
```

**Sampling Strategies**:

1. **Uniform Sampling** (already exists, improved)
   - Fixed probability sampling
   - Configurable rate (1%, 10%, 50%, etc.)

2. **Reservoir Sampling**
   - Guarantee exactly N samples across experiment
   - Uses reservoir algorithm for uniform random sample

3. **Stratified Sampling**
   - Sample different event types at different rates
   - E.g., 100% errors, 10% successes
   - Ensures minority events are captured

4. **Adaptive Sampling**
   - Increase sampling during anomalies (latency spikes, errors)
   - Decrease sampling during stable periods
   - Uses statistical process control for detection

5. **Importance Sampling**
   - Prioritize expensive events (high cost, high latency)
   - Maintain complete sample of tail events (P99+)

**Configuration**:
```elixir
CrucibleTelemetry.start_experiment(
  name: "large_scale_test",
  sampling_strategy: :adaptive,
  sampling_config: %{
    base_rate: 0.1,        # Sample 10% normally
    anomaly_rate: 1.0,     # Sample 100% during anomalies
    min_samples: 1000,     # Always collect at least 1000 samples
    stratified_rates: %{
      error: 1.0,          # All errors
      success: 0.1         # 10% of successes
    }
  }
)
```

**Testing Strategy**:
- Verify sample size guarantees
- Test statistical properties of samples
- Verify anomaly detection triggers increased sampling
- Property-based tests for sampling algorithms

#### Benefits
- **Scalability**: Handle experiments with millions/billions of events
- **Quality**: Maintain statistical validity with smaller samples
- **Flexibility**: Choose appropriate strategy for experiment goals

---

### Enhancement 3: Experiment Pause/Resume

#### Rationale
Long-running experiments may need to be paused for:
- Debugging issues without stopping data collection permanently
- Resource management (e.g., overnight pauses)
- Multi-phase experiments with setup time between phases
- Cost control (pause during non-critical periods)

#### Design

**Schema Changes**: Add status field values
```elixir
status: :running | :paused | :stopped | :archived
paused_at: DateTime.t() | nil
resume_count: integer()
```

**API Changes**:
```elixir
def pause(experiment_id, opts \\ [])
def resume(experiment_id, opts \\ [])
def is_paused?(experiment_id)
```

**Behavior**:
- `pause/1`: Detach telemetry handlers, update status, record pause time
- `resume/1`: Reattach handlers, update status, increment resume count
- Events during pause are not collected
- Metrics account for pause duration (active duration vs wall-clock duration)

**Enhanced Metrics**:
```elixir
%{
  summary: %{
    wall_clock_duration: 3600,    # Total elapsed time (1 hour)
    active_duration: 2400,        # Time actually running (40 min)
    paused_duration: 1200,        # Time paused (20 min)
    pause_count: 2
  }
}
```

**Testing Strategy**:
- Test handler attachment/detachment during pause/resume
- Verify events not collected during pause
- Test metrics calculations with paused periods
- Test multiple pause/resume cycles

#### Benefits
- **Flexibility**: Better control over experiment lifecycle
- **Resource Management**: Pause experiments during low-priority periods
- **Debugging**: Investigate issues without losing experiment state
- **Cost Control**: Stop spending during pauses

---

### Enhancement 4: Time-Window Queries

#### Rationale
For streaming analysis and large experiments, full table scans are inefficient. Time-windowed queries enable:
- Efficient analysis of recent events (last 5 minutes, last hour)
- Streaming dashboards with minimal latency
- Detection of time-based patterns (hourly variations, degradation over time)

#### Design

**Storage Enhancement**: Leverage ETS ordered_set by timestamp

**New Query API**:
```elixir
def query_window(experiment_id, window_spec, filters \\ %{})

# Examples:
# Last 5 minutes
query_window(exp_id, {:last, 5, :minutes})

# Last 100 events
query_window(exp_id, {:last_n, 100})

# Specific time range
query_window(exp_id, {:range, start_time, end_time})

# Sliding window (for streaming)
query_window(exp_id, {:sliding, 5, :minutes, step: 1_000})
```

**Windowed Aggregations**:
```elixir
def windowed_metrics(experiment_id, window_size, step_size)

# Returns metrics for each window:
[
  %{window_start: t1, window_end: t2, metrics: %{...}},
  %{window_start: t2, window_end: t3, metrics: %{...}},
  ...
]
```

**Implementation**:
- Use ETS ordered traversal for efficient range scans
- Implement sliding window with efficient incremental updates
- Cache recent window results for streaming queries

**Testing Strategy**:
- Test correctness of window boundaries
- Benchmark query performance vs full table scan
- Test sliding window updates
- Verify metrics match full analysis for same window

#### Benefits
- **Performance**: 10-100x faster for windowed queries
- **Streaming Analysis**: Enable real-time dashboards
- **Pattern Detection**: Identify time-based trends
- **Memory Efficient**: Analyze large experiments in chunks

---

### Enhancement 5: Statistical Anomaly Detection

#### Rationale
Automatic anomaly detection helps researchers:
- Identify outliers and unusual patterns automatically
- Detect system failures or degradation early
- Focus analysis on interesting events
- Improve experiment quality through early intervention

#### Design

**New Module**: `CrucibleTelemetry.AnomalyDetection`

```elixir
defmodule CrucibleTelemetry.AnomalyDetection do
  @moduledoc """
  Statistical anomaly detection for experiment events.

  Supports multiple detection methods:
  - Z-score (standard deviations from mean)
  - Modified Z-score (using MAD for robustness)
  - IQR (interquartile range method)
  - Isolation Forest (for multivariate anomalies)
  """
end
```

**Detection Methods**:

1. **Z-Score Method**
   - Flag events >3 standard deviations from mean
   - Fast, simple, assumes normal distribution
   - Good for latency and cost anomalies

2. **Modified Z-Score (MAD)**
   - Uses Median Absolute Deviation (robust to outliers)
   - Better for skewed distributions
   - Threshold: |0.6745 * (x - median) / MAD| > 3.5

3. **IQR Method**
   - Flag events outside [Q1 - 1.5*IQR, Q3 + 1.5*IQR]
   - Non-parametric, no distribution assumptions
   - Classic outlier detection

4. **Streaming Detection**
   - Online algorithms for real-time detection
   - Adaptive thresholds based on recent history
   - Uses EWMA (Exponentially Weighted Moving Average)

**API**:
```elixir
# Configure anomaly detection for experiment
CrucibleTelemetry.start_experiment(
  name: "anomaly_test",
  anomaly_detection: %{
    enabled: true,
    methods: [:z_score, :iqr],
    metrics: [:latency_ms, :cost_usd],
    threshold: 3.0,
    action: :flag  # or :alert, :sample_more
  }
)

# Query anomalies
anomalies = CrucibleTelemetry.AnomalyDetection.get_anomalies(exp_id)

# Anomaly metrics
anomaly_stats = CrucibleTelemetry.AnomalyDetection.calculate_anomaly_metrics(exp_id)
%{
  total_anomalies: 15,
  anomaly_rate: 0.015,  # 1.5% of events
  anomalies_by_type: %{
    latency: 10,
    cost: 5
  },
  anomaly_periods: [
    %{start: t1, end: t2, count: 8, severity: :high}
  ]
}
```

**Integration**:
- Flag anomalous events with `:anomaly` field
- Store anomaly scores for ranking/analysis
- Trigger adaptive sampling when anomalies detected
- Include anomaly analysis in metrics

**Testing Strategy**:
- Test detection accuracy with synthetic anomalies
- Verify false positive rates are acceptable
- Test real-time detection latency
- Property-based tests for statistical correctness

#### Benefits
- **Automatic Detection**: No manual analysis needed
- **Early Warning**: Detect issues during experiments
- **Quality**: Focus on interesting events
- **Integration**: Works with adaptive sampling

---

### Enhancement 6: Statistical Testing (Future Work)

#### Rationale
Research requires statistically rigorous conclusions. While this is partially covered by the separate `crucible_bench` module, having basic statistical testing integrated helps researchers:
- Test hypotheses directly from telemetry data
- Calculate confidence intervals for metrics
- Compute effect sizes for differences
- Determine required sample sizes

**Note**: This enhancement is designed to complement, not replace, the comprehensive statistical testing in `crucible_bench`. The goal is to provide lightweight, integrated testing for common scenarios.

#### Design (Brief Outline)

**New Module**: `CrucibleTelemetry.StatTests`

```elixir
# Simple hypothesis tests
t_test(control_exp_id, treatment_exp_id, metric: :latency)
mann_whitney_u(control_exp_id, treatment_exp_id, metric: :cost)

# Confidence intervals
confidence_interval(exp_id, metric: :success_rate, confidence: 0.95)

# Effect sizes
cohens_d(control_exp_id, treatment_exp_id, metric: :latency)

# Power analysis
required_sample_size(effect_size: 0.5, power: 0.8, alpha: 0.05)
```

**Implementation Note**: This is marked for future work as it requires additional dependencies (`Statistics` library or similar) and careful integration with `crucible_bench`.

---

## Implementation Plan

### Phase 1: Core Enhancements (v0.2.0)
1. **Streaming Metrics** (Priority: High)
   - GenServer for streaming state
   - Online algorithms for basic stats
   - Window-based queries

2. **Advanced Sampling** (Priority: High)
   - Implement 3-4 sampling strategies
   - Configuration system
   - Documentation

3. **Pause/Resume** (Priority: Medium)
   - Extend experiment lifecycle
   - Update metrics calculations
   - Tests

4. **Time-Window Queries** (Priority: Medium)
   - Efficient range scans
   - Window API
   - Benchmarks

### Phase 2: Advanced Features (v0.3.0)
1. **Anomaly Detection** (Priority: High)
   - Z-score and IQR methods
   - Integration with sampling
   - Anomaly metrics

2. **Statistical Testing** (Priority: Low)
   - Basic t-tests and confidence intervals
   - Integration with crucible_bench
   - Documentation

### Phase 3: Integration & Polish (v0.4.0)
1. **LiveView Dashboard** (if needed)
2. **PostgreSQL Backend** (for persistence)
3. **Advanced Export Formats** (Parquet)

---

## Testing Strategy

### Unit Tests
- Test each module in isolation
- Mock dependencies for deterministic tests
- Cover edge cases (empty data, single event, etc.)

### Integration Tests
- Test full workflow: start → collect → analyze → export
- Test multiple experiments running concurrently
- Test pause/resume cycles with events

### Property-Based Tests
- Statistical algorithms (sampling, percentiles, anomaly detection)
- Verify mathematical properties hold
- Use StreamData for randomized testing

### Performance Tests
- Benchmark streaming metrics overhead
- Measure query performance for time windows
- Verify memory usage stays bounded

### Quality Metrics
- Target: >90% test coverage (maintain current standard)
- Zero compilation warnings
- All doctests passing
- Mix format validation

---

## Risk Analysis

### Risk 1: Performance Overhead
**Risk**: Streaming metrics and anomaly detection add computational overhead

**Mitigation**:
- Make features opt-in (disabled by default)
- Use efficient algorithms (online, O(1) space)
- Benchmark and set performance budgets
- Provide configuration to disable expensive features

### Risk 2: Statistical Accuracy
**Risk**: Online algorithms and sampling may reduce accuracy

**Mitigation**:
- Test accuracy against exact calculations
- Document accuracy/performance tradeoffs
- Provide multiple algorithm options
- Default to exact calculations for small datasets

### Risk 3: API Complexity
**Risk**: Too many options may confuse users

**Mitigation**:
- Provide sensible defaults
- Clear documentation with examples
- Keep simple cases simple (zero config)
- Progressive disclosure of advanced features

### Risk 4: Breaking Changes
**Risk**: Enhancements may break existing code

**Mitigation**:
- Maintain backward compatibility
- Make new features opt-in
- Deprecation warnings before removal
- Semantic versioning

---

## Success Metrics

### Quantitative
- All tests passing (100%)
- Zero compilation warnings
- Test coverage >90%
- Performance overhead <5% for default config
- Documentation coverage 100% for public APIs

### Qualitative
- Easy to understand for researchers
- Clear, helpful error messages
- Good developer experience
- Complements existing crucible ecosystem

---

## Documentation Updates

### README.md
- Add sections for new features
- Update examples with new APIs
- Add performance considerations
- Update roadmap

### API Documentation
- Comprehensive module docs
- Examples for all public functions
- Type specifications
- Links between related modules

### Guides (New)
- "Streaming Metrics Guide"
- "Sampling Strategies Guide"
- "Anomaly Detection Guide"
- "Performance Tuning Guide"

---

## Version History

### v0.2.0 (2025-11-25) - Proposed
- Real-time streaming metrics
- Advanced sampling strategies
- Experiment pause/resume
- Time-window queries
- Statistical anomaly detection

### v0.1.0 (2025-10-07) - Current
- Initial release
- Basic experiment management
- ETS storage
- CSV/JSON export
- Descriptive statistics

---

## Appendix: Technical Details

### A. Streaming Percentile Algorithm (T-Digest)

T-Digest is a probabilistic data structure for accurate percentile estimation with bounded memory:

**Properties**:
- Space: O(1) - fixed size regardless of data volume
- Accuracy: ~1% error for P50, ~0.1% for P95/P99
- Mergeable: Can combine multiple digests

**Trade-offs**:
- Approximate (not exact) percentiles
- More accurate at tails (P95, P99) than median
- Requires careful tuning of compression parameter

### B. Reservoir Sampling Algorithm

Classic algorithm for uniform random sample of fixed size:

```
maintain reservoir of size k
for each element i (where i > k):
  with probability k/i, replace random reservoir element
```

**Properties**:
- Guarantees exactly k samples
- Each element has equal probability k/n of selection
- Single pass algorithm (streaming friendly)

### C. Statistical Process Control for Adaptive Sampling

Uses EWMA (Exponentially Weighted Moving Average) to detect anomalies:

```
EWMA[t] = λ * value[t] + (1-λ) * EWMA[t-1]
Variance = λ * (value[t] - EWMA[t])^2 + (1-λ) * Variance[t-1]

Trigger if: |value - EWMA| > k * sqrt(Variance)
```

**Properties**:
- Online algorithm (no historical data needed)
- Adapts to changing baseline
- Tunable sensitivity (λ and k parameters)

---

## References

1. Dunning, T., & Ertl, O. (2019). Computing Extremely Accurate Quantiles Using t-Digests. arXiv:1902.04023
2. Vitter, J. S. (1985). Random sampling with a reservoir. ACM Transactions on Mathematical Software, 11(1), 37-57.
3. Hunter, J. S. (1986). The exponentially weighted moving average. Journal of Quality Technology, 18(4), 203-210.
4. Aggarwal, C. C. (2017). Outlier Analysis (2nd ed.). Springer.
5. Crucible Framework Documentation - https://github.com/North-Shore-AI/crucible_framework

---

## Conclusion

These enhancements significantly improve CrucibleTelemetry's capabilities for research-grade instrumentation while maintaining its core strengths:

✅ **Maintains**: Simplicity, isolation, reproducibility
✅ **Adds**: Real-time monitoring, scalability, automatic detection
✅ **Enables**: Larger experiments, streaming analysis, early detection
✅ **Preserves**: Backward compatibility, low overhead, ease of use

The proposed changes position CrucibleTelemetry as a comprehensive solution for AI/ML research experimentation, complementing the broader Crucible ecosystem.
