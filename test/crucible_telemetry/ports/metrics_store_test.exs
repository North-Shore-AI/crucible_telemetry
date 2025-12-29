defmodule CrucibleTelemetry.Ports.MetricsStoreTest do
  @moduledoc """
  Tests for the MetricsStore port behaviour.
  """
  use ExUnit.Case, async: true

  alias CrucibleTelemetry.Ports.MetricsStore

  describe "port behaviour" do
    test "defines expected callbacks" do
      callbacks = MetricsStore.behaviour_info(:callbacks)

      expected_callbacks = [
        {:record, 5},
        {:flush, 2},
        {:read, 2}
      ]

      for callback <- expected_callbacks do
        assert callback in callbacks,
               "Expected callback #{inspect(callback)} not found in #{inspect(callbacks)}"
      end
    end
  end
end
