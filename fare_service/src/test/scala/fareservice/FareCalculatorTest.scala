package fareservice

/** Lightweight assertion-based tests for `FareCalculator`.
  *
  * Deliberately not written against ScalaTest/specs2, since pulling
  * those in needs a build tool with Maven Central access. Run with:
  *
  *   scalac -d out (find src -name "SomeFile.scala")
  *   scala -cp out fareservice.FareCalculatorTest
  *
  * (compile every .scala file under src/main and src/test into "out")
  *
  * Exits with a non-zero status and prints a message on the first
  * failing assertion; prints "All tests passed." if everything holds.
  */
object FareCalculatorTest {
  def main(args: Array[String]): Unit = {
    testNoSurgeAtZeroDemand()
    testSurgeTiers()
    testFareMath()
    testRejectsNegativeDistance()
    println("All tests passed.")
  }

  private def testNoSurgeAtZeroDemand(): Unit = {
    assert(FareCalculator.surgeMultiplierFor(0) == 1.0, "demand 0 should have no surge")
    assert(FareCalculator.surgeMultiplierFor(-5) == 1.0, "negative demand should clamp to no surge")
  }

  private def testSurgeTiers(): Unit = {
    assert(FareCalculator.surgeMultiplierFor(1) == 1.2, "demand 1 should be 1.2x")
    assert(FareCalculator.surgeMultiplierFor(2) == 1.5, "demand 2 should be 1.5x")
    assert(FareCalculator.surgeMultiplierFor(3) == 2.0, "demand 3 should be 2.0x")
    assert(FareCalculator.surgeMultiplierFor(10) == 2.0, "demand above 3 should cap at 2.0x")
  }

  private def testFareMath(): Unit = {
    val fare = FareCalculator.calculateFare(distanceKm = 5.5, demandLevel = 2)
    assert(fare.baseFare == 40.0, s"unexpected base fare: ${fare.baseFare}")
    assert(fare.distanceFare == 66.0, s"unexpected distance fare: ${fare.distanceFare}")
    assert(fare.surgeMultiplier == 1.5, s"unexpected surge: ${fare.surgeMultiplier}")
    assert(fare.totalFare == 159.0, s"unexpected total: ${fare.totalFare}")
  }

  private def testRejectsNegativeDistance(): Unit = {
    var threw = false
    try {
      FareCalculator.calculateFare(distanceKm = -1.0, demandLevel = 0)
    } catch {
      case _: IllegalArgumentException => threw = true
    }
    assert(threw, "negative distance should raise IllegalArgumentException")
  }
}
