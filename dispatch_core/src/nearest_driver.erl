%%%-------------------------------------------------------------------
%%% @doc nearest_driver
%%%
%%% Core matching algorithm for the dispatch system, written as a raw
%%% Erlang module. Because Elixir and Erlang share the same BEAM
%%% runtime, Elixir calls into this module as a plain, same-process
%%% function call - no serialization, no network hop, no API contract.
%%% See DispatchCore.Matcher for the Elixir side of this call.
%%% @end
%%%-------------------------------------------------------------------
-module(nearest_driver).
-export([find_nearest/2, distance/2]).

%% @doc Given a rider location and a list of drivers, returns the
%% nearest *available* driver.
%%
%% RiderLocation = {float(), float()}  (lat, lng)
%% Drivers       = [{DriverId, Location, Status}]
%%   DriverId = term()
%%   Location = {float(), float()}
%%   Status   = available | busy
%%
%% Returns {ok, DriverId, Distance} or {error, no_drivers_available}.
-spec find_nearest(RiderLocation :: {float(), float()},
                    Drivers :: [{term(), {float(), float()}, available | busy}]) ->
          {ok, term(), float()} | {error, no_drivers_available}.
find_nearest(_RiderLocation, []) ->
    {error, no_drivers_available};
find_nearest(RiderLocation, Drivers) ->
    Available = [D || {_Id, _Loc, Status} = D <- Drivers, Status =:= available],
    case Available of
        [] ->
            {error, no_drivers_available};
        _ ->
            WithDistances = [{Id, distance(RiderLocation, Loc)}
                              || {Id, Loc, _Status} <- Available],
            {NearestId, NearestDist} = pick_min(WithDistances),
            {ok, NearestId, NearestDist}
    end.

%% @doc Euclidean distance between two {X, Y} points. Kept as a simple
%% flat-plane distance since this simulator isn't modeling real-world
%% map projections - the algorithm shape is the point, not map accuracy.
-spec distance({float(), float()}, {float(), float()}) -> float().
distance({X1, Y1}, {X2, Y2}) ->
    math:sqrt(math:pow(X2 - X1, 2) + math:pow(Y2 - Y1, 2)).

%% @private Fold over {Id, Distance} pairs to find the minimum distance.
pick_min([First | Rest]) ->
    lists:foldl(
      fun({_Id, Dist} = Current, {_BestId, BestDist} = Best) ->
              case Dist < BestDist of
                  true -> Current;
                  false -> Best
              end
      end,
      First,
      Rest
     ).
