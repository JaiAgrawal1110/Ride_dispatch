import Config

config :dispatch_core, DispatchCoreWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  server: true,
  # For local/dev use only. Regenerate with `mix phx.gen.secret` for any
  # real deployment.
  secret_key_base:
    "REPLACE_ME_WITH_OUTPUT_OF_mix_phx_gen_secret_this_needs_to_be_at_least_64_bytes_long",
  # Dev-only: allows the Elm dashboard (served from a different origin/port)
  # to open a WebSocket connection to this endpoint.
  check_origin: false,
  pubsub_server: DispatchCore.PubSub

config :phoenix, :json_library, Jason

config :logger, :console, format: "[$level] $message\n"
