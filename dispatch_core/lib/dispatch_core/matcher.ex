defmodule DispatchCore.Matcher do
  @moduledoc """
  Thin Elixir wrapper around the Erlang `nearest_driver` module.

  This is the concrete demonstration of same-runtime BEAM interop:
  `:nearest_driver.find_nearest/2` is a plain function call into a
  `.erl` module compiled into the very same application - not an API
  call, not a network hop, no serialization boundary at all.
  """

  alias DispatchCore.DriverRegistry

  @spec find_driver_for({float(), float()}) ::
          {:ok, term(), float()} | {:error, :no_drivers_available}
  def find_driver_for(rider_location) do
    drivers = DriverRegistry.list_drivers()
    # This is the actual Erlang call.
    :nearest_driver.find_nearest(rider_location, drivers)
  end
end
