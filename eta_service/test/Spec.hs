{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the pure route/ETA logic. Since Eta.hs has no I/O at
-- all, these tests exercise it directly with no mocking needed - one
-- of the practical payoffs of keeping core logic pure.
module Main (main) where

import Eta (Coordinate (..), RouteEstimate (..), estimateRoute)
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "estimateRoute" $ do
    it "returns zero distance and zero ETA for identical coordinates" $ do
      let point = Coordinate 12.9716 77.5946
          result = estimateRoute point point
      distanceKm result `shouldSatisfy` (< 0.0001)
      etaMinutes result `shouldSatisfy` (< 0.0001)

    it "returns a positive distance and ETA for two distinct coordinates" $ do
      let origin = Coordinate 12.9716 77.5946 -- Bengaluru
          dest = Coordinate 13.0827 80.2707 -- Chennai
          result = estimateRoute origin dest
      distanceKm result `shouldSatisfy` (> 0)
      etaMinutes result `shouldSatisfy` (> 0)

    it "gives a longer ETA for a longer distance" $ do
      let origin = Coordinate 0 0
          near = Coordinate 0.01 0.01
          far = Coordinate 5 5
          nearResult = estimateRoute origin near
          farResult = estimateRoute origin far
      etaMinutes farResult `shouldSatisfy` (> etaMinutes nearResult)
