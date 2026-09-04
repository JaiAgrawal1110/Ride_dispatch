(ns rideanalytics.core
  "Pure aggregate functions over ride log data - rides/hour, average
   fare, driver utilization. No I/O in this namespace at all; the HTTP
   boundary lives in rideanalytics.main. Because Clojure is also
   JVM-hosted, this could freely share a process with the Scala fare
   service if you wanted to combine them - here they're kept as
   separate services to mirror a realistic microservices split, and to
   force practice with Clojure's very different (Lisp,
   immutable-data-first) way of thinking about the same platform."
  (:require [clojure.set :as set]))

(defn average-fare
  "Average fare across a seq of ride maps, each with a :fare key.
   Returns 0.0 for an empty seq rather than dividing by zero."
  [rides]
  (if (empty? rides)
    0.0
    (/ (reduce + (map :fare rides)) (double (count rides)))))

(defn rides-per-hour
  "Throughput of completed rides over an observed window (in hours)."
  [rides window-hours]
  (if (or (nil? window-hours) (zero? window-hours))
    0.0
    (/ (count rides) (double window-hours))))

(defn driver-utilization
  "Fraction of all known drivers who completed at least one ride in
   this log - i.e. how much of the fleet was actually put to work."
  [rides all-driver-ids]
  (if (empty? all-driver-ids)
    0.0
    (let [active-drivers (into #{} (map :driver-id rides))
          known-drivers (into #{} all-driver-ids)
          active-count (count (set/intersection active-drivers known-drivers))]
      (/ active-count (double (count known-drivers))))))

(defn summarize
  "Top-level aggregate report for a batch of ride logs."
  [rides all-driver-ids window-hours]
  {:total-rides (count rides)
   :average-fare (average-fare rides)
   :rides-per-hour (rides-per-hour rides window-hours)
   :driver-utilization (driver-utilization rides all-driver-ids)})
