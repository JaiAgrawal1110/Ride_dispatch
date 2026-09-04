# Clojure Ride Analytics

A standalone JVM microservice that ingests ride logs and produces
aggregates: total rides, average fare, rides/hour, and driver
utilization. It runs on the same JVM family as the Scala fare service,
but forces a genuinely different way of thinking about the platform —
Lisp syntax, immutable-data-first, everything-is-a-map/seq.

## Files

```
src/rideanalytics/
  core.clj    - pure aggregate functions (average-fare, rides-per-hour, driver-utilization, summarize)
  main.clj    - HTTP wrapper using the JDK's com.sun.net.httpserver via Java interop
```

## Design choices worth knowing about

- **No Leiningen/deps.edn dependency resolution.** Like the Scala fare
  service, this needed to run with nothing beyond a
  JVM + the Clojure runtime — no access to Maven Central to fetch
  ring/http-kit/compojure. So the HTTP layer is `com.sun.net.httpserver`
  via direct Java interop (`(:import ...)`, `reify`), which is the
  concrete "same runtime, different paradigm" moment: Clojure reaching
  for a Java class exactly the way the Scala service did, just with
  Lisp syntax wrapped around it.
- **Request bodies are EDN, not JSON.** `clojure.edn/read-string` is
  built into Clojure with zero dependencies, and EDN is the idiomatic
  choice for a same-ecosystem client talking to a Clojure service — so
  rather than hand-rolling another tiny JSON parser, the input format
  itself leans into what Clojure gives you for free. Responses are
  still JSON, for consistency with the rest of the (polyglot) system.
- **Fleet-wide `driver-ids` is a required input**, separate from the
  ride log — utilization is "how many of the drivers I *know about*
  actually worked", which needs the roster, not just who shows up in
  the log.

## This was actually run, not just written

Both the pure logic and the full HTTP server were installed and
exercised in the sandbox that built this project:

```
$ clojure -i src/rideanalytics/core.clj -e "..."
average-fare: 150.0
rides-per-hour (3 rides / 1.5h): 2.0
driver-utilization (2 of 3 active): 0.6666666666666666
```

```
$ java -cp src:clojure-1.11.jar clojure.main -m rideanalytics.main
Ride analytics service listening on port 4003

$ curl -X POST http://localhost:4003/analytics --data-binary \
  '{:rides [{:fare 100.0 :driver-id "d1"} {:fare 200.0 :driver-id "d2"}] :driver-ids ["d1" "d2" "d3"] :window-hours 2}'
{"total_rides":2,"average_fare":150.0000,"rides_per_hour":1.0000,"driver_utilization":0.6667}
```

Malformed and non-map EDN bodies correctly return 400, and `GET
/analytics` correctly returns 405.

## Running it yourself

```bash
CLOJURE_JAR=$(find / -name "clojure-1.11.jar" 2>/dev/null | head -1)
java -cp "src:$CLOJURE_JAR" clojure.main -m rideanalytics.main
```

The service listens on port 4003.

```bash
curl http://localhost:4003/health

curl -X POST http://localhost:4003/analytics --data-binary \
  '{:rides [{:fare 120.0 :driver-id "d1"} {:fare 95.0 :driver-id "d2"}]
    :driver-ids ["d1" "d2" "d3" "d4"]
    :window-hours 3}'
```

## Compiling ahead-of-time (optional)

```bash
CLOJURE_JAR=$(find / -name "clojure-1.11.jar" 2>/dev/null | head -1)
mkdir -p classes
java -cp "src:$CLOJURE_JAR" clojure.main -e \
  "(binding [*compile-path* \"classes\"] (compile 'rideanalytics.core) (compile 'rideanalytics.main))"
```
