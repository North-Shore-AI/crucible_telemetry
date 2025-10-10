defmodule TelemetryResearch.Handler do
  @moduledoc """
  Event collection pipeline with enrichment and filtering.

  Handles telemetry events, enriches them with experiment context,
  and stores them for later analysis.
  """

  alias TelemetryResearch.Store

  @doc """
  Main event handler attached to telemetry events.

  This function is called for every telemetry event that matches the
  patterns defined in the experiment. It enriches the event with
  experiment context and stores it.
  """
  def handle_event(event_name, measurements, metadata, config) do
    experiment = config.experiment

    # Check if we should collect this event (sampling)
    if should_collect?(event_name, experiment) do
      # Enrich with experiment context
      enriched = enrich_event(event_name, measurements, metadata, experiment)

      # Store the event
      Store.insert(experiment.id, enriched)
    end

    :ok
  end

  @doc """
  Enrich an event with experiment context and computed fields.
  """
  def enrich_event(event_name, measurements, metadata, experiment) do
    %{
      # Event identity
      event_id: generate_event_id(),
      event_name: event_name,
      timestamp: System.system_time(:microsecond),

      # Experiment context
      experiment_id: experiment.id,
      experiment_name: experiment.name,
      condition: experiment.condition,
      tags: experiment.tags,

      # Original data
      measurements: measurements,
      metadata: metadata,

      # Computed fields
      latency_ms: calculate_latency(measurements),
      cost_usd: calculate_cost(measurements, metadata),
      success: determine_success(measurements, metadata),

      # Additional enrichment
      session_id: metadata[:session_id],
      user_id: metadata[:user_id],
      sample_id: metadata[:sample_id],
      cohort: metadata[:cohort],
      model: metadata[:model],
      provider: metadata[:provider]
    }
  end

  # Private functions

  defp should_collect?(_event_name, experiment) do
    # Get sampling rate from experiment config
    sampling_rate = get_in(experiment.metadata, [:sampling_rate]) || 1.0
    :rand.uniform() <= sampling_rate
  end

  defp calculate_latency(measurements) do
    cond do
      Map.has_key?(measurements, :duration) ->
        # Convert nanoseconds to milliseconds
        measurements.duration / 1_000_000

      Map.has_key?(measurements, :stop) and Map.has_key?(measurements, :start) ->
        (measurements.stop - measurements.start) / 1_000_000

      true ->
        nil
    end
  end

  defp calculate_cost(measurements, metadata) do
    cond do
      # Explicit cost in metadata
      metadata[:cost] ->
        metadata[:cost]

      # Calculate from tokens and model
      metadata[:tokens] && metadata[:model] ->
        calculate_cost_from_tokens(metadata[:tokens], metadata[:model])

      # Try to extract from measurements
      measurements[:cost] ->
        measurements[:cost]

      true ->
        nil
    end
  end

  defp calculate_cost_from_tokens(tokens, model) when is_map(tokens) do
    # Simple cost calculation (would be more sophisticated in production)
    # Prices per 1M tokens (example rates)
    rates = %{
      "gemini-2.0-flash-exp" => %{input: 0.075, output: 0.30},
      "gpt-4" => %{input: 30.0, output: 60.0},
      "gpt-4-turbo" => %{input: 10.0, output: 30.0},
      "gpt-3.5-turbo" => %{input: 0.5, output: 1.5},
      "claude-3-opus" => %{input: 15.0, output: 75.0},
      "claude-3-sonnet" => %{input: 3.0, output: 15.0}
    }

    rate = rates[model] || %{input: 1.0, output: 2.0}

    input_cost = (tokens[:prompt] || 0) * rate.input / 1_000_000
    output_cost = (tokens[:completion] || 0) * rate.output / 1_000_000

    input_cost + output_cost
  end

  defp calculate_cost_from_tokens(_tokens, _model), do: nil

  defp determine_success(measurements, metadata) do
    cond do
      # Explicit error or exception
      metadata[:error] -> false
      metadata[:exception] -> false
      # Check status in measurements
      measurements[:status] == :ok -> true
      measurements[:status] == :error -> false
      # Check for response (indicates success)
      metadata[:response] != nil -> true
      # Default to nil (unknown)
      true -> nil
    end
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
