defmodule DispatchCoreWeb.RideChannel do
  @moduledoc """
  Phoenix channel for a single ride's topic, "ride:<ride_id>".

  Riders request rides on this topic, drivers register/update location,
  and any client (notably the Elm dashboard) can join the topic to
  receive live `ride_update` events as the ride is matched.
  """
  use Phoenix.Channel

  alias DispatchCore.{RideServer, DriverRegistry}

  @impl true
  def join("ride:" <> ride_id, _payload, socket) do
    Phoenix.PubSub.subscribe(DispatchCore.PubSub, "ride:" <> ride_id)
    {:ok, assign(socket, :ride_id, ride_id)}
  end

  @impl true
  def handle_in(
        "request_ride",
        %{
          "rider_id" => rider_id,
          "lat" => lat,
          "lng" => lng,
          "dest_lat" => dest_lat,
          "dest_lng" => dest_lng
        } = payload,
        socket
      ) do
    ride_id = socket.assigns.ride_id
    demand_level = Map.get(payload, "demand_level", 0)

    RideServer.request_ride(
      ride_id,
      rider_id,
      {lat * 1.0, lng * 1.0},
      {dest_lat * 1.0, dest_lng * 1.0},
      demand_level
    )

    {:noreply, socket}
  end

  @impl true
  def handle_in(
        "register_driver",
        %{"driver_id" => driver_id, "lat" => lat, "lng" => lng},
        socket
      ) do
    DriverRegistry.register_driver(driver_id, {lat * 1.0, lng * 1.0})
    {:reply, :ok, socket}
  end

  @impl true
  def handle_in(
        "update_driver_location",
        %{"driver_id" => driver_id, "lat" => lat, "lng" => lng},
        socket
      ) do
    DriverRegistry.update_location(driver_id, {lat * 1.0, lng * 1.0})
    {:noreply, socket}
  end

  # Pushed out to every subscriber whenever a RideServer broadcasts a
  # status change (matched, no_drivers_available, etc).
  @impl true
  def handle_info({:ride_update, state}, socket) do
    push(socket, "ride_update", %{
      ride_id: state.ride_id,
      status: to_string(state.status),
      driver_id: state.driver_id,
      distance_km: state.distance_km,
      eta_minutes: state.eta_minutes,
      fare: state.fare
    })

    {:noreply, socket}
  end
end
