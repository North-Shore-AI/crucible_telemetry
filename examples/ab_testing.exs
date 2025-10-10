# A/B Testing Example for TelemetryResearch
#
# This example demonstrates how to run concurrent experiments
# to compare different approaches (e.g., single model vs. ensemble)

Application.ensure_all_started(:telemetry_research)

IO.puts("\n=== A/B Testing Example ===\n")

# 1. Start control experiment (single model)
IO.puts("1. Starting control experiment (single model)...")

{:ok, control_exp} =
  CrucibleTelemetry.start_experiment(
    name: "control_single_model",
    hypothesis: "Single GPT-4 baseline",
    condition: "control",
    tags: ["ab_test", "baseline"]
  )

IO.puts("   Control experiment ID: #{control_exp.id}")

# 2. Start treatment experiment (ensemble)
IO.puts("\n2. Starting treatment experiment (ensemble)...")

{:ok, treatment_exp} =
  CrucibleTelemetry.start_experiment(
    name: "treatment_ensemble",
    hypothesis: "5-model ensemble improves reliability",
    condition: "treatment",
    tags: ["ab_test", "ensemble"]
  )

IO.puts("   Treatment experiment ID: #{treatment_exp.id}")

# 3. Simulate control group requests (single model)
IO.puts("\n3. Simulating control group (10 requests)...")

Enum.each(1..10, fn i ->
  # Single model request - faster but occasionally fails
  # 90% success rate
  success = :rand.uniform() > 0.1

  :telemetry.execute(
    [:req_llm, :request, :stop],
    %{duration: 80_000_000 + :rand.uniform(40_000_000)},
    %{
      provider: :openai,
      model: "gpt-4",
      request_id: "control-#{i}",
      tokens: %{prompt: 150, completion: 300, total: 450},
      cost: 0.002,
      response: if(success, do: "result", else: nil),
      error: if(success, do: nil, else: "timeout")
    }
  )

  Process.sleep(5)
end)

IO.puts("   Control requests complete")

# 4. Simulate treatment group requests (ensemble)
IO.puts("\n4. Simulating treatment group (10 requests)...")

Enum.each(1..10, fn i ->
  # Ensemble approach - slower but more reliable
  # 98% success rate
  success = :rand.uniform() > 0.02

  # Ensemble start
  :telemetry.execute(
    [:ensemble, :prediction, :start],
    %{system_time: System.system_time()},
    %{
      query: "test query #{i}",
      models: [:gemini, :openai, :anthropic],
      strategy: :majority_vote,
      prediction_id: "pred-#{i}"
    }
  )

  Process.sleep(5)

  # Ensemble stop - higher latency due to multiple models
  :telemetry.execute(
    [:ensemble, :prediction, :stop],
    %{duration: 200_000_000 + :rand.uniform(100_000_000)},
    %{
      prediction_id: "pred-#{i}",
      result: if(success, do: "consensus result", else: nil),
      total_cost: 0.006,
      # 3x cost for 3 models
      models_succeeded: if(success, do: 3, else: 2),
      models_failed: if(success, do: 0, else: 1),
      error: if(success, do: nil, else: "model_failure")
    }
  )

  Process.sleep(5)
end)

IO.puts("   Treatment requests complete")

# 5. Stop both experiments
IO.puts("\n5. Stopping experiments...")
{:ok, _} = CrucibleTelemetry.stop_experiment(control_exp.id)
{:ok, _} = CrucibleTelemetry.stop_experiment(treatment_exp.id)
IO.puts("   Both experiments stopped")

# 6. Calculate and compare metrics
IO.puts("\n6. Calculating metrics...")

control_metrics = CrucibleTelemetry.calculate_metrics(control_exp.id)
treatment_metrics = CrucibleTelemetry.calculate_metrics(treatment_exp.id)

IO.puts("\n   CONTROL (Single Model):")
IO.puts("   - Events: #{control_metrics.summary.total_events}")
IO.puts("   - Mean latency: #{Float.round(control_metrics.latency.mean || 0, 2)}ms")
IO.puts("   - Total cost: $#{Float.round(control_metrics.cost.total || 0, 4)}")

IO.puts(
  "   - Success rate: #{Float.round((control_metrics.reliability.success_rate || 0) * 100, 2)}%"
)

IO.puts("\n   TREATMENT (Ensemble):")
IO.puts("   - Events: #{treatment_metrics.summary.total_events}")
IO.puts("   - Mean latency: #{Float.round(treatment_metrics.latency.mean || 0, 2)}ms")
IO.puts("   - Total cost: $#{Float.round(treatment_metrics.cost.total || 0, 4)}")

IO.puts(
  "   - Success rate: #{Float.round((treatment_metrics.reliability.success_rate || 0) * 100, 2)}%"
)

# 7. Calculate improvements
IO.puts("\n7. Analysis:")

latency_change =
  if control_metrics.latency.mean && treatment_metrics.latency.mean do
    ((treatment_metrics.latency.mean - control_metrics.latency.mean) /
       control_metrics.latency.mean * 100)
    |> Float.round(1)
  else
    0
  end

cost_increase =
  ((treatment_metrics.cost.total - control_metrics.cost.total) /
     control_metrics.cost.total * 100)
  |> Float.round(1)

reliability_improvement =
  ((treatment_metrics.reliability.success_rate - control_metrics.reliability.success_rate) *
     100)
  |> Float.round(2)

IO.puts("   - Latency change: #{latency_change}%")
IO.puts("   - Cost increase: #{cost_increase}%")
IO.puts("   - Reliability improvement: +#{reliability_improvement} percentage points")

# 8. Export comparison data
IO.puts("\n8. Exporting results...")

{:ok, control_csv} =
  CrucibleTelemetry.export(control_exp.id, :csv, path: "exports/ab_test_control.csv")

{:ok, treatment_csv} =
  CrucibleTelemetry.export(treatment_exp.id, :csv, path: "exports/ab_test_treatment.csv")

IO.puts("   Control CSV: #{control_csv}")
IO.puts("   Treatment CSV: #{treatment_csv}")

# 9. Clean up
IO.puts("\n9. Cleaning up...")
CrucibleTelemetry.Experiment.cleanup(control_exp.id)
CrucibleTelemetry.Experiment.cleanup(treatment_exp.id)

IO.puts("\n=== A/B Test Complete ===")
IO.puts("\nConclusion:")

IO.puts("The ensemble approach showed #{reliability_improvement}pp better reliability")

IO.puts("but with #{latency_change}% latency change and #{cost_increase}% higher cost.")
IO.puts("\n")
