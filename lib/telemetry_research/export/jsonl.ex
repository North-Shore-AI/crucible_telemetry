defmodule CrucibleTelemetry.Export.JSONL do
  @moduledoc """
  Export experiment data to JSON Lines format.

  JSON Lines (newline-delimited JSON) is perfect for:
  - jq queries: `cat data.jsonl | jq '.latency_ms'`
  - Streaming processing
  - Log analysis tools
  - Line-by-line processing in any language
  """

  @doc """
  Export events to JSON Lines format.

  Each event is encoded as a single JSON object on its own line.
  """
  def to_jsonl(events, experiment, opts) do
    path = Keyword.get(opts, :path, default_path(experiment, "jsonl"))
    pretty = Keyword.get(opts, :pretty, false)

    # Ensure directory exists
    File.mkdir_p!(Path.dirname(path))

    if Enum.empty?(events) do
      {:error, :no_data}
    else
      # Write JSON Lines
      file = File.open!(path, [:write])

      Enum.each(events, fn event ->
        json =
          if pretty do
            Jason.encode!(event, pretty: true)
          else
            Jason.encode!(event)
          end

        IO.puts(file, json)
      end)

      File.close(file)

      {:ok, path}
    end
  end

  # Private functions

  defp default_path(experiment, extension) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "exports/#{experiment.name}_#{timestamp}.#{extension}"
  end
end
