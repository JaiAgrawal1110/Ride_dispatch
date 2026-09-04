defmodule DispatchCore.RideServer do
  @moduledoc """
  A GenServer representing a single active ride as its own lightweight
  BEAM process. Each ride gets matched to a driver, holds its own
  state, and broadcasts updates over PubSub to any subscribed Phoenix
  channel. Modeling rides this way is what makes many-simultaneous-rides
  concurrency cheap: thousands of these processes can run isolated from
  one another, each with its own tiny slice of memory and a scheduler
  that shares time fairly across all of them.
  """
  use GenServer, restart: :transient

  alias DispatchCore.Matcher
  alias Phoenix.PubSub

  defstruct [:ride_id, :rider_id, :pickup_location, :driver_id, status: :requested]

  # --- Client API -------------------------------------------------------

  def start_link(%{ride_id: ride_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(ride_id))
  end

  def via(ride_id), do: {:via, Registry, {DispatchCore.RideRegistry, ride_id}}

  @doc "Starts a new ride process under the DynamicSupervisor."
  def request_ride(ride_id, rider_id, pickup_location) do
    DispatchCore.RideSupervisor.start_ride(%{
      ride_id: ride_id,
      rider_id: rider_id,
      pickup_location: pickup_location
    })
  end

  def get_state(ride_id) do
    GenServer.call(via(ride_id), :get_state)
  end

  # --- Server callbacks ---------------------------------------------------

  @impl true
  def init(%{ride_id: ride_id, rider_id: rider_id, pickup_location: pickup_location}) do
    state = %__MODULE__{
      ride_id: ride_id,
      rider_id: rider_id,
      pickup_location: pickup_location
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
          DispatchCore.DriverRegistry.set_status(driver_id, :busy)
          %{state | driver_id: driver_id, status: :matched}

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

  defp broadcast(state) do
    PubSub.broadcast(DispatchCore.PubSub, "ride:" <> state.ride_id, {:ride_update, state})
  end
end
