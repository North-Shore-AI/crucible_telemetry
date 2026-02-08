# CrucibleTelemetry Examples

This directory contains runnable examples demonstrating CrucibleTelemetry features.

## Running Examples

Run any example with:

```bash
mix run examples/<example_name>.exs
```

## Basic Examples

### basic_usage.exs

Basic experiment lifecycle: start, collect events, stop, analyze.

```bash
mix run examples/basic_usage.exs
```

### ab_testing.exs

A/B testing with two experimental conditions and comparison metrics.

```bash
mix run examples/ab_testing.exs
```

### custom_metrics.exs

Custom metric calculation beyond the built-in analysis.

```bash
mix run examples/custom_metrics.exs
```

## Output Formats

Examples demonstrate various output formats:

- **Console**: Real-time progress and metrics
- **CSV**: `CrucibleTelemetry.export(exp_id, :csv)`
- **JSONL**: `CrucibleTelemetry.export(exp_id, :jsonl)`

## See Also

- [README.md](../README.md)
- [CHANGELOG.md](../CHANGELOG.md)
