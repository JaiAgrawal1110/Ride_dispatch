defmodule DispatchCoreWeb.Router do
  use Phoenix.Router

  # No HTTP routes are needed for this simulator - the dispatch core is
  # driven entirely through the "/socket" WebSocket endpoint declared in
  # DispatchCoreWeb.Endpoint. Add `pipeline`/`scope` blocks here if you
  # later want a plain HTTP API alongside the channel.
end
