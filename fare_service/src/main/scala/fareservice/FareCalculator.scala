package fareservice

import java.math.{BigDecimal, RoundingMode}

/** Pure fare / surge pricing logic.
  *
  * Demonstrates the "FP with training wheels" flavor of Scala: an
  * immutable case class as the result type, pattern matching with
  * guards for the surge tiers, and a direct pull-in of a plain Java
  * class (`java.math.BigDecimal`) for rounding - since Scala runs on
  * the JVM, using Java's standard library takes zero glue code.
  */
object FareCalculator {

  final case class FareBreakdown(
    baseFare: Double,
    distanceFare: Double,
    surgeMultiplier: Double,
    totalFare: Double
  )

  private val BaseFare: Double = 40.0 // flat starting fare, in currency units
  private val PerKmRate: Double = 12.0 // rate charged per kilometer

  /** Maps a coarse demand level (0 = quiet, higher = busier) to a surge
    * multiplier. A real system would derive this from a live
    * supply/demand ratio; this simulator keeps the tiers simple and
    * explicit since surge *mechanics*, not calibration, are the point.
    */
  def surgeMultiplierFor(demandLevel: Int): Double = demandLevel match {
    case level if level <= 0 => 1.0
    case 1                   => 1.2
    case 2                   => 1.5
    case level if level >= 3 => 2.0
  }

  /** Calculates the fare for a ride given its distance and a coarse
    * demand level used to determine surge pricing.
    */
  def calculateFare(distanceKm: Double, demandLevel: Int): FareBreakdown = {
    require(distanceKm >= 0, "distanceKm must not be negative")

    val surge = surgeMultiplierFor(demandLevel)
    val distanceFare = distanceKm * PerKmRate
    val subtotal = (BaseFare + distanceFare) * surge

    FareBreakdown(
      baseFare = BaseFare,
      distanceFare = roundToTwoDecimals(distanceFare),
      surgeMultiplier = surge,
      totalFare = roundToTwoDecimals(subtotal)
    )
  }

  /** Rounds via `java.math.BigDecimal` rather than hand-rolled float
    * math - a small, deliberate example of Scala/Java interop.
    */
  private def roundToTwoDecimals(value: Double): Double =
    new BigDecimal(value).setScale(2, RoundingMode.HALF_UP).doubleValue()
}
