defmodule DispatchCore.RideServer do
  @moduledoc """
  A GenServer representing a single active ride as its own lightweight
  BEAM process. Each ride gets matched to a driver, holds its own
  state, and broadcasts updates over PubSub to any subscribed Phoenix
  channel. Modeling rides this way is what makes many-simultaneous-rides
  concurrency cheap: thousands of these processes can run isolated from
  one another, each with its own tiny slice of memory and a scheduler
  that shares time fairly across all of them.

  Once a ride is matched to a driver, this process also calls out to
  the standalone Haskell ETA service and Scala fare service over HTTP
  (see DispatchCore.ExternalServices) - the concrete "different
  runtime, network boundary" pattern this whole project is built to
  demonstrate. Both calls are best-effort: if either service isn't
  running, the ride still completes, just without that field filled in.
  """
  use GenServer, restart: :transient

  require Logger

  alias DispatchCore.{Matcher, ExternalServices, DriverRegistry}
  alias Phoenix.PubSub

  defstruct [
    :ride_id,
    :rider_id,
    :pickup_location,
    :destination_location,
    :demand_level,
    :driver_id,
    :distance_km,
    :eta_minutes,
    :fare,
    status: :requested
  ]

  # --- Client API -------------------------------------------------------

  def start_link(%{ride_id: ride_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(ride_id))
  end

  def via(ride_id), do: {:via, Registry, {DispatchCore.RideRegistry, ride_id}}

  @doc """
  Starts a new ride process under the DynamicSupervisor.

  `pickup_location` and `destination_location` are `{lat, lng}` tuples.
  `demand_level` is a coarse 0-3+ signal forwarded to the fare service
  for surge pricing; it defaults to 0 (no surge) if not given.
  """
  def request_ride(
        ride_id,
        rider_id,
        pickup_location,
        destination_location,
        demand_level \\ 0
      ) do
    DispatchCore.RideSupervisor.start_ride(%{
      ride_id: ride_id,
      rider_id: rider_id,
      pickup_location: pickup_location,
      destination_location: destination_location,
      demand_level: demand_level
    })
  end

  def get_state(ride_id) do
    GenServer.call(via(ride_id), :get_state)
  end

  # --- Server callbacks ---------------------------------------------------

  @impl true
  def init(%{
        ride_id: ride_id,
        rider_id: rider_id,
        pickup_location: pickup_location,
        destination_location: destination_location,
        demand_level: demand_level
      }) do
    state = %__MODULE__{
      ride_id: ride_id,
      rider_id: rider_id,
      pickup_location: pickup_location,
      destination_location: destination_location,
      demand_level: demand_level
    }

    # Kick off matching right after init rather than blocking start_link.
    send(self(), :match_driver)
    {:ok, state}
  end

  @impl true
  def handle_info(:match_driver, state) do
    new_state =
      case Matcher.find_driver_for(state.pickup_location) do
        {:ok, driver_id, _distance} ->
          DriverRegistry.set_status(driver_id, :busy)

          %{state | driver_id: driver_id, status: :matched}
          |> attach_eta_and_fare()

        {:error, :no_drivers_available} ->
          %{state | status: :no_drivers_available}
      end

    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Calls out to the Haskell ETA service, then the Scala fare service
  # (reusing the distance the ETA service already computed, rather than
  # calculating it twice) once a ride is matched. Falls back to leaving
  # these fields nil - logging a warning rather than crashing - if
  # either service isn't reachable.
  defp attach_eta_and_fare(%__MODULE__{} = state) do
    with {:ok, %{distance_km: distance_km, eta_minutes: eta_minutes}} <-
           ExternalServices.get_eta(state.pickup_location, state.destination_location),
         {:ok, %{total_fare: total_fare}} <-
           ExternalServices.get_fare(distance_km, state.demand_level) do
      %{state | distance_km: distance_km, eta_minutes: eta_minutes, fare: total_fare}
    else
      {:error, reason} ->
        Logger.warning("Ride #{state.ride_id}: could not fetch eta/fare (#{inspect(reason)})")
        state
    end
  end

  defp broadcast(state) do
    PubSub.broadcast(DispatchCore.PubSub, "ride:" <> state.ride_id, {:ride_update, state})
  end
end
