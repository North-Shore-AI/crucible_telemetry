defmodule CrucibleTelemetry.Export do
  @moduledoc """
  Export experiment data in multiple formats for analysis.

  Supports various export formats optimized for different analysis tools:

  - CSV - For Excel, pandas, R
  - JSON Lines - For streaming analysis and jq
  - Parquet - For big data tools (future)
  """

  alias CrucibleTelemetry.{Experiment, Store}
  alias CrucibleTelemetry.Export.{CSV, JSONL}

  @doc """
  Export experiment data in the specified format.

  ## Formats

  - `:csv` - Comma-separated values (Excel, pandas, R)
  - `:jsonl` - JSON Lines (streaming, jq)

  ## Options

  - `:path` - Output file path (default: auto-generated)
  - `:anonymize` - Remove PII fields (default: false)
  - `:flatten` - Flatten nested structures (default: true)

  ## Examples

      # Export to CSV
      {:ok, path} = CrucibleTelemetry.Export.export("exp-123", :csv,
        path: "results/experiment.csv"
      )

      # Export to JSON Lines
      {:ok, path} = CrucibleTelemetry.Export.export("exp-123", :jsonl,
        path: "results/experiment.jsonl",
        anonymize: true
      )
  """
  def export(experiment_id, format, opts \\ []) do
    with {:ok, experiment} <- Experiment.get(experiment_id) do
      data = Store.get_all(experiment_id)

      case format do
        :csv -> CSV.to_csv(data, experiment, opts)
        :jsonl -> JSONL.to_jsonl(data, experiment, opts)
        _ -> {:error, :unsupported_format}
      end
    end
  end

  @doc """
  Export multiple experiments to a single file.

  Useful for comparing experiments side-by-side.
  """
  def export_multiple(experiment_ids, format, opts \\ []) do
    experiments =
      experiment_ids
      |> Enum.map(&Experiment.get/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, exp} -> exp end)

    all_data =
      experiments
      |> Enum.flat_map(fn exp ->
        Store.get_all(exp.id)
      end)

    # Use first experiment as template
    experiment = List.first(experiments)

    case format do
      :csv -> CSV.to_csv(all_data, experiment, opts)
      :jsonl -> JSONL.to_jsonl(all_data, experiment, opts)
      _ -> {:error, :unsupported_format}
    end
  end
end
