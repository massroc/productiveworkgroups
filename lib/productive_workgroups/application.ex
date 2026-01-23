defmodule ProductiveWorkgroups.Application do
  @moduledoc """
  The ProductiveWorkgroups Application.

  Starts the supervision tree including:
  - Ecto Repo
  - PubSub (for real-time features)
  - Presence (for participant tracking)
  - Phoenix Endpoint
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ProductiveWorkgroupsWeb.Telemetry,
      ProductiveWorkgroups.Repo,
      {DNSCluster, query: Application.get_env(:productive_workgroups, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ProductiveWorkgroups.PubSub},
      # Presence for tracking participants in sessions
      ProductiveWorkgroupsWeb.Presence,
      # Start the Finch HTTP client for Swoosh
      {Finch, name: ProductiveWorkgroups.Finch},
      # Start the Endpoint (http/https)
      ProductiveWorkgroupsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ProductiveWorkgroups.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ProductiveWorkgroupsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
