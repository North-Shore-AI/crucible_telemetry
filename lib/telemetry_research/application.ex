defmodule CrucibleTelemetry.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize global ETS table for experiment registry
    :ets.new(:crucible_telemetry_experiments, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true}
    ])

    children = [
      # Starts a worker by calling: CrucibleTelemetry.Worker.start_link(arg)
      # {CrucibleTelemetry.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CrucibleTelemetry.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
