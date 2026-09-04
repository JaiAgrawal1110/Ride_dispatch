# Mini Ride-Dispatch Simulator

A polyglot learning project covering Erlang, Elixir, Scala, Clojure, Haskell,
and Elm — modeled loosely on how a real ride-hailing dispatch system like
Namma Yatri is architected. Riders request rides, drivers get matched,
fares get calculated, and a live dashboard shows it all happening in real
time — with each language used for the job it's actually good at.

This is one project made of five independent services. They're organized
as siblings at the top level, one folder per service, rather than grouped
by "which part of the build this was" — that's what makes it read like an
actual small microservices system instead of a set of assignments.

```
ride_dispatch_simulator/
  dispatch_core/         Elixir + Erlang — the dispatch engine (WebSocket hub)
  dashboard/              Elm — the live frontend
  eta_service/            Haskell — ETA / route estimation
  fare_service/           Scala — fare / surge pricing
  analytics_service/      Clojure — ride log aggregates
  .vscode/                tasks.json to run everything at once
  README.md               (this file)
```

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
| `dispatch_core/` | Elixir + Erlang | WebSocket hub, ride matching | Elixir↔Erlang in-process; WebSocket to clients |
| `dashboard/` | Elm | Live frontend | WebSocket to `dispatch_core` |
| `eta_service/` | Haskell | ETA / route estimate | HTTP (REST) |
| `fare_service/` | Scala | Fare / surge pricing | HTTP (REST) |
| `analytics_service/` | Clojure | Ride log aggregates | HTTP (REST) |

Each folder has its own README with full build/run instructions and
example requests — this file is just the map.

## Quickstart in VS Code

This project ships with `.vscode/tasks.json`, so once you've installed the
toolchains below, you can start everything with one command instead of
juggling five terminals by hand.

**One-time setup** — install whichever of these you don't already have:

| Service | Install |
|---|---|
| `dispatch_core` (Elixir/Erlang) | [Erlang/OTP 26+](https://www.erlang.org/downloads), then [Elixir 1.15+](https://elixir-lang.org/install.html) |
| `eta_service` (Haskell) | [GHCup](https://www.haskell.org/ghcup/) (gives you `stack`/`ghc`) |
| `dashboard` (Elm) | `npm install -g elm` |
| `fare_service` (Scala) | [Coursier](https://get-coursier.io/) (`cs setup`) or `brew install scala` |
| `analytics_service` (Clojure) | [Clojure CLI](https://clojure.org/guides/install_clojure) |

Opening the folder in VS Code will prompt you to install the recommended
extensions (ElixirLS, Haskell, Elm, Metals, Calva) — accept that, it's
optional but makes editing each language much nicer.

**Running everything:**

1. Open this folder in VS Code (`code ride_dispatch_simulator`).
2. Press `Ctrl+Shift+B` (`Cmd+Shift+B` on Mac) — this runs the **"Start All
   Services"** task, which opens a separate terminal panel for each of the
   five services listed above.
3. Once they're all up, run **Terminal → Run Task… → "Check All Service
   Health"** to curl the three HTTP services' `/health` endpoints at once.
4. Open `dashboard/index.html` in a browser to see the live dashboard
   (connects to `dispatch_core`'s WebSocket).

To stop everything, just close the terminal panels (or `Ctrl+C` in each).
Individual tasks are also runnable one at a time via **Terminal → Run
Task…** if you only want to work on one service.

**Windows note:** these tasks assume a Unix-like shell (they use `mix`,
`stack`, and shell command substitution like `` $(find ...) ``). On
Windows, run them from WSL, or open the WSL-integrated terminal in VS Code
— that's simpler than translating each command to PowerShell.

## Running it by hand (no VS Code)

```bash
# dispatch_core — ws://localhost:4000/socket
cd dispatch_core && mix deps.get && mix run --no-halt

# dashboard — open dashboard/index.html after building
cd dashboard && elm make src/Main.elm --output=main.js

# eta_service — http://localhost:4001
cd eta_service && stack build && stack exec eta-service-exe

# fare_service — http://localhost:4002
cd fare_service
scalac -d out src/main/scala/fareservice/*.scala
java -cp "out:$(find / -name scala-library.jar 2>/dev/null | head -1)" fareservice.Main

# analytics_service — http://localhost:4003
cd analytics_service
java -cp "src:$(find / -name clojure-1.11.jar 2>/dev/null | head -1)" clojure.main -m rideanalytics.main
```

None of these five services call each other automatically yet — e.g.
`dispatch_core` doesn't currently reach out to `eta_service` or
`fare_service` once a ride is matched. Wiring that up (a `RideServer`
calling out over HTTP once `status == :matched`) is the natural next step
if you want to turn this into a fully connected system. Each service's
own README has its manual-testing walkthrough in the meantime.

## What was actually verified to run, and how

This project was built without a pre-installed BEAM/JVM/Haskell/Elm dev
environment, so rather than just asserting the code is correct, here's
exactly what was checked in the sandbox that built it:

| Service | Verified how | Result |
|---|---|---|
| `dispatch_core` — `nearest_driver.erl` | Installed Erlang; ran `erlc` + a live `erl` shell exercising `find_nearest/2` | Compiled clean; correctly picked the nearest available driver, correctly returned `no_drivers_available` |
| `dispatch_core` — Elixir/Phoenix layer | Not compiled (no Mix/Hex toolchain available) | Written by hand following standard OTP/Phoenix conventions |
| `eta_service` — `Eta.hs` (pure logic) | Installed GHC; type-checked and ran it standalone against real coordinates | Correct: haversine distance Bengaluru→Chennai ≈ 290 km |
| `eta_service` — HTTP layer (`Main.hs`) | Not built (needs Hackage packages: scotty, aeson) | Written by hand on top of the verified `Eta.hs` |
| `dashboard` — `Main.elm` | Not compiled (needs `package.elm-lang.org`, unreachable here) | Written by hand following standard Elm 0.19 idioms |
| `fare_service` (Scala) | Installed Scala 2.11 + JDK; compiled with `scalac`, ran the HTTP server, hit it with `curl` for several scenarios, ran an assertion-based test suite | Fully passing: surge math (e.g. `(40 + 5.5×12) × 1.5 = 159.0`) verified by hand; 400/405 error paths verified |
| `analytics_service` (Clojure) | Installed Clojure 1.11 + JDK; ran the pure aggregate functions directly, then compiled and ran the full HTTP server, hit it with `curl` for several scenarios | Fully passing: aggregates verified by hand; malformed-body 400 and GET-405 paths verified |

**Bottom line**: every piece with no external package-registry dependency
— the Erlang matcher, the pure Haskell ETA logic, and both entire JVM
services (`fare_service`, `analytics_service`) — was actually compiled
and run with real inputs in this environment. Only the pieces that need a
package ecosystem this sandbox couldn't reach (Hex for Elixir, Hackage for
Haskell's HTTP layer, Elm's package registry) were written carefully but
not build-verified end-to-end. Run `mix deps.get` / `stack build` /
`elm make` yourself as the first step for those, and lean on each tool's
compiler errors if anything needs a tweak.

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

This project includes all five services, complete.
