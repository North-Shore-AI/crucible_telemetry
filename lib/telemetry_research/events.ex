defmodule CrucibleTelemetry.Events do
  @moduledoc """
  Standard telemetry event definitions for the Crucible ecosystem.

  This module provides a centralized registry of all telemetry events that
  CrucibleTelemetry can capture and process. Events are organized by category
  and include metadata about each event type.

  ## Categories

  - `:llm` - LLM API request events (req_llm)
  - `:ensemble` - Ensemble prediction and voting events
  - `:hedging` - Request hedging events
  - `:training` - ML training job events (crucible_train)
  - `:deployment` - Model deployment and inference events
  - `:framework` - Pipeline and stage execution events
  - `:trace` - Causal reasoning trace events
  - `:tools` - Tool invocation events

  ## Examples

      # Get all standard events
      events = CrucibleTelemetry.Events.standard_events()

      # Get only training events
      training = CrucibleTelemetry.Events.training_events()

      # Get event info
      info = CrucibleTelemetry.Events.event_info([:crucible_train, :epoch, :stop])
      # => %{category: :training, description: "Epoch completed with metrics"}
  """

  @typedoc "A telemetry event name as a list of atoms"
  @type event_name :: [atom()]

  @typedoc "Event category identifier"
  @type category ::
          :llm | :ensemble | :hedging | :training | :deployment | :framework | :trace | :tools

  @typedoc "Event information map"
  @type event_info :: %{
          category: category(),
          description: String.t()
        }

  # LLM Events (req_llm)
  @llm_events [
    [:req_llm, :request, :start],
    [:req_llm, :request, :stop],
    [:req_llm, :request, :exception]
  ]

  # Ensemble Events
  @ensemble_events [
    [:ensemble, :prediction, :start],
    [:ensemble, :prediction, :stop],
    [:ensemble, :vote, :completed]
  ]

  # Hedging Events
  @hedging_events [
    [:hedging, :request, :start],
    [:hedging, :request, :duplicated],
    [:hedging, :request, :stop]
  ]

  # Training Events (crucible_train)
  @training_events [
    [:crucible_train, :training, :start],
    [:crucible_train, :training, :stop],
    [:crucible_train, :epoch, :start],
    [:crucible_train, :epoch, :stop],
    [:crucible_train, :batch, :stop],
    [:crucible_train, :checkpoint, :saved]
  ]

  # Deployment Events (crucible_deployment)
  @deployment_events [
    [:crucible_deployment, :inference, :start],
    [:crucible_deployment, :inference, :stop],
    [:crucible_deployment, :inference, :exception]
  ]

  # Framework Events (crucible_framework)
  @framework_events [
    [:crucible_framework, :pipeline, :start],
    [:crucible_framework, :pipeline, :stop],
    [:crucible_framework, :stage, :start],
    [:crucible_framework, :stage, :stop]
  ]

  # Trace Events
  @trace_events [
    [:causal_trace, :event, :created]
  ]

  # Tool Events
  @tool_events [
    [:altar, :tool, :start],
    [:altar, :tool, :stop]
  ]

  # All standard events combined
  @standard_events @llm_events ++
                     @ensemble_events ++
                     @hedging_events ++
                     @training_events ++
                     @deployment_events ++
                     @framework_events ++
                     @trace_events ++
                     @tool_events

  # Event descriptions
  @event_descriptions %{
    # LLM Events
    [:req_llm, :request, :start] => "LLM request started",
    [:req_llm, :request, :stop] => "LLM request completed",
    [:req_llm, :request, :exception] => "LLM request failed with exception",
    # Ensemble Events
    [:ensemble, :prediction, :start] => "Ensemble prediction started",
    [:ensemble, :prediction, :stop] => "Ensemble prediction completed",
    [:ensemble, :vote, :completed] => "Ensemble voting completed",
    # Hedging Events
    [:hedging, :request, :start] => "Hedging request started",
    [:hedging, :request, :duplicated] => "Request duplicated for hedging",
    [:hedging, :request, :stop] => "Hedging request completed",
    # Training Events
    [:crucible_train, :training, :start] => "Training job started",
    [:crucible_train, :training, :stop] => "Training job completed",
    [:crucible_train, :epoch, :start] => "Epoch started",
    [:crucible_train, :epoch, :stop] => "Epoch completed with metrics",
    [:crucible_train, :batch, :stop] => "Batch completed with loss",
    [:crucible_train, :checkpoint, :saved] => "Model checkpoint saved",
    # Deployment Events
    [:crucible_deployment, :inference, :start] => "Inference request started",
    [:crucible_deployment, :inference, :stop] => "Inference request completed",
    [:crucible_deployment, :inference, :exception] => "Inference request failed",
    # Framework Events
    [:crucible_framework, :pipeline, :start] => "Pipeline execution started",
    [:crucible_framework, :pipeline, :stop] => "Pipeline execution completed",
    [:crucible_framework, :stage, :start] => "Stage execution started",
    [:crucible_framework, :stage, :stop] => "Stage execution completed",
    # Trace Events
    [:causal_trace, :event, :created] => "Causal reasoning event created",
    # Tool Events
    [:altar, :tool, :start] => "Tool invocation started",
    [:altar, :tool, :stop] => "Tool invocation completed"
  }

  @doc """
  Returns all standard telemetry events tracked by CrucibleTelemetry.

  ## Examples

      iex> events = CrucibleTelemetry.Events.standard_events()
      iex> [:req_llm, :request, :start] in events
      true
  """
  @spec standard_events() :: [event_name()]
  def standard_events, do: @standard_events

  @doc """
  Returns training-related events (crucible_train).

  These events track ML training job lifecycle including epochs, batches,
  and checkpoints.

  ## Examples

      iex> events = CrucibleTelemetry.Events.training_events()
      iex> [:crucible_train, :epoch, :stop] in events
      true
  """
  @spec training_events() :: [event_name()]
  def training_events, do: @training_events

  @doc """
  Returns deployment-related events (crucible_deployment).

  These events track model inference requests and deployment lifecycle.

  ## Examples

      iex> events = CrucibleTelemetry.Events.deployment_events()
      iex> [:crucible_deployment, :inference, :stop] in events
      true
  """
  @spec deployment_events() :: [event_name()]
  def deployment_events, do: @deployment_events

  @doc """
  Returns framework-related events (crucible_framework).

  These events track pipeline and stage execution in the framework.

  ## Examples

      iex> events = CrucibleTelemetry.Events.framework_events()
      iex> [:crucible_framework, :pipeline, :start] in events
      true
  """
  @spec framework_events() :: [event_name()]
  def framework_events, do: @framework_events

  @doc """
  Returns LLM-related events (req_llm).

  These events track LLM API requests and responses.

  ## Examples

      iex> events = CrucibleTelemetry.Events.llm_events()
      iex> [:req_llm, :request, :stop] in events
      true
  """
  @spec llm_events() :: [event_name()]
  def llm_events, do: @llm_events

  @doc """
  Returns ensemble-related events.

  These events track ensemble predictions and voting.

  ## Examples

      iex> events = CrucibleTelemetry.Events.ensemble_events()
      iex> [:ensemble, :prediction, :stop] in events
      true
  """
  @spec ensemble_events() :: [event_name()]
  def ensemble_events, do: @ensemble_events

  @doc """
  Returns hedging-related events.

  These events track request hedging and duplication.

  ## Examples

      iex> events = CrucibleTelemetry.Events.hedging_events()
      iex> [:hedging, :request, :stop] in events
      true
  """
  @spec hedging_events() :: [event_name()]
  def hedging_events, do: @hedging_events

  @doc """
  Returns trace-related events.

  These events track causal reasoning traces.

  ## Examples

      iex> events = CrucibleTelemetry.Events.trace_events()
      iex> [:causal_trace, :event, :created] in events
      true
  """
  @spec trace_events() :: [event_name()]
  def trace_events, do: @trace_events

  @doc """
  Returns tool-related events.

  These events track tool invocations.

  ## Examples

      iex> events = CrucibleTelemetry.Events.tool_events()
      iex> [:altar, :tool, :start] in events
      true
  """
  @spec tool_events() :: [event_name()]
  def tool_events, do: @tool_events

  @doc """
  Returns events organized by category.

  ## Categories

  - `:llm` - LLM API request events
  - `:ensemble` - Ensemble prediction events
  - `:hedging` - Request hedging events
  - `:training` - ML training events
  - `:deployment` - Model deployment events
  - `:framework` - Pipeline/stage events
  - `:trace` - Causal trace events
  - `:tools` - Tool invocation events

  ## Examples

      iex> categories = CrucibleTelemetry.Events.events_by_category()
      iex> Map.keys(categories)
      [:deployment, :ensemble, :framework, :hedging, :llm, :tools, :trace, :training]
  """
  @spec events_by_category() :: %{category() => [event_name()]}
  def events_by_category do
    %{
      llm: @llm_events,
      ensemble: @ensemble_events,
      hedging: @hedging_events,
      training: @training_events,
      deployment: @deployment_events,
      framework: @framework_events,
      trace: @trace_events,
      tools: @tool_events
    }
  end

  @doc """
  Returns information about a specific event.

  Returns `nil` if the event is not a known standard event.

  ## Parameters

  - `event_name` - The telemetry event name (list of atoms)

  ## Returns

  - `%{category: atom(), description: String.t()}` - Event info map
  - `nil` - If event is not recognized

  ## Examples

      iex> CrucibleTelemetry.Events.event_info([:crucible_train, :epoch, :stop])
      %{category: :training, description: "Epoch completed with metrics"}

      iex> CrucibleTelemetry.Events.event_info([:unknown, :event])
      nil
  """
  @spec event_info(event_name()) :: event_info() | nil
  def event_info(event_name) do
    case @event_descriptions[event_name] do
      nil ->
        nil

      description ->
        %{
          category: get_category(event_name),
          description: description
        }
    end
  end

  # Mapping of event prefixes to categories
  @prefix_to_category %{
    req_llm: :llm,
    ensemble: :ensemble,
    hedging: :hedging,
    crucible_train: :training,
    crucible_deployment: :deployment,
    crucible_framework: :framework,
    causal_trace: :trace,
    altar: :tools
  }

  # Get category for an event based on its prefix
  @spec get_category(event_name()) :: category()
  defp get_category([prefix | _]) do
    Map.get(@prefix_to_category, prefix, :unknown)
  end
end
