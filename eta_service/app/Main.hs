{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- |
-- Module: Main
--
-- Thin HTTP wrapper around the pure logic in Eta.hs. This is the
-- standalone ETA / Route Engine service - it doesn't share a runtime
-- with anything else in the project (unlike the Elixir/Erlang pair),
-- so the Elixir dispatch core would talk to it over plain HTTP.
-- This mirrors Namma Yatri's own production stack, which is built on
-- Haskell.
module Main (main) where

import Data.Aeson (FromJSON, object, (.=))
import Eta (Coordinate (..), RouteEstimate (..), estimateRoute)
import GHC.Generics (Generic)
import Web.Scotty

-- | Request body for POST /eta
data EtaRequest = EtaRequest
  { originLat :: Double
  , originLng :: Double
  , destLat :: Double
  , destLng :: Double
  }
  deriving (Show, Generic)

instance FromJSON EtaRequest

main :: IO ()
main = scotty 4001 $ do
  get "/health" $
    json (object ["status" .= ("ok" :: String)])

  post "/eta" $ do
    req <- jsonData :: ActionM EtaRequest
    let origin = Coordinate (originLat req) (originLng req)
        dest = Coordinate (destLat req) (destLng req)
        result = estimateRoute origin dest
    json $
      object
        [ "distance_km" .= distanceKm result
        , "eta_minutes" .= etaMinutes result
        ]
