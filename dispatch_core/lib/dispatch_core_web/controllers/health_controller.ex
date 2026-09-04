defmodule DispatchCoreWeb.HealthController do
  use Phoenix.Controller

  def index(conn, _params) do
    text(conn, "Dispatch core is running. Connect via WebSocket at /socket.")
  end
end