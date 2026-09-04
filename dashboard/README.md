# Elm Live Dashboard

Frontend for the simulator — connects to the Elixir/Phoenix dispatch core
over WebSocket and shows ride status updates live as they happen.

## Why it's built this way

Elm 0.19 has no native WebSocket package, and Phoenix channels use their
own message-framing protocol on top of a raw socket anyway. So:

- `index.html` owns the actual WebSocket connection, using the official
  `phoenix.js` client (loaded from a CDN) to join channel topics.
- `src/Main.elm` never touches the socket directly. It sends topic names
  out through a `joinRideChannel` port, and receives decoded
  `ride_update` events back through a `rideUpdateReceived` port.
- All state management, JSON decoding, and rendering stays in Elm's pure,
  strictly-typed world. The JS side is a deliberately thin transport shim.

This is the realistic way FP principles (immutability, strict typing)
show up in frontend state management even when the platform (the browser)
forces you to drop into JS at the very edge.

## Files

```
elm.json        - Elm 0.19.1 project manifest
src/Main.elm    - dashboard app (model/update/view + ports)
index.html      - host page, phoenix.js socket, port wiring
```

## Building it

You'll need the [Elm compiler](https://guide.elm-lang.org/install/elm.html).

```bash
elm make src/Main.elm --output=main.js
```

Then open `index.html` in a browser (with the dispatch core running
on `ws://localhost:4000/socket`), type a ride ID like `ride-1` into the
box, click "Watch Ride", and trigger a ride request against that same
topic from another client to see the row update live.

## A note on testing in this environment

`Main.elm` was written and reviewed carefully against standard Elm 0.19
idioms (ports, `Json.Decode`, `Browser.element`), but it could not be
fully compiled in the sandbox that built this project — `elm make` needs
to reach `package.elm-lang.org` to verify dependencies, and that host
isn't reachable from there. Run `elm make` yourself the first time to
confirm it builds cleanly; if anything's off, the compiler's error
messages are unusually good at pointing straight at the fix.
