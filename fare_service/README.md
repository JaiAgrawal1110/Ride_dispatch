# Scala Fare / Surge Pricing Service

A standalone JVM microservice: given a ride distance and a coarse demand
level, returns a fare breakdown with surge pricing applied. The Elixir
dispatch core would call this over HTTP once a ride is matched — same
pattern as the Haskell ETA service, just on the JVM instead.

## Files

```
src/main/scala/fareservice/
  FareCalculator.scala   - pure fare/surge logic (case class + pattern matching)
  TinyJson.scala          - tiny dependency-free JSON field extractor
  Main.scala               - HTTP wrapper using the JDK's com.sun.net.httpserver
src/test/scala/fareservice/
  FareCalculatorTest.scala - assertion-based tests, no test framework needed
```

## Why no build tool (sbt) and no JSON/HTTP library

A real project would use sbt + Akka HTTP/http4s + circe. Those all need to
resolve dependencies from Maven Central, which isn't reachable from the
sandbox this project was built and verified in. So this service is built
to need **nothing beyond a JDK and the Scala compiler**:

- HTTP comes from `com.sun.net.httpserver`, bundled with every JDK.
- JSON parsing is a small regex-based extractor (`TinyJson`) sufficient
  for this service's flat `{"distanceKm": ..., "demandLevel": ...}`
  request shape — not a general-purpose parser.
- Rounding uses `java.math.BigDecimal` directly, which is the deliberate
  "pull in a small Java library" moment for this piece, per the original
  project brief.

If you do have sbt + internet access, swapping in Akka HTTP/http4s and
circe is a natural upgrade — the pure `FareCalculator` logic doesn't need
to change at all.

## This was actually compiled and run

Unlike some of the earlier pieces, this service doesn't depend on any
external package registry, so it was verified end-to-end in the sandbox
that built it:

```
$ scalac -d out src/main/scala/fareservice/*.scala
COMPILE EXIT: 0

$ java -cp out:scala-library.jar fareservice.Main
Fare / surge pricing service listening on port 4002

$ curl -X POST http://localhost:4002/fare -d '{"distanceKm": 5.5, "demandLevel": 2}'
{"base_fare":40.0,"distance_fare":66.0,"surge_multiplier":1.5,"total_fare":159.0}
```

That's `(40 + 5.5*12) * 1.5 = 159.0` — checks out by hand. The 10km/no-surge
and 3km/max-surge cases, the missing-field 400 response, and the
GET-not-allowed 405 response were all exercised too. The assertion-based
test suite (`FareCalculatorTest`) also passes.

This code has also since been compiled and run for real on Windows, via
Scala 3.9.0 (installed through Coursier) using `scala run
src/main/scala/fareservice` — confirmed working with no changes needed
despite the version jump from 2.11 to 3.9.

## Running it yourself

**If you installed Scala via Coursier** (`cs setup`, the modern route,
and what actually got used and confirmed working on Windows during this
project's development):

```bash
scala run src/main/scala/fareservice
```

The first run bootstraps Scala CLI's own build tooling (Bloop, etc.) and
can take a few minutes; after that it's fast. This single command
recompiles and runs the service in one step.

**If you have a plain `scalac`/`scala` install** (e.g. Scala 2.11, no
Scala CLI):

```bash
scalac -d out src/main/scala/fareservice/*.scala
java -cp "out:$(find / -name scala-library.jar 2>/dev/null | head -1)" fareservice.Main
```

Either way, the service listens on port 4002.

```bash
curl http://localhost:4002/health

curl -X POST http://localhost:4002/fare \
  -H "Content-Type: application/json" \
  -d '{"distanceKm": 5.5, "demandLevel": 2}'
```

On Windows PowerShell, `curl` is aliased to `Invoke-WebRequest`, which
doesn't understand `-X`/`-d` the same way. Use this instead:

```powershell
Invoke-RestMethod -Uri http://localhost:4002/fare -Method Post -ContentType "application/json" -Body '{"distanceKm": 5.5, "demandLevel": 2}'
```

`demandLevel` maps to a surge multiplier: `0` → 1.0x, `1` → 1.2x,
`2` → 1.5x, `3+` → 2.0x.

## Running the tests

```bash
scalac -d out src/main/scala/fareservice/*.scala src/test/scala/fareservice/*.scala
java -cp "out:$(find / -name scala-library.jar 2>/dev/null | head -1)" fareservice.FareCalculatorTest
```
