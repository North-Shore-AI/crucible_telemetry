defmodule CrucibleTelemetry.Ports.MetricsStore do
  @moduledoc """
  Port for training metrics storage.

  This port handles storing and retrieving training metrics (loss, learning rate, etc.)
  to various backends like JSONL files, databases, or experiment tracking services.

  ## Implementing an Adapter

      defmodule MyApp.Adapters.MetricsStore do
        @behaviour CrucibleTelemetry.Ports.MetricsStore

        @impl true
        def record(opts, run_id, metric_name, value, record_opts) do
          # Store the metric
          :ok
        end

        @impl true
        def flush(opts, run_id) do
          # Ensure all metrics are persisted
          :ok
        end

        @impl true
        def read(opts, run_id) do
          # Read all metrics for run
          {:ok, []}
        end
      end

  ## Metrics Operations

  1. `record/5` - Record a metric value at a step
  2. `flush/2` - Ensure all metrics are persisted
  3. `read/2` - Read all metrics for a run
  """

  @type adapter :: module()
  @type adapter_opts :: keyword()
  @type adapter_ref :: {adapter(), adapter_opts()}
  @type run_id :: String.t()
  @type metric_name :: atom() | String.t()
  @type value :: number()

  # ============================================================================
  # Callbacks (what adapters implement)
  # ============================================================================

  @doc """
  Record a single metric value.

  ## Parameters
  - `opts` - Adapter-specific options
  - `run_id` - Training run identifier
  - `metric_name` - Name of the metric (e.g., :loss, :accuracy)
  - `value` - Numeric value
  - `record_opts` - Options including `:step` and optional `:metadata`

  ## Returns
  - `:ok` - Metric recorded
  - `{:error, reason}` - Recording failed
  """
  @callback record(adapter_opts(), run_id(), metric_name(), value(), keyword()) ::
              :ok | {:error, term()}

  @doc """
  Flush any buffered metrics to storage.

  ## Parameters
  - `opts` - Adapter options
  - `run_id` - Training run identifier

  ## Returns
  - `:ok` - Flushed successfully
  - `{:error, reason}` - Flush failed
  """
  @callback flush(adapter_opts(), run_id()) :: :ok | {:error, term()}

  @doc """
  Read all metrics for a training run.

  ## Parameters
  - `opts` - Adapter options
  - `run_id` - Training run identifier

  ## Returns
  - `{:ok, [map()]}` - List of metric entries
  - `{:error, reason}` - Read failed
  """
  @callback read(adapter_opts(), run_id()) :: {:ok, [map()]} | {:error, term()}

  # ============================================================================
  # Facade functions (called via adapter tuple)
  # ============================================================================

  @doc """
  Record a metric using the given adapter.

  ## Parameters
  - `adapter_ref` - Tuple of `{module, opts}`
  - `run_id` - Training run identifier
  - `metric_name` - Name of the metric
  - `value` - Numeric value
  - `record_opts` - Options including `:step` and optional `:metadata`

  ## Examples

      adapter = {JSONLMetrics, [path: "/tmp/metrics.jsonl"]}
      MetricsStore.record(adapter, "run_123", :loss, 1.5, step: 0)
  """
  @spec record(adapter_ref(), run_id(), metric_name(), value(), keyword()) ::
          :ok | {:error, term()}
  def record({module, opts}, run_id, metric_name, value, record_opts \\ []) do
    module.record(opts, run_id, metric_name, value, record_opts)
  end

  @doc """
  Flush buffered metrics using the given adapter.

  ## Parameters
  - `adapter_ref` - Tuple of `{module, opts}`
  - `run_id` - Training run identifier

  ## Examples

      adapter = {JSONLMetrics, [path: "/tmp/metrics.jsonl"]}
      MetricsStore.flush(adapter, "run_123")
  """
  @spec flush(adapter_ref(), run_id()) :: :ok | {:error, term()}
  def flush({module, opts}, run_id) do
    module.flush(opts, run_id)
  end

  @doc """
  Read all metrics for a run using the given adapter.

  ## Parameters
  - `adapter_ref` - Tuple of `{module, opts}`
  - `run_id` - Training run identifier

  ## Examples

      adapter = {JSONLMetrics, [path: "/tmp/metrics.jsonl"]}
      {:ok, entries} = MetricsStore.read(adapter, "run_123")
  """
  @spec read(adapter_ref(), run_id()) :: {:ok, [map()]} | {:error, term()}
  def read({module, opts}, run_id) do
    module.read(opts, run_id)
  end
end
