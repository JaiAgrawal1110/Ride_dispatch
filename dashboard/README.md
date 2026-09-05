# Elm Live Dashboard

Frontend for the simulator — connects to the Elixir/Phoenix dispatch core
over WebSocket, lets you register drivers and request rides through real
form controls, and shows ride status (plus fare and ETA, once
`dispatch_core` is wired up to those services) updating live as it happens.

## Why it's built this way

Elm 0.19 has no native WebSocket package, and Phoenix channels use their
own message-framing protocol (JSON arrays: `[join_ref, ref, topic, event,
payload]`) on top of a raw socket anyway. So:

- `index.html` owns the actual WebSocket connection, talking to that wire
  protocol directly — no external `phoenix.js` dependency, just a plain
  `WebSocket` and some JSON encoding.
- `src/Main.elm` never touches the socket directly. It sends actions out
  through three ports (`joinRideChannel`, `registerDriver`, `requestRide`)
  and receives decoded `ride_update` events back through a
  `rideUpdateReceived` port.
- All state management, form validation, JSON decoding, and rendering
  stays in Elm's pure, strictly-typed world. The JS side is a
  deliberately thin transport shim — it doesn't make decisions, it just
  moves messages between the WebSocket and Elm's ports.

This is the realistic way FP principles (immutability, strict typing)
show up in frontend state management even when the platform (the browser)
forces you to drop into JS at the very edge.

## Files

```
elm.json        - Elm 0.19.1 project manifest
src/Main.elm    - dashboard app (model/update/view + ports + form validation)
index.html      - host page, raw WebSocket client, port wiring
```

## The three panels

1. **Watch a ride** — join a ride's topic to receive live updates for it.
2. **Register a driver** — driver ID + lat/lng.
3. **Request a ride** — rider ID, pickup lat/lng, destination lat/lng, and
   an optional demand level (0-3+, used for surge pricing). The
   destination is what lets `dispatch_core` compute an ETA once wired up
   to `eta_service`.

All three run basic validation — empty or non-numeric fields show a red
error banner instead of silently doing nothing.

## Building it

You'll need the [Elm compiler](https://guide.elm-lang.org/install/elm.html).

```bash
elm make src/Main.elm --output=main.js
```

## Running it two ways

**Standalone** — open `index.html` directly in a browser (with
`dispatch_core` running on `ws://localhost:4000/socket`). The page
detects it was opened as a local file and connects straight to port 4000.

**Via the orchestrator** — run `npm start` in `../orchestrator` and open
`http://localhost:8080` instead. The same `index.html` detects it's being
served over HTTP and connects through the orchestrator's proxy instead of
hardcoding port 4000 — no separate build or config needed for either mode.

## A note on testing in this environment

`Main.elm` was written and reviewed carefully against standard Elm 0.19
idioms (ports, `Json.Decode`, `Browser.element`, nested `case` pyramids
for form validation since Elm caps tuples at 3 elements), but it could
not be fully compiled in the sandbox that built this project — `elm make`
needs to reach `package.elm-lang.org` to verify dependencies, and that
host isn't reachable from there. Run `elm make` yourself the first time
to confirm it builds cleanly; if anything's off, the compiler's error
messages are unusually good at pointing straight at the fix. (In
practice, across several rounds of changes to this file during
development, it has compiled clean on the first try every time once
actually run against a real Elm installation.)
