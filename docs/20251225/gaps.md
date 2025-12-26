# CrucibleTelemetry Gap Analysis

**Date:** 2025-12-25
**Version:** 0.2.1

## Summary

This document identifies gaps, missing features, and areas for improvement in crucible_telemetry based on the design documents, roadmap, and ecosystem integration requirements.

---

## Critical Gaps

### 1. Missing Standard Telemetry Events

**Issue:** The library only captures a limited set of telemetry events. Other crucible packages should emit standardized events that this library should capture.

**Missing Events from Crucible Ecosystem:**
- `[:crucible_train, :training, :start|stop|exception]` - Training job events
- `[:crucible_train, :epoch, :start|stop]` - Epoch progress
- `[:crucible_train, :batch, :stop]` - Batch metrics
- `[:crucible_train, :checkpoint, :saved]` - Checkpoint events
- `[:crucible_deployment, :inference, :start|stop|exception]` - Inference events
- `[:crucible_deployment, :health_check, :completed]` - Health monitoring
- `[:crucible_framework, :pipeline, :start|stop]` - Pipeline execution
- `[:crucible_framework, :stage, :start|stop]` - Stage execution
- `[:crucible_xai, :explanation, :generated]` - Explainability events
- `[:crucible_adversary, :attack, :executed]` - Adversarial testing events

**Impact:** Cannot track full ML lifecycle (train -> deploy -> monitor)

**Recommendation:** Add configurable event subscription and define standard event schemas in crucible_ir.

---

### 2. No PostgreSQL Storage Backend

**Issue:** Only ETS storage is implemented. The `Store` module defines a behavior but only ETS implements it.

**From mix.exs roadmap:**
```
- [ ] PostgreSQL backend for persistent storage
- [ ] TimescaleDB support for time-series optimization
```

**Impact:**
- Cannot persist experiments across node restarts
- Cannot handle experiments with >1M events
- No distributed experiment queries

**Location:** `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/store.ex` (lines 112-115)

---

### 3. Missing Parquet Export

**Issue:** Only CSV and JSONL exports are implemented. Parquet is listed in roadmap.

**From README.md:**
```
- [ ] Parquet export format
```

**Impact:** Less efficient for large-scale data analysis in Python/Spark

---

### 4. No Integration with crucible_framework

**Issue:** crucible_telemetry is not listed as a dependency in crucible_framework, and there's no automatic telemetry attachment for framework pipelines.

**crucible_framework deps (mix.exs lines 36-65):**
- Lists crucible_ensemble, crucible_hedging, crucible_bench, crucible_trace
- Does NOT list crucible_telemetry

**Impact:** Experiments run through crucible_framework don't get automatic instrumentation.

---

### 5. No Integration with crucible_train

**Issue:** crucible_train has telemetry dependency but no integration with crucible_telemetry for training metrics.

**Impact:** Training jobs don't benefit from experiment tracking.

---

### 6. Missing Anomaly Detection

**Issue:** Documented in enhancement design but not implemented.

**From `/home/home/p/g/North-Shore-AI/crucible_telemetry/docs/20251125/enhancements_design.md` (lines 304-402):**
- Z-score method
- Modified Z-score (MAD)
- IQR method
- Streaming detection with EWMA

**Impact:** Researchers must manually analyze data for outliers.

---

### 7. Missing Advanced Sampling Strategies

**Issue:** Only simple probabilistic sampling exists.

**From enhancement design (lines 103-183):**
- Uniform sampling (exists but basic)
- Reservoir sampling (not implemented)
- Stratified sampling (not implemented)
- Adaptive sampling (not implemented)
- Importance sampling (not implemented)

**Impact:** Cannot balance storage/performance for long-running experiments.

---

## Moderate Gaps

### 8. No LiveView Dashboard

**Issue:** Real-time monitoring dashboard is on roadmap but not implemented.

**From README.md:**
```
- [ ] LiveView dashboard for real-time monitoring
```

**Impact:** No visual real-time monitoring capability.

---

### 9. Missing Statistical Hypothesis Testing

**Issue:** Basic descriptive statistics only. No t-tests, chi-square, etc.

**From README.md:**
```
- [ ] Statistical hypothesis testing (t-test, chi-square)
```

**Note:** crucible_bench has this capability - should integrate rather than duplicate.

---

### 10. No S3 Archival Support

**Issue:** Archive function only supports local file export.

**Location:** `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/experiment.ex` (lines 250-268)

```elixir
case destination do
  :local -> archive_to_file(experiment, data, opts[:path])
  :s3 -> {:error, :not_implemented}
  :postgres -> {:error, :not_implemented}
end
```

---

### 11. Missing Multi-Node Support

**Issue:** No distributed experiment support.

**From README.md:**
```
- [ ] Multi-node distributed experiments
```

**Impact:** Cannot aggregate metrics from multiple nodes.

---

### 12. No Continuous Aggregates

**Issue:** All aggregations are computed on-demand.

**From README.md:**
```
- [ ] Continuous aggregates
```

**Impact:** Performance issues with large datasets.

---

## Minor Gaps

### 13. Missing Credo Configuration

**Issue:** No `.credo.exs` file for code quality checks.

---

### 14. Missing Dialyzer Configuration for Tests

**Issue:** Dialyzer not configured to analyze test modules.

---

### 15. Incomplete Type Specifications

**Issue:** Not all public functions have @spec.

**Examples without @spec:**
- `CrucibleTelemetry.export/3`
- `CrucibleTelemetry.calculate_metrics/1`
- Most `CrucibleTelemetry.Analysis` functions

---

### 16. Missing CHANGELOG.md

**Issue:** Referenced in mix.exs but file doesn't exist at project root.

**Location:** mix.exs line 76:
```elixir
extras: ["README.md", "CHANGELOG.md"]
```

---

### 17. No Property-Based Tests

**Issue:** Enhancement design mentions property-based tests but none exist.

**From enhancement design (lines 492-495):**
```
### Property-Based Tests
- Statistical algorithms (sampling, percentiles, anomaly detection)
- Verify mathematical properties hold
- Use StreamData for randomized testing
```

---

### 18. Missing Cost Model for New Models

**Issue:** Cost calculation only covers a few models.

**Location:** `/home/home/p/g/North-Shore-AI/crucible_telemetry/lib/telemetry_research/handler.ex` (lines 115-123)

```elixir
rates = %{
  "gemini-2.0-flash-exp" => %{input: 0.075, output: 0.30},
  "gpt-4" => %{input: 30.0, output: 60.0},
  "gpt-4-turbo" => %{input: 10.0, output: 30.0},
  "gpt-3.5-turbo" => %{input: 0.5, output: 1.5},
  "claude-3-opus" => %{input: 15.0, output: 75.0},
  "claude-3-sonnet" => %{input: 3.0, output: 15.0}
}
```

**Missing models:** Claude 3.5 Sonnet/Haiku, GPT-4o, o1-preview, Gemini 1.5 Pro, etc.

---

## Integration Gaps

### 19. No crucible_ir Schema for Telemetry Events

**Issue:** crucible_ir should define standard telemetry event schemas that all crucible packages use.

---

### 20. No Standardized Event Naming Convention

**Issue:** Event names are hardcoded in multiple places. Should be centralized.

---

### 21. No Correlation ID Support

**Issue:** Cannot trace related events across different components.

**Recommendation:** Add correlation_id to event enrichment for distributed tracing.

---

## Documentation Gaps

### 22. Missing API Documentation for Private Functions

**Issue:** Private functions lack documentation for maintainability.

---

### 23. No Troubleshooting Guide

**Issue:** No guide for common issues and solutions.

---

### 24. Missing Performance Benchmarks

**Issue:** Claims performance characteristics but no benchmarks to verify.

---

## Priority Matrix

| Gap | Severity | Effort | Priority |
|-----|----------|--------|----------|
| Standard Telemetry Events | High | Medium | 1 |
| crucible_framework Integration | High | Medium | 2 |
| PostgreSQL Backend | High | High | 3 |
| crucible_train Integration | Medium | Low | 4 |
| Parquet Export | Medium | Medium | 5 |
| Anomaly Detection | Medium | High | 6 |
| Advanced Sampling | Medium | High | 7 |
| LiveView Dashboard | Low | High | 8 |
| S3 Archival | Low | Medium | 9 |
| Type Specifications | Low | Low | 10 |

---

## Recommended Next Steps

1. **Define Standard Events in crucible_ir** - Create event schemas that all packages emit
2. **Add crucible_telemetry as dependency to crucible_framework** - Enable automatic instrumentation
3. **Implement PostgreSQL Backend** - Enable persistence and scalability
4. **Add Training Events to crucible_train** - Enable training job tracking
5. **Create Integration Tests** - Test cross-package telemetry flow
