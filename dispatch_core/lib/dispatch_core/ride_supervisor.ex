defmodule DispatchCore.RideSupervisor do
  @moduledoc """
  DynamicSupervisor that starts one `DispatchCore.RideServer` per
  active ride. If a ride process crashes, it's simply gone (rides are
  `:transient`) rather than taking down the rest of the system - this
  is the BEAM "let it crash, isolate the blast radius" philosophy in
  practice.
  """
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_ride(args) do
    spec = {DispatchCore.RideServer, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
