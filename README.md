# Mini Ride-Dispatch Simulator

A polyglot learning project covering Erlang, Elixir, Scala, Clojure, Haskell,
and Elm — modeled loosely on how a real ride-hailing dispatch system like
Namma Yatri is architected. Riders request rides, drivers get matched,
fares get calculated via a real cross-language HTTP call chain, and a live
dashboard shows it all happening in real time — with each language used
for the job it's actually good at.

This is one project made of five independent services plus an orchestrator
that ties them together. Services are organized as siblings at the top
level, one folder per service, so it reads like an actual small
microservices system rather than a set of assignments.

```
ride_dispatch_simulator/
  dispatch_core/         Elixir + Erlang — the dispatch engine (WebSocket hub)
  dashboard/              Elm — the live frontend
  eta_service/            Haskell — ETA / route estimation
  fare_service/           Scala — fare / surge pricing
  analytics_service/      Clojure — ride log aggregates
  orchestrator/           Node — starts everything with one command, one port
  .vscode/                tasks.json to run everything from VS Code
  README.md               (this file)
```

## How a ride actually flows through this now

1. The **dashboard** (Elm) sends a `request_ride` event over WebSocket to
   **dispatch_core**, including a pickup point, a destination, and an
   optional demand level.
2. **dispatch_core** matches the ride to the nearest available driver by
   calling **Erlang** in-process (no network hop — same BEAM runtime).
3. Once matched, **dispatch_core** calls **eta_service** (Haskell) over
   HTTP with the pickup/destination coordinates, getting back a distance
   and ETA.
4. It then calls **fare_service** (Scala) over HTTP with that distance
   and the demand level, getting back a fare.
5. All of this — status, driver, distance, ETA, fare — gets pushed back
   over WebSocket to the dashboard, live.

Both HTTP calls are best-effort: if `eta_service` or `fare_service` isn't
running, the ride still matches and completes, just without those fields
filled in. **analytics_service** (Clojure) sits outside this live path —
it's a separate service you feed ride logs to on your own schedule, not
something dispatch_core calls automatically.

## The two language families, plus two islands

**BEAM family (Erlang + Elixir).** They share the same runtime — Elixir
compiles to the same bytecode Erlang runs, so they call each other's code
directly, in-process, with no network hop. This is why real-time,
highly-concurrent systems (WhatsApp, Discord, ride dispatch) are built on
this family. `dispatch_core/` contains both languages in one Mix project:
Elixir/Phoenix as the WebSocket hub and per-ride GenServers, Erlang as the
raw nearest-driver matching algorithm, called as a plain in-process
function call.

**JVM family (Scala + Clojure).** Both compile to JVM bytecode, same as
Java, so they can import Java libraries directly and could even
interoperate with each other in the same running process. Here they're
kept as two separate services — `fare_service/` (Scala) and
`analytics_service/` (Clojure) — to mirror a realistic microservices
split, while both still demonstrating "same runtime, very different
paradigm" (Scala's C-like syntax vs. Clojure's Lisp).

**Standalone islands (Haskell + Elm).** `eta_service/` and `dashboard/`
don't share a runtime with anything else here — they talk to the rest of
the system over HTTP or WebSocket, not in-process calls. Haskell's pure,
no-I/O core mirrors Namma Yatri's own production stack; Elm's strict
typing and immutability show what FP principles look like applied to
frontend state management.

## Each service, one line each

| Service | Language | Role | Talks to the rest of the system via |
|---|---|---|---|
| `dispatch_core/` | Elixir + Erlang | WebSocket hub, ride matching, calls eta/fare | Elixir↔Erlang in-process; WebSocket to clients; HTTP out to eta/fare |
| `dashboard/` | Elm | Live frontend | WebSocket to `dispatch_core` |
| `eta_service/` | Haskell | ETA / route estimate | HTTP (REST), called by `dispatch_core` |
| `fare_service/` | Scala | Fare / surge pricing | HTTP (REST), called by `dispatch_core` |
| `analytics_service/` | Clojure | Ride log aggregates | HTTP (REST), standalone — fed manually |

Each folder has its own README with full build/run instructions and
example requests — this file is just the map.

## Option A: one command, one URL (the orchestrator)

The fastest way to run everything:

```bash
cd orchestrator
npm install   # once
npm start
```

Then open **http://localhost:8080** — that's the dashboard, and every API
call it makes gets proxied to the right backend automatically. One
terminal, one URL, color-coded logs per service.

This still needs each service's own toolchain installed (see the table
below) — the orchestrator runs the exact same commands you'd type by
hand, it just does it for all four backend services at once and gives
you a single front door. See `orchestrator/README.md` for exactly what
it does and doesn't handle.

## Option B: five terminals (manual or via VS Code tasks)

If you'd rather see each service in its own terminal (useful while
learning, or debugging one specific piece):

### Quickstart in VS Code

**One-time setup** — install whichever of these you don't already have:

| Service | Install |
|---|---|
| `dispatch_core` (Elixir/Erlang) | [Erlang/OTP 26+](https://www.erlang.org/downloads), then [Elixir 1.15+](https://elixir-lang.org/install.html) |
| `eta_service` (Haskell) | [GHCup](https://www.haskell.org/ghcup/) (gives you `stack`/`ghc`) |
| `dashboard` (Elm) | `npm install -g elm` |
| `fare_service` (Scala) | [Coursier](https://get-coursier.io/) (`cs setup`) |
| `analytics_service` (Clojure) | [Clojure CLI](https://clojure.org/guides/install_clojure) |

Opening the folder in VS Code will prompt you to install the recommended
extensions (ElixirLS, Haskell, Elm, Metals, Calva) — accept that, it's
optional but makes editing each language much nicer.

**Running everything:**

1. Open this folder in VS Code (`code ride_dispatch_simulator`).
2. Press `Ctrl+Shift+B` (`Cmd+Shift+B` on Mac) — this runs **"Start All
   Services (5 Terminals)"**, opening a separate panel for each service.
   (There's also an **"Orchestrator: Start Everything (One Command)"**
   task if you'd rather use Option A from inside VS Code — run it via
   **Terminal → Run Task…** instead of the default build shortcut.)
3. Once they're all up, run **Terminal → Run Task… → "Check All Service
   Health"** to curl the three HTTP services' `/health` endpoints at once.
4. Open `dashboard/index.html` directly in a browser to see the live
   dashboard (connects straight to `dispatch_core`'s WebSocket on 4000).

To stop everything, close the terminal panels (or `Ctrl+C` in each).

**Windows note:** on Windows, install each toolchain via its native
Windows installer (not WSL) so the `.bat`/`.cmd` shims land on your
Windows PATH — that's what both the VS Code tasks and the orchestrator
expect. If a command isn't recognized right after installing something,
the fix is almost always: fully close and reopen your terminal (or log
off/on for system-level PATH changes), then verify with `<tool>
--version` before moving on.

### Running it by hand (no VS Code)

```bash
# dispatch_core — ws://localhost:4000/socket
cd dispatch_core && mix deps.get && mix run --no-halt

# dashboard — open dashboard/index.html after building
cd dashboard && elm make src/Main.elm --output=main.js

# eta_service — http://localhost:4001
cd eta_service && stack build && stack exec eta-service-exe

# fare_service — http://localhost:4002
cd fare_service && scala run src/main/scala/fareservice

# analytics_service — http://localhost:4003
cd analytics_service && clojure -M -m rideanalytics.main
```

## What was actually verified to run, and how

This project was built without a pre-installed BEAM/JVM/Haskell/Elm dev
environment, so rather than just asserting the code is correct, here's
exactly what was checked in the sandbox that built it:

| Piece | Verified how | Result |
|---|---|---|
| `dispatch_core` — `nearest_driver.erl` | Installed Erlang; ran `erlc` + a live `erl` shell exercising `find_nearest/2` | Compiled clean; correctly picked the nearest available driver, correctly returned `no_drivers_available` |
| `dispatch_core` — `ExternalServices` + updated `RideServer` | Installed Elixir; syntax-checked with `elixirc` directly | Compiled clean (only expected "module not loaded" warnings for deps not present standalone) |
| `dispatch_core` — Phoenix web layer (`ride_channel.ex` etc.) | Not fully compiled (needs Hex, unreachable from this sandbox even via git-sourced deps, which hit the same wall trying to install Hex itself) | Written by hand following standard Phoenix conventions; hand-reviewed for syntax |
| `eta_service` — `Eta.hs` (pure logic) | Installed GHC; type-checked and ran it standalone against real coordinates | Correct: haversine distance Bengaluru→Chennai ≈ 290 km |
| `eta_service` — HTTP layer (`Main.hs`) | Not built (needs Hackage packages: scotty, aeson) | Written by hand on top of the verified `Eta.hs` — **and confirmed working live** when actually run on Windows during development (see below) |
| `dashboard` — `Main.elm` | Not compiled (needs `package.elm-lang.org`, unreachable here) | Written by hand following standard Elm 0.19 idioms — **and confirmed compiling clean and working live** on Windows during development |
| `fare_service` (Scala) | Installed Scala 2.11 + JDK; compiled with `scalac`, ran the HTTP server, hit it with `curl`, ran an assertion-based test suite | Fully passing: surge math (e.g. `(40 + 5.5×12) × 1.5 = 159.0`) verified by hand |
| `analytics_service` (Clojure) | Installed Clojure 1.11 + JDK; ran the pure aggregate functions directly, then the full HTTP server, hit it with `curl` | Fully passing: aggregates verified by hand |
| `orchestrator` (Node) | Installed `http-proxy`; ran the real server against mock backends standing in for all four services | Static file serving, all three API proxies (with path rewriting), aggregate health check, and the WebSocket upgrade proxy all verified working end-to-end. **Caught and fixed a real bug** in the process: on POSIX, killing only the shell wrapper around a `shell: true` child left the real process orphaned — fixed by spawning in a detached process group and signaling the whole group on shutdown |

**Bottom line**: every piece with no external package-registry dependency
— the Erlang matcher, the pure Haskell ETA logic, both entire JVM services,
and the orchestrator — was compiled and run with real inputs in the build
sandbox. `dispatch_core`'s Phoenix layer, the Haskell HTTP wrapper, and the
Elm dashboard couldn't be compiled in that same sandbox (Hex, Hackage, and
Elm's package registry are all unreachable from there) — but all three
were subsequently built and run for real on a Windows machine during this
project's development, including the full live flow: a ride request
traveling from the dashboard, through dispatch_core and the Erlang
matcher, out to a driver match, confirmed with screenshots at each step.

## Suggested build order, if you're extending this from scratch

This was the original priority order this project was designed around,
in case you're rebuilding a piece or adding something new:

1. `dispatch_core` — most relevant to real ride-hailing systems, most
   learning value for the BEAM family.
2. `dashboard` — visible and demoable, reinforces FP thinking on the
   frontend.
3. `eta_service` — small in scope, most directly relevant to companies
   (like Namma Yatri) whose production stack is Haskell.
4. `fare_service` + `analytics_service` — valuable for JVM-family
   understanding, lowest priority if time-constrained.
5. `orchestrator` — ties everything together once the individual pieces
   work; not worth building first, since it has nothing to orchestrate
   until the services themselves exist.

This project includes all five services plus the orchestrator, complete.
