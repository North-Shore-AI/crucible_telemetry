defmodule CrucibleTelemetry do
  @moduledoc """
  Research-grade instrumentation and metrics collection for AI/ML experiments.

  TelemetryResearch provides specialized observability for rigorous scientific
  experimentation in Elixir, with features that go beyond standard production
  telemetry:

  - **Experiment Isolation**: Run multiple experiments concurrently without cross-contamination
  - **Rich Metadata**: Automatic enrichment with experiment context, timestamps, and custom tags
  - **Multiple Export Formats**: CSV, JSON Lines, Parquet for analysis in Python, R, Julia
  - **Complete Event Capture**: No sampling by default - full reproducibility
  - **Statistical Analysis**: Built-in descriptive statistics and metrics calculations

  ## Quick Start

      # Start an experiment
      {:ok, experiment} = CrucibleTelemetry.start_experiment(
        name: "ensemble_vs_single",
        hypothesis: "5-model ensemble achieves >99% reliability",
        condition: "treatment",
        tags: ["accuracy", "reliability"]
      )

      # Events are automatically collected during experiment
      # ... run your AI workload ...

      # Stop and export results
      {:ok, experiment} = CrucibleTelemetry.stop_experiment(experiment.id)
      {:ok, path} = CrucibleTelemetry.export(experiment.id, :csv)

  ## Architecture

  - `CrucibleTelemetry.Experiment` - Experiment lifecycle management
  - `CrucibleTelemetry.Handler` - Event collection and enrichment
  - `CrucibleTelemetry.Store` - Multi-backend storage (ETS, PostgreSQL)
  - `CrucibleTelemetry.Export` - Format conversion (CSV, JSON, Parquet)
  - `CrucibleTelemetry.Analysis` - Statistical analysis and metrics
  """

  alias CrucibleTelemetry.Experiment

  @doc """
  Start a new experiment with the given options.

  ## Options

  - `:name` (required) - Human-readable experiment name
  - `:hypothesis` - What you're testing
  - `:condition` - Experimental condition (e.g., "treatment", "control")
  - `:tags` - List of tags for categorization
  - `:metadata` - Additional context as a map
  - `:sample_size` - Target sample size
  - `:storage_backend` - Storage backend to use (`:ets` or `:postgres`)

  ## Examples

      {:ok, exp} = CrucibleTelemetry.start_experiment(
        name: "baseline_gpt4",
        condition: "control",
        tags: ["h1", "baseline"]
      )
  """
  defdelegate start_experiment(opts), to: Experiment, as: :start

  @doc """
  Stop an experiment and finalize data collection.
  """
  defdelegate stop_experiment(experiment_id), to: Experiment, as: :stop

  @doc """
  Get an experiment by ID.
  """
  defdelegate get_experiment(experiment_id), to: Experiment, as: :get

  @doc """
  List all experiments.
  """
  defdelegate list_experiments, to: Experiment, as: :list

  @doc """
  Export experiment data in the specified format.

  ## Formats

  - `:csv` - Comma-separated values
  - `:jsonl` - JSON Lines (one JSON object per line)

  ## Examples

      {:ok, path} = CrucibleTelemetry.export("exp-123", :csv,
        path: "results/experiment.csv"
      )
  """
  def export(experiment_id, format, opts \\ []) do
    CrucibleTelemetry.Export.export(experiment_id, format, opts)
  end

  @doc """
  Calculate metrics for an experiment.

  Returns a map with comprehensive metrics including latency, cost,
  reliability, and custom metrics.

  ## Examples

      metrics = CrucibleTelemetry.calculate_metrics("exp-123")
      metrics.latency.p95  # 95th percentile latency
      metrics.reliability.success_rate  # Overall success rate
  """
  def calculate_metrics(experiment_id) do
    CrucibleTelemetry.Analysis.calculate_metrics(experiment_id)
  end
end
