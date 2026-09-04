port module Main exposing (main)

{-| Live dashboard for the ride-dispatch simulator.

Elm doesn't have a native WebSocket package in 0.19, and Phoenix channels
use their own message-framing protocol on top of a raw WebSocket anyway.
So the actual socket connection lives in a small bit of JavaScript in
index.html, and this module talks to that JS through ports:

  - `joinRideChannel` - ask JS to join a ride's topic
  - `registerDriver` / `requestRide` - ask JS to push those events
  - `rideUpdateReceived` - receive decoded ride-update events back

This keeps all the state management, decoding, and rendering in Elm's
pure, strictly-typed world - the JS side is a deliberately thin, "dumb"
transport shim. Everything a person does with this dashboard - watching
a ride, registering a driver, requesting a ride - happens through real
form controls instead of the browser's dev console.

-}

import Browser
import Html exposing (Html, button, div, h1, h2, input, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- PORTS


port joinRideChannel : String -> Cmd msg


port registerDriver : Encode.Value -> Cmd msg


port requestRide : Encode.Value -> Cmd msg


port rideUpdateReceived : (Decode.Value -> msg) -> Sub msg



-- MODEL


type alias Ride =
    { rideId : String
    , status : String
    , driverId : Maybe String
    }


type alias DriverForm =
    { rideId : String
    , driverId : String
    , lat : Float
    , lng : Float
    }


type alias RideRequestForm =
    { rideId : String
    , riderId : String
    , lat : Float
    , lng : Float
    }


type alias Model =
    { rideIdInput : String
    , rides : List Ride
    , driverIdInput : String
    , driverLatInput : String
    , driverLngInput : String
    , riderIdInput : String
    , riderLatInput : String
    , riderLngInput : String
    , formError : Maybe String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { rideIdInput = ""
      , rides = []
      , driverIdInput = ""
      , driverLatInput = ""
      , driverLngInput = ""
      , riderIdInput = ""
      , riderLatInput = ""
      , riderLngInput = ""
      , formError = Nothing
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = RideIdChanged String
    | JoinClicked
    | RideUpdateArrived Decode.Value
    | DriverIdChanged String
    | DriverLatChanged String
    | DriverLngChanged String
    | RegisterDriverClicked
    | RiderIdChanged String
    | RiderLatChanged String
    | RiderLngChanged String
    | RequestRideClicked


rideDecoder : Decoder Ride
rideDecoder =
    Decode.map3 Ride
        (Decode.field "ride_id" Decode.string)
        (Decode.field "status" Decode.string)
        (Decode.maybe (Decode.field "driver_id" Decode.string))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RideIdChanged newId ->
            ( { model | rideIdInput = newId }, Cmd.none )

        JoinClicked ->
            case requireRideId model of
                Err err ->
                    ( { model | formError = Just err }, Cmd.none )

                Ok rideId ->
                    ( { model | formError = Nothing }, joinRideChannel rideId )

        RideUpdateArrived value ->
            case Decode.decodeValue rideDecoder value of
                Ok ride ->
                    ( { model | rides = upsertRide ride model.rides }, Cmd.none )

                Err _ ->
                    -- Malformed payload from the JS side; ignore rather than crash.
                    ( model, Cmd.none )

        DriverIdChanged newVal ->
            ( { model | driverIdInput = newVal }, Cmd.none )

        DriverLatChanged newVal ->
            ( { model | driverLatInput = newVal }, Cmd.none )

        DriverLngChanged newVal ->
            ( { model | driverLngInput = newVal }, Cmd.none )

        RegisterDriverClicked ->
            case parseDriverForm model of
                Err err ->
                    ( { model | formError = Just err }, Cmd.none )

                Ok form ->
                    ( { model | formError = Nothing }
                    , registerDriver
                        (Encode.object
                            [ ( "rideId", Encode.string form.rideId )
                            , ( "driverId", Encode.string form.driverId )
                            , ( "lat", Encode.float form.lat )
                            , ( "lng", Encode.float form.lng )
                            ]
                        )
                    )

        RiderIdChanged newVal ->
            ( { model | riderIdInput = newVal }, Cmd.none )

        RiderLatChanged newVal ->
            ( { model | riderLatInput = newVal }, Cmd.none )

        RiderLngChanged newVal ->
            ( { model | riderLngInput = newVal }, Cmd.none )

        RequestRideClicked ->
            case parseRideRequestForm model of
                Err err ->
                    ( { model | formError = Just err }, Cmd.none )

                Ok form ->
                    ( { model | formError = Nothing }
                    , requestRide
                        (Encode.object
                            [ ( "rideId", Encode.string form.rideId )
                            , ( "riderId", Encode.string form.riderId )
                            , ( "lat", Encode.float form.lat )
                            , ( "lng", Encode.float form.lng )
                            ]
                        )
                    )


upsertRide : Ride -> List Ride -> List Ride
upsertRide newRide rides =
    newRide :: List.filter (\r -> r.rideId /= newRide.rideId) rides


requireRideId : Model -> Result String String
requireRideId model =
    requireNonEmpty "Ride ID" model.rideIdInput


requireNonEmpty : String -> String -> Result String String
requireNonEmpty label raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        Err (label ++ " is required.")

    else
        Ok trimmed


requireFloat : String -> String -> Result String Float
requireFloat label raw =
    case String.toFloat (String.trim raw) of
        Just n ->
            Ok n

        Nothing ->
            Err (label ++ " must be a number.")


{-| Validates all four fields of the driver-registration form, in order,
short-circuiting on the first error. Written as an explicit nested case
pyramid (rather than tuples, which Elm caps at 3 elements, or
Result.map4, which elm/core's Result module doesn't provide) so it's
easy to follow field by field.
-}
parseDriverForm : Model -> Result String DriverForm
parseDriverForm model =
    case requireRideId model of
        Err e ->
            Err e

        Ok rideId ->
            case requireNonEmpty "Driver ID" model.driverIdInput of
                Err e ->
                    Err e

                Ok driverId ->
                    case requireFloat "Driver latitude" model.driverLatInput of
                        Err e ->
                            Err e

                        Ok lat ->
                            case requireFloat "Driver longitude" model.driverLngInput of
                                Err e ->
                                    Err e

                                Ok lng ->
                                    Ok { rideId = rideId, driverId = driverId, lat = lat, lng = lng }


parseRideRequestForm : Model -> Result String RideRequestForm
parseRideRequestForm model =
    case requireRideId model of
        Err e ->
            Err e

        Ok rideId ->
            case requireNonEmpty "Rider ID" model.riderIdInput of
                Err e ->
                    Err e

                Ok riderId ->
                    case requireFloat "Rider latitude" model.riderLatInput of
                        Err e ->
                            Err e

                        Ok lat ->
                            case requireFloat "Rider longitude" model.riderLngInput of
                                Err e ->
                                    Err e

                                Ok lng ->
                                    Ok { rideId = rideId, riderId = riderId, lat = lat, lng = lng }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    rideUpdateReceived RideUpdateArrived



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "dashboard" ]
        [ h1 [] [ text "Ride Dispatch — Live Dashboard" ]
        , viewFormError model.formError
        , div [ class "panel" ]
            [ h2 [] [ text "1. Watch a ride" ]
            , div [ class "controls" ]
                [ input
                    [ placeholder "Ride ID (e.g. ride-1)"
                    , value model.rideIdInput
                    , onInput RideIdChanged
                    ]
                    []
                , button [ onClick JoinClicked ] [ text "Watch Ride" ]
                ]
            ]
        , div [ class "panel" ]
            [ h2 [] [ text "2. Register a driver" ]
            , div [ class "controls" ]
                [ input
                    [ placeholder "Driver ID (e.g. d1)"
                    , type_ "text"
                    , value model.driverIdInput
                    , onInput DriverIdChanged
                    ]
                    []
                , input
                    [ placeholder "Latitude"
                    , type_ "text"
                    , value model.driverLatInput
                    , onInput DriverLatChanged
                    ]
                    []
                , input
                    [ placeholder "Longitude"
                    , type_ "text"
                    , value model.driverLngInput
                    , onInput DriverLngChanged
                    ]
                    []
                , button [ onClick RegisterDriverClicked ] [ text "Register Driver" ]
                ]
            ]
        , div [ class "panel" ]
            [ h2 [] [ text "3. Request a ride" ]
            , div [ class "controls" ]
                [ input
                    [ placeholder "Rider ID (e.g. r1)"
                    , type_ "text"
                    , value model.riderIdInput
                    , onInput RiderIdChanged
                    ]
                    []
                , input
                    [ placeholder "Latitude"
                    , type_ "text"
                    , value model.riderLatInput
                    , onInput RiderLatChanged
                    ]
                    []
                , input
                    [ placeholder "Longitude"
                    , type_ "text"
                    , value model.riderLngInput
                    , onInput RiderLngChanged
                    ]
                    []
                , button [ onClick RequestRideClicked ] [ text "Request Ride" ]
                ]
            ]
        , if List.isEmpty model.rides then
            div [ class "empty-state" ] [ text "No rides yet. Watch a ride ID above to see live updates." ]

          else
            table []
                [ thead []
                    [ tr []
                        [ th [] [ text "Ride ID" ]
                        , th [] [ text "Status" ]
                        , th [] [ text "Driver" ]
                        ]
                    ]
                , tbody [] (List.map viewRideRow model.rides)
                ]
        ]


viewFormError : Maybe String -> Html Msg
viewFormError maybeError =
    case maybeError of
        Nothing ->
            text ""

        Just err ->
            div [ class "form-error" ] [ text err ]


viewRideRow : Ride -> Html Msg
viewRideRow ride =
    tr []
        [ td [] [ text ride.rideId ]
        , td [ class ("status-" ++ ride.status) ] [ text ride.status ]
        , td [] [ text (Maybe.withDefault "—" ride.driverId) ]
        ]



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }