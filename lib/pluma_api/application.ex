defmodule PlumaApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      PlumaApi.Repo,
      # Start the Telemetry supervisor
      PlumaApiWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PlumaApi.PubSub},
      # Start the Endpoint (http/https)
      PlumaApiWeb.Endpoint
      # Start a worker by calling: PlumaApi.Worker.start_link(arg)
      # {PlumaApi.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PlumaApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PlumaApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
