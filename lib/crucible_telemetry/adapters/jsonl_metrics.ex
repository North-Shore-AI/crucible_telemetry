defmodule CrucibleTelemetry.Adapters.JSONLMetrics do
  @moduledoc """
  JSONL file-based metrics storage adapter.

  Writes metrics as newline-delimited JSON for easy parsing
  and compatibility with analysis tools.

  ## Options

  - `:path` - Path to JSONL file (required)

  ## Example

      adapters = %{
        metrics_store: {
          CrucibleTelemetry.Adapters.JSONLMetrics,
          [path: "/tmp/training/metrics.jsonl"]
        }
      }

  ## Output Format

  Each line is a JSON object with:
  - `run_id` - Training run identifier
  - `metric` - Metric name (string)
  - `value` - Numeric value
  - `step` - Training step number
  - `timestamp` - ISO8601 timestamp
  - `metadata` - Optional additional data
  """

  @behaviour CrucibleTelemetry.Ports.MetricsStore

  @impl true
  @spec record(keyword(), String.t(), atom() | String.t(), number(), keyword()) ::
          :ok | {:error, term()}
  def record(opts, run_id, metric_name, value, record_opts) do
    path = Keyword.fetch!(opts, :path)
    step = Keyword.get(record_opts, :step)
    metadata = Keyword.get(record_opts, :metadata, %{})

    entry = %{
      run_id: run_id,
      metric: to_string(metric_name),
      value: value,
      step: step,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      metadata: metadata
    }

    line = Jason.encode!(entry) <> "\n"

    case File.write(path, line, [:append, :utf8]) do
      :ok -> :ok
      {:error, reason} -> {:error, {:write_failed, reason}}
    end
  end

  @impl true
  @spec flush(keyword(), String.t()) :: :ok | {:error, term()}
  def flush(_opts, _run_id) do
    # JSONL writes are immediate, no buffering
    :ok
  end

  @impl true
  @spec read(keyword(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def read(opts, run_id) do
    path = Keyword.fetch!(opts, :path)

    if File.exists?(path) do
      entries =
        path
        |> File.stream!()
        |> Stream.map(&String.trim/1)
        |> Stream.reject(&(&1 == ""))
        |> Stream.map(&Jason.decode!/1)
        |> Stream.filter(&(&1["run_id"] == run_id))
        |> Enum.to_list()

      {:ok, entries}
    else
      {:ok, []}
    end
  end
end
