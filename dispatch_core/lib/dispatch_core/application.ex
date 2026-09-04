defmodule DispatchCore.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: DispatchCore.PubSub},
      {Registry, keys: :unique, name: DispatchCore.RideRegistry},
      DispatchCore.DriverRegistry,
      DispatchCore.RideSupervisor,
      DispatchCoreWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DispatchCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DispatchCoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
