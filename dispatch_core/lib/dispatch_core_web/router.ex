defmodule DispatchCoreWeb.Router do
  use Phoenix.Router

  get "/", DispatchCoreWeb.HealthController, :index
end