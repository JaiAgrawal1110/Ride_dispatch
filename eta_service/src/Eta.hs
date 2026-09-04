-- |
-- Module: Eta
--
-- Pure route/ETA estimation logic. No I/O here at all - deliberately.
-- This is the part of the whole polyglot project meant to give the
-- deepest practice with pure functions, immutability, and a strict
-- type system with no OOP escape hatch. The HTTP layer in Main.hs is
-- just a thin wrapper around this module.
module Eta
  ( Coordinate (..)
  , RouteEstimate (..)
  , estimateRoute
  ) where

-- | A simple latitude/longitude coordinate.
data Coordinate = Coordinate
  { latitude :: Double
  , longitude :: Double
  }
  deriving (Show, Eq)

-- | The result of estimating a route between two coordinates.
data RouteEstimate = RouteEstimate
  { distanceKm :: Double
  , etaMinutes :: Double
  }
  deriving (Show, Eq)

-- | Average speed assumption used for the ETA calculation, in km/h.
-- A real system would derive this from live traffic/routing data -
-- this simulator intentionally keeps the math simple since routing
-- accuracy isn't the point of this exercise.
averageSpeedKmh :: Double
averageSpeedKmh = 30.0

-- | Earth's radius in kilometers, used by the haversine formula.
earthRadiusKm :: Double
earthRadiusKm = 6371.0

-- | Pure function: estimate distance and ETA between two coordinates
-- using the haversine (great-circle distance) formula.
estimateRoute :: Coordinate -> Coordinate -> RouteEstimate
estimateRoute origin destination =
  let dist = haversineDistance origin destination
      eta = (dist / averageSpeedKmh) * 60.0
   in RouteEstimate {distanceKm = dist, etaMinutes = eta}

toRadians :: Double -> Double
toRadians deg = deg * pi / 180.0

haversineDistance :: Coordinate -> Coordinate -> Double
haversineDistance (Coordinate lat1 lon1) (Coordinate lat2 lon2) =
  let dLat = toRadians (lat2 - lat1)
      dLon = toRadians (lon2 - lon1)
      rLat1 = toRadians lat1
      rLat2 = toRadians lat2
      a =
        sin (dLat / 2) ^ (2 :: Int)
          + cos rLat1 * cos rLat2 * sin (dLon / 2) ^ (2 :: Int)
      c = 2 * atan2 (sqrt a) (sqrt (1 - a))
   in earthRadiusKm * c
