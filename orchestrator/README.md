# Orchestrator

Starts every service in the Mini Ride-Dispatch Simulator with **one
command**, and serves the dashboard plus all the backend APIs behind a
**single host:port** instead of five.

```bash
cd orchestrator
npm install   # once
npm start
```

Then open **http://localhost:8080** — that's the whole system.

## What this does and doesn't do

**Does:**
- Spawns `dispatch_core`, `eta_service`, `fare_service`, and
  `analytics_service` as child processes, each logged to this one
  terminal with a colored `[service_name]` prefix.
- Serves the Elm dashboard's `index.html` and `main.js` as static files.
- Reverse-proxies the dashboard's WebSocket connection (`/socket/*`)
  through to `dispatch_core` on port 4000.
- Reverse-proxies `/api/eta`, `/api/fare`, and `/api/analytics` through
  to their real services on ports 4001-4003.
- Exposes `/api/health`, which checks all three HTTP services at once
  and returns a combined JSON report - handy for confirming everything
  actually started.
- Cleans up every child process (including the real process behind
  each one, not just its shell wrapper) when you stop it with `Ctrl+C`.

**Doesn't:**
- Install any toolchain for you. Elixir/Erlang, Stack, Scala (via
  Coursier), and the Clojure CLI still need to be installed and on
  PATH exactly as described in each service's own README - the
  orchestrator just runs the same commands you'd type by hand.
- Rebuild the Elm dashboard automatically. If you change `Main.elm`,
  you still need to run `elm make src/Main.elm --output=main.js` in
  `dashboard/` before restarting the orchestrator.
- Handle a service crashing and restarting gracefully - if one dies,
  its terminal output will show the exit code, but you'll need to
  restart the orchestrator to bring it back.

## Why a Node script instead of Docker Compose or similar

This project deliberately avoids requiring Docker so that each
language's toolchain gets installed and used directly, which was the
whole point of the learning exercise. The orchestrator is a thin
convenience layer on top of that, not a replacement for understanding
how each piece runs on its own - if something goes wrong, look at the
color-coded terminal output to see which specific service is
complaining, and refer to that service's own README.

## Windows notes

Child processes are spawned with `shell: true` so Windows can resolve
`.bat`/`.cmd` shims (`mix.bat`, `scala.bat`, etc.) the same way a real
terminal does. Shutdown on Windows uses `taskkill /T /F` on each
process's PID tree, since a plain `kill()` often only reaches the shell
wrapper, not the real process underneath it - this was tested and
fixed during development after exactly that bug showed up.

## Ports reference

| What | Port | Notes |
|---|---|---|
| Orchestrator (dashboard + proxy) | 8080 | The one URL you actually open |
| `dispatch_core` | 4000 | Proxied via `/socket/*` |
| `eta_service` | 4001 | Proxied via `/api/eta` |
| `fare_service` | 4002 | Proxied via `/api/fare` |
| `analytics_service` | 4003 | Proxied via `/api/analytics` |

You can still hit the real ports directly (e.g. `curl
http://localhost:4002/health`) - the orchestrator doesn't block that,
it just adds a unified front door on top.
