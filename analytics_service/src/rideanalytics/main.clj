(ns rideanalytics.main
  "Thin HTTP wrapper around rideanalytics.core. This is the standalone
   JVM microservice piece described in the project brief: a small
   service ingesting ride logs to produce aggregates, sitting on the
   same JVM family as the Scala fare service but forcing a very
   different, Lisp/immutable-data-first style of thinking.

   Built directly on the JDK's com.sun.net.httpserver (via Java
   interop) rather than a library like http-kit or Ring/Jetty, so this
   runs with nothing beyond a JDK + the Clojure runtime - no
   Leiningen/deps.edn dependency resolution against Maven Central
   required.

   Request bodies are read as EDN (via clojure.edn/read-string) rather
   than JSON, since EDN needs zero external libraries and is the
   idiomatic Clojure choice for a same-ecosystem client. Responses are
   still emitted as JSON for consistency with the rest of the
   (polyglot) system."
  (:require [rideanalytics.core :as core]
            [clojure.edn :as edn])
  (:import [com.sun.net.httpserver HttpServer HttpHandler HttpExchange]
           [java.net InetSocketAddress])
  (:gen-class))

(defn- respond [^HttpExchange exchange status ^String body]
  (let [bytes (.getBytes body "UTF-8")]
    (.add (.getResponseHeaders exchange) "Content-Type" "application/json")
    (.sendResponseHeaders exchange status (long (count bytes)))
    (with-open [os (.getResponseBody exchange)]
      (.write os bytes))))

(defn- json-number
  "Formats a number for JSON output - integers as-is, everything else
   to 4 decimal places so ratios/doubles don't spew Clojure's exact
   fraction syntax (e.g. 7/3) or excessive precision into the response."
  [n]
  (if (integer? n)
    (str n)
    (format "%.4f" (double n))))

(defn- summary->json [summary]
  (str "{"
       "\"total_rides\":" (:total-rides summary) ","
       "\"average_fare\":" (json-number (:average-fare summary)) ","
       "\"rides_per_hour\":" (json-number (:rides-per-hour summary)) ","
       "\"driver_utilization\":" (json-number (:driver-utilization summary))
       "}"))

(defn- handle-analytics [^HttpExchange exchange]
  (try
    (let [body (slurp (.getRequestBody exchange))
          payload (edn/read-string body)]
      (if-not (map? payload)
        (respond exchange 400
                 "{\"error\":\"request body must be an EDN map with :rides, :driver-ids, :window-hours\"}")
        (let [rides (:rides payload)
              all-driver-ids (:driver-ids payload)
              window-hours (get payload :window-hours 1)
              summary (core/summarize rides all-driver-ids window-hours)]
          (respond exchange 200 (summary->json summary)))))
    (catch Exception e
      (respond exchange 400
               (str "{\"error\":\"" (.getMessage e) "\"}")))))

(defn -main [& _args]
  (let [port 4003
        server (HttpServer/create (InetSocketAddress. port) 0)]
    (.createContext server "/health"
                     (reify HttpHandler
                       (handle [_ exchange]
                         (respond exchange 200 "{\"status\":\"ok\"}"))))
    (.createContext server "/analytics"
                     (reify HttpHandler
                       (handle [_ exchange]
                         (if (= "POST" (.getRequestMethod exchange))
                           (handle-analytics exchange)
                           (respond exchange 405 "{\"error\":\"method not allowed\"}")))))
    (.setExecutor server nil)
    (.start server)
    (println (str "Ride analytics service listening on port " port))))
