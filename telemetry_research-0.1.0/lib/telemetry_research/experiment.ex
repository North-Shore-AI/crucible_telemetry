defmodule TelemetryResearch.Experiment do
  @moduledoc """
  Manages experiment lifecycle with complete isolation.

  Each experiment has its own isolated storage, telemetry handlers, and metadata.
  Multiple experiments can run concurrently without cross-contamination.
  """

  defstruct [
    :id,
    :name,
    :hypothesis,
    :condition,
    :metadata,
    :tags,
    :started_at,
    :stopped_at,
    :status,
    :sample_size,
    :metrics_config,
    :storage_backend
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          hypothesis: String.t() | nil,
          condition: String.t(),
          metadata: map(),
          tags: list(String.t()),
          started_at: DateTime.t(),
          stopped_at: DateTime.t() | nil,
          status: :running | :stopped | :archived,
          sample_size: integer() | nil,
          metrics_config: map(),
          storage_backend: atom()
        }

  alias TelemetryResearch.{Store, Handler}

  @doc """
  Start a new experiment.

  ## Options

  - `:name` (required) - Human-readable experiment name
  - `:hypothesis` - What you're testing
  - `:condition` - Experimental condition (default: "default")
  - `:tags` - List of tags for categorization (default: [])
  - `:metadata` - Additional context (default: %{})
  - `:sample_size` - Target sample size
  - `:metrics_config` - Which metrics to collect (default: all)
  - `:storage_backend` - Storage backend (:ets or :postgres, default: :ets)

  ## Examples

      {:ok, exp} = TelemetryResearch.Experiment.start(
        name: "ensemble_vs_single_model",
        hypothesis: "5-model ensemble achieves >99% reliability",
        condition: "treatment",
        tags: ["accuracy", "reliability", "h1"],
        sample_size: 1000
      )
  """
  def start(opts) do
    experiment = %__MODULE__{
      id: generate_id(),
      name: Keyword.fetch!(opts, :name),
      hypothesis: Keyword.get(opts, :hypothesis),
      condition: Keyword.get(opts, :condition, "default"),
      metadata: Keyword.get(opts, :metadata, %{}),
      tags: Keyword.get(opts, :tags, []),
      started_at: DateTime.utc_now(),
      stopped_at: nil,
      status: :running,
      sample_size: Keyword.get(opts, :sample_size),
      metrics_config: Keyword.get(opts, :metrics_config, default_metrics()),
      storage_backend: Keyword.get(opts, :storage_backend, :ets)
    }

    # Create isolated storage
    Store.init_experiment(experiment)

    # Attach telemetry handlers
    attach_handlers(experiment)

    # Register experiment
    :ets.insert(:telemetry_research_experiments, {experiment.id, experiment})

    {:ok, experiment}
  end

  @doc """
  Stop an experiment and finalize data collection.
  """
  def stop(experiment_id) do
    case get(experiment_id) do
      {:ok, experiment} ->
        # Detach handlers
        detach_handlers(experiment)

        # Update status
        updated = %{experiment | status: :stopped, stopped_at: DateTime.utc_now()}

        # Update in registry
        :ets.insert(:telemetry_research_experiments, {experiment_id, updated})

        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Get an experiment by ID.
  """
  def get(experiment_id) do
    case :ets.lookup(:telemetry_research_experiments, experiment_id) do
      [{^experiment_id, experiment}] -> {:ok, experiment}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all experiments.
  """
  def list do
    :ets.tab2list(:telemetry_research_experiments)
    |> Enum.map(fn {_id, experiment} -> experiment end)
  end

  @doc """
  Archive experiment data for long-term storage.
  """
  def archive(experiment_id, opts \\ []) do
    with {:ok, experiment} <- get(experiment_id) do
      destination = Keyword.get(opts, :destination, :local)

      # Export all data
      data = Store.get_all(experiment_id)

      case destination do
        :local ->
          archive_to_file(experiment, data, opts[:path])

        :s3 ->
          {:error, :not_implemented}

        :postgres ->
          {:error, :not_implemented}
      end
    end
  end

  @doc """
  Clean up experiment resources.
  """
  def cleanup(experiment_id, opts \\ []) do
    keep_data = Keyword.get(opts, :keep_data, false)

    unless keep_data do
      Store.delete_experiment(experiment_id)
    end

    :ets.delete(:telemetry_research_experiments, experiment_id)

    :ok
  end

  # Private functions

  defp attach_handlers(experiment) do
    events = [
      [:req_llm, :request, :start],
      [:req_llm, :request, :stop],
      [:req_llm, :request, :exception],
      [:ensemble, :prediction, :start],
      [:ensemble, :prediction, :stop],
      [:ensemble, :vote, :completed],
      [:hedging, :request, :start],
      [:hedging, :request, :duplicated],
      [:hedging, :request, :stop],
      [:causal_trace, :event, :created],
      [:altar, :tool, :start],
      [:altar, :tool, :stop]
    ]

    :telemetry.attach_many(
      handler_id(experiment),
      events,
      &Handler.handle_event/4,
      %{experiment: experiment}
    )
  end

  defp detach_handlers(experiment) do
    :telemetry.detach(handler_id(experiment))
  end

  defp handler_id(experiment), do: "research_#{experiment.id}"

  defp generate_id do
    # Generate a short UUID-like ID
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp default_metrics do
    %{
      latency: true,
      cost: true,
      success_rate: true,
      tokens: true,
      custom: []
    }
  end

  defp archive_to_file(experiment, data, path) do
    path = path || "exports/#{experiment.name}_archive.jsonl"
    File.mkdir_p!(Path.dirname(path))

    file = File.open!(path, [:write])

    # Write experiment metadata
    IO.puts(file, Jason.encode!(%{type: :experiment_metadata, data: experiment}))

    # Write all events
    Enum.each(data, fn event ->
      IO.puts(file, Jason.encode!(%{type: :event, data: event}))
    end)

    File.close(file)

    {:ok, path}
  end
end
