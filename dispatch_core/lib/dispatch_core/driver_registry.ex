defmodule DispatchCore.DriverRegistry do
  @moduledoc """
  Holds the live location and availability status of every driver
  currently connected to the system, backed by an ETS table for fast
  concurrent reads. `DispatchCore.Matcher` reads from this registry
  and hands the snapshot to the Erlang matching algorithm.
  """
  use GenServer

  @table :driver_registry

  # --- Client API -----------------------------------------------------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec register_driver(term(), {float(), float()}) :: :ok
  def register_driver(driver_id, location) do
    GenServer.call(__MODULE__, {:register, driver_id, location})
  end

  @spec update_location(term(), {float(), float()}) :: :ok
  def update_location(driver_id, location) do
    GenServer.call(__MODULE__, {:update_location, driver_id, location})
  end

  @spec set_status(term(), :available | :busy) :: :ok
  def set_status(driver_id, status) when status in [:available, :busy] do
    GenServer.call(__MODULE__, {:set_status, driver_id, status})
  end

  @doc """
  Returns the full driver list in the shape the Erlang matcher expects:
  [{driver_id, {lat, lng}, status}]
  """
  @spec list_drivers() :: [{term(), {float(), float()}, :available | :busy}]
  def list_drivers do
    :ets.tab2list(@table)
  end

  # --- Server callbacks ------------------------------------------------

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, driver_id, location}, _from, state) do
    :ets.insert(@table, {driver_id, location, :available})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_location, driver_id, location}, _from, state) do
    case :ets.lookup(@table, driver_id) do
      [{^driver_id, _old_loc, status}] -> :ets.insert(@table, {driver_id, location, status})
      [] -> :ok
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_status, driver_id, status}, _from, state) do
    case :ets.lookup(@table, driver_id) do
      [{^driver_id, loc, _old_status}] -> :ets.insert(@table, {driver_id, loc, status})
      [] -> :ok
    end

    {:reply, :ok, state}
  end
end
