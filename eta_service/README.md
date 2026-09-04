# Haskell ETA / Route Engine

A standalone service (no shared runtime with the BEAM or JVM parts of this
project) that estimates route distance and ETA between two coordinates.
The core logic in `src/Eta.hs` is pure - no I/O at all - which is the whole
point of building this piece: real practice with pure functions,
immutability, and a strict type system with no OOP escape hatch. This
mirrors Namma Yatri's own production stack, which is built on Haskell.

## Files

```
package.yaml       - hpack project definition (deps, exe, test)
stack.yaml          - resolver pin
src/Eta.hs          - pure route/ETA logic (haversine distance)
app/Main.hs         - thin Scotty HTTP wrapper around Eta.hs
test/Spec.hs        - hspec tests against the pure logic directly
```

This has been sanity-checked in this environment: `Eta.hs` type-checks and
was compiled and run standalone (no framework), producing correct
haversine distances (e.g. ~290 km between Bengaluru and Chennai). The
HTTP layer (`Main.hs`, using Scotty + aeson) follows the same pattern but
wasn't build-tested here since it needs package downloads from Hackage,
which this sandbox can't reach.

## Running it

You'll need [Stack](https://docs.haskellstack.org) or Cabal + GHC installed.

```bash
stack build
stack exec eta-service-exe
```

The service listens on port 4001.

```bash
curl http://localhost:4001/health

curl -X POST http://localhost:4001/eta \
  -H "Content-Type: application/json" \
  -d '{"originLat": 12.9716, "originLng": 77.5946, "destLat": 13.0827, "destLng": 80.2707}'
```

Expected response shape:

```json
{"distance_km": 290.17, "eta_minutes": 580.34}
```

## Running the tests

```bash
stack test
```

## How this fits the bigger system

In the full simulator, the Elixir dispatch core would call this over plain
HTTP once a ride is matched, to show the rider an ETA. That HTTP boundary
is deliberate: Haskell doesn't share a runtime with the BEAM (Elixir/Erlang)
or the JVM (Scala/Clojure), so this is where the project demonstrates a
real cross-language network integration rather than in-process calls.
