defmodule CrucibleTelemetry.EventsTest do
  @moduledoc """
  Tests for the CrucibleTelemetry.Events module.
  """
  use ExUnit.Case, async: true

  alias CrucibleTelemetry.Events

  describe "standard_events/0" do
    test "returns a list of telemetry event names" do
      events = Events.standard_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be lists of atoms
      Enum.each(events, fn event ->
        assert is_list(event)
        assert Enum.all?(event, &is_atom/1)
      end)
    end

    test "includes req_llm events" do
      events = Events.standard_events()

      assert [:req_llm, :request, :start] in events
      assert [:req_llm, :request, :stop] in events
      assert [:req_llm, :request, :exception] in events
    end

    test "includes ensemble events" do
      events = Events.standard_events()

      assert [:ensemble, :prediction, :start] in events
      assert [:ensemble, :prediction, :stop] in events
      assert [:ensemble, :vote, :completed] in events
    end

    test "includes hedging events" do
      events = Events.standard_events()

      assert [:hedging, :request, :start] in events
      assert [:hedging, :request, :duplicated] in events
      assert [:hedging, :request, :stop] in events
    end

    test "includes training events" do
      events = Events.standard_events()

      assert [:crucible_train, :training, :start] in events
      assert [:crucible_train, :training, :stop] in events
      assert [:crucible_train, :epoch, :start] in events
      assert [:crucible_train, :epoch, :stop] in events
      assert [:crucible_train, :batch, :stop] in events
      assert [:crucible_train, :checkpoint, :saved] in events
    end

    test "includes deployment events" do
      events = Events.standard_events()

      assert [:crucible_deployment, :inference, :start] in events
      assert [:crucible_deployment, :inference, :stop] in events
      assert [:crucible_deployment, :inference, :exception] in events
    end

    test "includes framework events" do
      events = Events.standard_events()

      assert [:crucible_framework, :pipeline, :start] in events
      assert [:crucible_framework, :pipeline, :stop] in events
      assert [:crucible_framework, :stage, :start] in events
      assert [:crucible_framework, :stage, :stop] in events
    end
  end

  describe "training_events/0" do
    test "returns only training-related events" do
      events = Events.training_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be training events
      Enum.each(events, fn [prefix | _rest] ->
        assert prefix == :crucible_train
      end)
    end

    test "includes all expected training events" do
      events = Events.training_events()

      assert [:crucible_train, :training, :start] in events
      assert [:crucible_train, :training, :stop] in events
      assert [:crucible_train, :epoch, :start] in events
      assert [:crucible_train, :epoch, :stop] in events
      assert [:crucible_train, :batch, :stop] in events
      assert [:crucible_train, :checkpoint, :saved] in events
    end
  end

  describe "deployment_events/0" do
    test "returns only deployment-related events" do
      events = Events.deployment_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be deployment events
      Enum.each(events, fn [prefix | _rest] ->
        assert prefix == :crucible_deployment
      end)
    end

    test "includes all expected deployment events" do
      events = Events.deployment_events()

      assert [:crucible_deployment, :inference, :start] in events
      assert [:crucible_deployment, :inference, :stop] in events
      assert [:crucible_deployment, :inference, :exception] in events
    end
  end

  describe "framework_events/0" do
    test "returns only framework-related events" do
      events = Events.framework_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be framework events
      Enum.each(events, fn [prefix | _rest] ->
        assert prefix == :crucible_framework
      end)
    end

    test "includes all expected framework events" do
      events = Events.framework_events()

      assert [:crucible_framework, :pipeline, :start] in events
      assert [:crucible_framework, :pipeline, :stop] in events
      assert [:crucible_framework, :stage, :start] in events
      assert [:crucible_framework, :stage, :stop] in events
    end
  end

  describe "llm_events/0" do
    test "returns only LLM-related events" do
      events = Events.llm_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be req_llm events
      Enum.each(events, fn [prefix | _rest] ->
        assert prefix == :req_llm
      end)
    end

    test "includes all expected LLM events" do
      events = Events.llm_events()

      assert [:req_llm, :request, :start] in events
      assert [:req_llm, :request, :stop] in events
      assert [:req_llm, :request, :exception] in events
    end
  end

  describe "ensemble_events/0" do
    test "returns only ensemble-related events" do
      events = Events.ensemble_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be ensemble events
      Enum.each(events, fn [prefix | _rest] ->
        assert prefix == :ensemble
      end)
    end
  end

  describe "hedging_events/0" do
    test "returns only hedging-related events" do
      events = Events.hedging_events()

      assert is_list(events)
      refute Enum.empty?(events)

      # All events should be hedging events
      Enum.each(events, fn [prefix | _rest] ->
        assert prefix == :hedging
      end)
    end
  end

  describe "events_by_category/0" do
    test "returns a map of categories to events" do
      categories = Events.events_by_category()

      assert is_map(categories)
      assert Map.has_key?(categories, :llm)
      assert Map.has_key?(categories, :training)
      assert Map.has_key?(categories, :deployment)
      assert Map.has_key?(categories, :framework)
      assert Map.has_key?(categories, :ensemble)
      assert Map.has_key?(categories, :hedging)
    end

    test "each category contains valid events" do
      categories = Events.events_by_category()

      Enum.each(categories, fn {_category, events} ->
        assert is_list(events)

        Enum.each(events, fn event ->
          assert is_list(event)
          assert Enum.all?(event, &is_atom/1)
        end)
      end)
    end
  end

  describe "event_info/1" do
    test "returns info for known events" do
      info = Events.event_info([:crucible_train, :training, :start])

      assert is_map(info)
      assert info.category == :training
      assert is_binary(info.description)
    end

    test "returns nil for unknown events" do
      info = Events.event_info([:unknown, :event, :name])

      assert info == nil
    end

    test "returns info with correct category for each event type" do
      # Test a sample from each category
      assert Events.event_info([:req_llm, :request, :start]).category == :llm
      assert Events.event_info([:crucible_train, :epoch, :stop]).category == :training
      assert Events.event_info([:crucible_deployment, :inference, :stop]).category == :deployment
      assert Events.event_info([:crucible_framework, :pipeline, :start]).category == :framework
      assert Events.event_info([:ensemble, :prediction, :start]).category == :ensemble
      assert Events.event_info([:hedging, :request, :start]).category == :hedging
    end
  end
end
