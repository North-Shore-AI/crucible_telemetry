defmodule CrucibleTelemetry.Store do
  @moduledoc """
  Multi-backend storage for experiment data.

  Provides a unified interface for different storage backends.
  Currently supports ETS backend only.
  """

  alias CrucibleTelemetry.Experiment

  @callback init_experiment(experiment :: Experiment.t()) :: :ok | {:error, term()}
  @callback insert(experiment_id :: String.t(), event :: map()) :: :ok | {:error, term()}
  @callback get_all(experiment_id :: String.t()) :: [map()]
  @callback query(experiment_id :: String.t(), filters :: map()) :: [map()]
  @callback query_window(
              experiment_id :: String.t(),
              window_spec :: tuple(),
              filter_fn :: function() | nil
            ) :: [map()]
  @callback windowed_metrics(
              experiment_id :: String.t(),
              window_size :: pos_integer(),
              step_size :: pos_integer()
            ) :: [map()]
  @callback delete_experiment(experiment_id :: String.t()) :: :ok

  @doc """
  Initialize storage for an experiment.
  """
  def init_experiment(experiment) do
    backend = get_backend(experiment)
    backend.init_experiment(experiment)
  end

  @doc """
  Insert an event into storage.
  """
  def insert(experiment_id, event) do
    backend = get_backend_for_experiment(experiment_id)
    backend.insert(experiment_id, event)
  end

  @doc """
  Get all events for an experiment.
  """
  def get_all(experiment_id) do
    backend = get_backend_for_experiment(experiment_id)
    backend.get_all(experiment_id)
  end

  @doc """
  Query events with filters.
  """
  def query(experiment_id, filters) do
    backend = get_backend_for_experiment(experiment_id)
    backend.query(experiment_id, filters)
  end

  @doc """
  Query events within a time window.

  ## Window Specifications

  - `{:last, n, :minutes}` - Last N minutes of events
  - `{:last, n, :seconds}` - Last N seconds of events
  - `{:last, n, :hours}` - Last N hours of events
  - `{:last_n, n}` - Last N events
  - `{:range, start_time, end_time}` - Events in specific time range

  ## Examples

      # Last 5 minutes
      Store.query_window(exp_id, {:last, 5, :minutes})

      # Last 100 events
      Store.query_window(exp_id, {:last_n, 100})

      # Specific range with filter
      Store.query_window(exp_id, {:range, start, end}, fn e -> e.success end)
  """
  def query_window(experiment_id, window_spec, filter_fn \\ nil) do
    backend = get_backend_for_experiment(experiment_id)
    backend.query_window(experiment_id, window_spec, filter_fn)
  end

  @doc """
  Calculate metrics for sliding time windows.

  Returns a list of metrics for each window, useful for time-series analysis.

  ## Examples

      # 5-minute windows with 1-minute steps
      windows = Store.windowed_metrics(exp_id, 5*60*1_000_000, 60*1_000_000)
  """
  def windowed_metrics(experiment_id, window_size, step_size) do
    backend = get_backend_for_experiment(experiment_id)
    backend.windowed_metrics(experiment_id, window_size, step_size)
  end

  @doc """
  Delete all data for an experiment.
  """
  def delete_experiment(experiment_id) do
    backend = get_backend_for_experiment(experiment_id)
    backend.delete_experiment(experiment_id)
  end

  # Private functions

  defp get_backend(experiment) do
    case experiment.storage_backend do
      :ets -> CrucibleTelemetry.Store.ETS
      _ -> CrucibleTelemetry.Store.ETS
    end
  end

  defp get_backend_for_experiment(experiment_id) do
    case Experiment.get(experiment_id) do
      {:ok, experiment} -> get_backend(experiment)
      {:error, _} -> CrucibleTelemetry.Store.ETS
    end
  end
end
