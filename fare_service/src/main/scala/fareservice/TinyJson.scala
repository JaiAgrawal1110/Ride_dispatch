package fareservice

import java.util.regex.Pattern
import scala.util.matching.Regex

/** Minimal helpers for pulling flat numeric fields out of a small JSON
  * object, without pulling in an external JSON library (which would
  * need a build tool with access to Maven Central). This is
  * deliberately not a general-purpose parser - just enough to read
  * request bodies shaped like `{"distanceKm": 5.2, "demandLevel": 2}`.
  */
object TinyJson {

  def extractDouble(json: String, field: String): Option[Double] = {
    val pattern: Regex = ("\"" + Pattern.quote(field) + "\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)").r
    pattern.findFirstMatchIn(json).map(_.group(1).toDouble)
  }

  def extractInt(json: String, field: String): Option[Int] =
    extractDouble(json, field).map(_.toInt)
}
