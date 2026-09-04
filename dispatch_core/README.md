# Dispatch Core — Elixir + Erlang

The heart of the simulator. One Mix project that contains both the
Elixir/Phoenix application *and* a raw Erlang matching module, compiled
together into a single BEAM application.

## What's in here

```
mix.exs
config/config.exs
src/
  nearest_driver.erl          <- raw Erlang, the matching algorithm
lib/
  dispatch_core/
    application.ex            <- supervision tree
    driver_registry.ex        <- ETS-backed driver location/status store
    matcher.ex                <- calls :nearest_driver.find_nearest/2
    ride_server.ex            <- GenServer, one process per active ride
    ride_supervisor.ex        <- DynamicSupervisor for ride processes
  dispatch_core_web/
    endpoint.ex                <- Phoenix.Endpoint, exposes /socket
    router.ex                  <- empty (no HTTP routes needed)
    user_socket.ex              <- Phoenix.Socket, "ride:*" channel
    channels/ride_channel.ex   <- handles request_ride / driver events
```

## The BEAM interop, concretely

`DispatchCore.Matcher.find_driver_for/1` calls `:nearest_driver.find_nearest/2`
directly. That's it — no HTTP client, no serialization, no port. Elixir
compiles to the same bytecode Erlang does, so this is a plain function call
into a module built from `src/nearest_driver.erl`. You can see this wired up
via `erlc_paths: ["src"]` in `mix.exs`.

## Running it

You'll need Erlang/OTP (26+) and Elixir (1.15+) installed locally.

```bash
mix deps.get
mix run --no-halt
```

This starts the app listening on `ws://localhost:4000/socket`.

(There's also a `.vscode/tasks.json` at the project root — press
`Ctrl+Shift+B` from the workspace root to start this alongside every
other service at once.)

## Trying it out manually

The easiest way to poke at this without writing a client is `wscat`
(`npm install -g wscat`) using the Phoenix v2 wire protocol, or just wire up
the Elm dashboard (in `../dashboard`), which does this for you.

Rough manual flow using Phoenix's JS client in a browser console pointed at
`ws://localhost:4000/socket`:

1. Join topic `ride:ride-1`.
2. Push `"register_driver"` with `{"driver_id": "d1", "lat": 12.9, "lng": 77.6}`
   on the same topic (in a real system, drivers would each join their own
   presence — this simulator keeps it on the ride topic for simplicity).
3. Push `"request_ride"` with `{"rider_id": "r1", "lat": 12.91, "lng": 77.61}`.
4. You should receive a `"ride_update"` push back with
   `{"status": "matched", "driver_id": "d1"}`.

If no driver was registered first, you'll get
`{"status": "no_drivers_available", "driver_id": null}` instead.

## This was actually compiled and run

`src/nearest_driver.erl` — the piece with no external dependencies — was
installed (Erlang/OTP) and exercised directly in the sandbox that built
this project:

```
$ erlc nearest_driver.erl
COMPILE OK

$ erl -noshell -pa . -eval '...'
{ok,d1,0.014142135623734417}
{error,no_drivers_available}
{error,no_drivers_available}
```

It correctly picked the nearest available driver and correctly reported
`no_drivers_available` for an empty or all-busy driver list.

The Elixir/Phoenix layer around it (GenServer, DynamicSupervisor, Registry,
Phoenix.Channel) was written by hand following standard OTP/Phoenix
conventions, but wasn't compiled in that sandbox since there was no
Mix/Hex toolchain available there. Run `mix deps.get` yourself as the
first step — the compiler's error messages are very good about pointing
at anything that needs a tweak.

## Notes / things intentionally simplified

- No persistence (Ecto/DB) — rides and driver state live only in memory,
  which is enough for a learning project.
- No auth on the socket — `connect/3` accepts everyone. Don't ship this as-is.
- Distance is a flat Euclidean calculation in `nearest_driver.erl`, not a
  real-world geo/haversine distance — the algorithm shape is the point.
- `secret_key_base` in `config.exs` is a placeholder. Regenerate with
  `mix phx.gen.secret` before doing anything beyond local dev.
