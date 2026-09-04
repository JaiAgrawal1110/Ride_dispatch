defmodule DispatchCoreWeb.UserSocket do
  use Phoenix.Socket

  # Riders/drivers/dashboard clients join topics like "ride:abc123".
  channel "ride:*", DispatchCoreWeb.RideChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
