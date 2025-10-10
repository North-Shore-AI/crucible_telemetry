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
  Delete all data for an experiment.
  """
  def delete_experiment(experiment_id) do
    backend = get_backend_for_experiment(experiment_id)
    backend.delete_experiment(experiment_id)
  end

  # Private functions

  defp get_backend(_experiment) do
    # Currently only ETS backend is implemented
    CrucibleTelemetry.Store.ETS
  end

  defp get_backend_for_experiment(experiment_id) do
    case Experiment.get(experiment_id) do
      {:ok, experiment} -> get_backend(experiment)
      {:error, _} -> CrucibleTelemetry.Store.ETS
    end
  end
end
