defmodule DispatchCore.ExternalServices do
  @moduledoc """
  Talks to the standalone microservices in this project - the Haskell
  ETA service (port 4001) and the Scala fare service (port 4002) - over
  plain HTTP, using Erlang's built-in `:httpc` client (from the
  `:inets` application). No extra Hex dependency needed for a couple
  of simple POST requests.

  Both calls are best-effort. Each piece of this project has its own
  toolchain to install, so it's entirely normal for one of these
  services to not be running yet - if a call fails, the caller gets
  `{:error, reason}` and the ride simply proceeds without that piece
  of information, rather than crashing.
  """

  require Logger

  @eta_service_url "http://localhost:4001/eta"
  @fare_service_url "http://localhost:4002/fare"
  @timeout_ms 3000

  @doc """
  Calls the Haskell ETA service with a pickup and destination
  coordinate. Returns `{:ok, %{distance_km: float, eta_minutes: float}}`
  or `{:error, reason}`.
  """
  @spec get_eta({float(), float()}, {float(), float()}) ::
          {:ok, %{distance_km: float(), eta_minutes: float()}} | {:error, term()}
  def get_eta({origin_lat, origin_lng}, {dest_lat, dest_lng}) do
    body =
      Jason.encode!(%{
        originLat: origin_lat,
        originLng: origin_lng,
        destLat: dest_lat,
        destLng: dest_lng
      })

    case post_json(@eta_service_url, body) do
      {:ok, %{"distance_km" => distance_km, "eta_minutes" => eta_minutes}} ->
        {:ok, %{distance_km: distance_km, eta_minutes: eta_minutes}}

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calls the Scala fare service with a distance and a coarse demand
  level. Returns `{:ok, %{total_fare: float, surge_multiplier: float}}`
  or `{:error, reason}`.
  """
  @spec get_fare(float(), integer()) ::
          {:ok, %{total_fare: float(), surge_multiplier: float()}} | {:error, term()}
  def get_fare(distance_km, demand_level) do
    body = Jason.encode!(%{distanceKm: distance_km, demandLevel: demand_level})

    case post_json(@fare_service_url, body) do
      {:ok, %{"total_fare" => total_fare, "surge_multiplier" => surge}} ->
        {:ok, %{total_fare: total_fare, surge_multiplier: surge}}

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post_json(url, body) do
    content_type = String.to_charlist("application/json")
    request = {String.to_charlist(url), [], content_type, body}

    case :httpc.request(:post, request, [{:timeout, @timeout_ms}], []) do
      {:ok, {{_http_version, 200, _reason_phrase}, _headers, response_body}} ->
        {:ok, Jason.decode!(List.to_string(response_body))}

      {:ok, {{_http_version, status, _reason_phrase}, _headers, response_body}} ->
        Logger.warning(
          "External service call to #{url} returned #{status}: #{List.to_string(response_body)}"
        )

        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.warning("External service call to #{url} failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.warning("External service call to #{url} raised: #{inspect(e)}")
      {:error, {:exception, e}}
  end
end
