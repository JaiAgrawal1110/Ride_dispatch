defmodule DispatchCoreWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dispatch_core

  # This is the actual WebSocket door into the dispatch core. The Elm
  # dashboard (and any driver/rider client) connects here.
  socket "/socket", DispatchCoreWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug DispatchCoreWeb.Router
end
