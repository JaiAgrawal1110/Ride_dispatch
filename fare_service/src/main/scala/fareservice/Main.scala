package fareservice

import com.sun.net.httpserver.{HttpExchange, HttpHandler, HttpServer}
import java.io.OutputStream
import java.net.InetSocketAddress
import scala.io.Source

/** Thin HTTP wrapper around `FareCalculator`. This is the standalone
  * JVM microservice piece of the project: the Elixir dispatch core
  * would call this over plain HTTP once a ride is matched, the same
  * pattern used for the Haskell ETA service in Part 2.
  *
  * Deliberately built on the JDK's own `com.sun.net.httpserver`
  * rather than a framework like Akka HTTP or http4s, so this compiles
  * and runs with nothing beyond a JDK + Scala compiler - no build
  * tool or Maven Central access required.
  */
object Main {
  private val Port = 4002

  def main(args: Array[String]): Unit = {
    val server = HttpServer.create(new InetSocketAddress(Port), 0)

    server.createContext(
      "/health",
      new HttpHandler {
        override def handle(exchange: HttpExchange): Unit =
          respond(exchange, 200, """{"status":"ok"}""")
      }
    )

    server.createContext(
      "/fare",
      new HttpHandler {
        override def handle(exchange: HttpExchange): Unit = {
          if (exchange.getRequestMethod != "POST") {
            respond(exchange, 405, """{"error":"method not allowed"}""")
          } else {
            handleFareRequest(exchange)
          }
        }
      }
    )

    server.setExecutor(null)
    server.start()
    println(s"Fare / surge pricing service listening on port $Port")
  }

  private def handleFareRequest(exchange: HttpExchange): Unit = {
    val body = Source.fromInputStream(exchange.getRequestBody).mkString
    val maybeDistance = TinyJson.extractDouble(body, "distanceKm")
    val demandLevel = TinyJson.extractInt(body, "demandLevel").getOrElse(0)

    maybeDistance match {
      case Some(distanceKm) if distanceKm >= 0 =>
        val fare = FareCalculator.calculateFare(distanceKm, demandLevel)
        val json =
          s"""{"base_fare":${fare.baseFare},""" +
            s""""distance_fare":${fare.distanceFare},""" +
            s""""surge_multiplier":${fare.surgeMultiplier},""" +
            s""""total_fare":${fare.totalFare}}"""
        respond(exchange, 200, json)
      case Some(_) =>
        respond(exchange, 400, """{"error":"distanceKm must not be negative"}""")
      case None =>
        respond(exchange, 400, """{"error":"distanceKm is required"}""")
    }
  }

  private def respond(exchange: HttpExchange, status: Int, body: String): Unit = {
    val bytes = body.getBytes("UTF-8")
    exchange.getResponseHeaders.add("Content-Type", "application/json")
    exchange.sendResponseHeaders(status, bytes.length.toLong)
    val os: OutputStream = exchange.getResponseBody
    try os.write(bytes)
    finally os.close()
  }
}
