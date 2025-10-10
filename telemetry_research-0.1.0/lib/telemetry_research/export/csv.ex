defmodule TelemetryResearch.Export.CSV do
  @moduledoc """
  Export experiment data to CSV format.

  CSV is ideal for:
  - Excel analysis
  - Python pandas: `pd.read_csv()`
  - R analysis: `read.csv()`
  - Quick visual inspection
  """

  @doc """
  Export events to CSV format.

  Flattens nested structures and creates a rectangular dataset
  suitable for statistical analysis.
  """
  def to_csv(events, experiment, opts) do
    path = Keyword.get(opts, :path, default_path(experiment, "csv"))
    flatten = Keyword.get(opts, :flatten, true)

    # Ensure directory exists
    File.mkdir_p!(Path.dirname(path))

    # Transform events to flat rows
    rows =
      events
      |> Enum.map(&event_to_row(&1, flatten))
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows) do
      {:error, :no_data}
    else
      # Write CSV
      file = File.open!(path, [:write, :utf8])

      # Write header
      headers = rows |> List.first() |> Map.keys() |> Enum.sort()
      write_csv_row(file, headers)

      # Write data rows
      Enum.each(rows, fn row ->
        values = Enum.map(headers, fn header -> Map.get(row, header) end)
        write_csv_row(file, values)
      end)

      File.close(file)

      {:ok, path}
    end
  end

  # Private functions

  defp event_to_row(event, flatten) do
    base = %{
      # Identifiers
      "event_id" => Map.get(event, :event_id),
      "experiment_id" => Map.get(event, :experiment_id),
      "experiment_name" => Map.get(event, :experiment_name),
      "condition" => Map.get(event, :condition),
      # Timing
      "timestamp" => Map.get(event, :timestamp),
      "datetime" => format_datetime(Map.get(event, :timestamp)),
      # Event details
      "event_name" => format_event_name(Map.get(event, :event_name)),
      # Metrics
      "latency_ms" => Map.get(event, :latency_ms),
      "cost_usd" => Map.get(event, :cost_usd),
      "success" => Map.get(event, :success),
      # Context
      "model" => Map.get(event, :model),
      "provider" => Map.get(event, :provider),
      "sample_id" => Map.get(event, :sample_id),
      "session_id" => Map.get(event, :session_id),
      "cohort" => Map.get(event, :cohort)
    }

    if flatten do
      # Add flattened metadata and measurements
      flattened_metadata = flatten_map(Map.get(event, :metadata), "metadata")
      flattened_measurements = flatten_map(Map.get(event, :measurements), "measurement")

      Map.merge(base, flattened_metadata)
      |> Map.merge(flattened_measurements)
    else
      base
    end
  end

  defp flatten_map(map, prefix) when is_map(map) do
    map
    |> Enum.flat_map(fn {key, value} ->
      flatten_value("#{prefix}_#{key}", value)
    end)
    |> Enum.into(%{})
  end

  defp flatten_map(_map, _prefix), do: %{}

  defp flatten_value(key, value) when is_map(value) do
    value
    |> Enum.flat_map(fn {k, v} ->
      flatten_value("#{key}_#{k}", v)
    end)
  end

  defp flatten_value(key, value) when is_list(value) do
    # Convert lists to comma-separated strings
    [{key, Enum.join(value, ",")}]
  end

  defp flatten_value(key, value) do
    [{key, value}]
  end

  defp format_event_name(event_name) when is_list(event_name) do
    Enum.join(event_name, ".")
  end

  defp format_event_name(event_name), do: to_string(event_name)

  defp format_datetime(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :microsecond)
    |> DateTime.to_iso8601()
  end

  defp format_datetime(_), do: nil

  defp write_csv_row(file, values) do
    row =
      values
      |> Enum.map(&csv_escape/1)
      |> Enum.join(",")

    IO.puts(file, row)
  end

  defp csv_escape(nil), do: ""

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      escaped = String.replace(value, "\"", "\"\"")
      "\"#{escaped}\""
    else
      value
    end
  end

  defp csv_escape(value) when is_boolean(value) do
    if value, do: "true", else: "false"
  end

  defp csv_escape(value) when is_atom(value) and not is_nil(value) do
    Atom.to_string(value)
  end

  defp csv_escape(value) when is_number(value) do
    to_string(value)
  end

  defp csv_escape(value) when is_list(value) do
    csv_escape(Enum.join(value, ";"))
  end

  defp csv_escape(value) when is_map(value) do
    csv_escape(Jason.encode!(value))
  end

  defp csv_escape(_value), do: ""

  defp default_path(experiment, extension) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "exports/#{experiment.name}_#{timestamp}.#{extension}"
  end
end
