defmodule CMS.CacheServer do
  @moduledoc """
  For caching results in an ETS table. A single instance of this GenServer is started
  automatically.
  """

  use GenServer

  @default_name __MODULE__

  defmodule State do
    defstruct table_names: MapSet.new()
  end

  ###
  # Client API
  ###

  @doc """
  See `GenServer.start_link/3`.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @doc """
  Deletes a table if it exists. Returns `:ok` or `{:error, :no_table}`.

  ## Examples

      iex> delete_table(:nonexistent_table)
      {:error, :no_table}

  """
  def delete_table(pid \\ @default_name, table) when is_atom(table) do
    GenServer.call(pid, {:delete_table, table})
  end

  @doc """
  Fetches a value from the cache. Returns one of the following
    * `{:ok, value}` if the item is found
    * `{:error, :no_table}` if the table doesn't exist
    * `{:error, :not_found}` if the table exists but doesn't contain the specified key
  """
  def fetch(pid \\ @default_name, table, key) when is_atom(table) do
    case lookup(table, key) do
      {:error, :no_table} ->
        # This might be a race conidition where the the GenServer process is running
        # `replace_table` and is between the ETS delete and rename calls. We should make a request
        # to the GenServer to get a race condition free result.
        GenServer.call(pid, {:fetch, table, key})

      result ->
        result
    end
  end

  @doc """
  Creates or replaces a table with the given names. `pairs` must be a map or a list of key value
  pairs like `[{:my_key, :my_value}]`.

  ## Examples

      iex> put_table(:my_table, [{"key", "value"}])
      :ok
  """
  def put_table(pid \\ @default_name, table, pairs)
      when is_atom(table) and (is_list(pairs) or is_map(pairs)) do
    GenServer.call(pid, {:put_table, table, pairs})
  end

  @doc """
  Like `put_table/3`, but puts multiple tables in a single call.

  ## Examples

      iex> put_tables(table_1: [{"key", "value"}], table_2: %{"key" => "value"})
      :ok
  """
  def put_tables(pid \\ @default_name, tables) when is_list(tables) do
    GenServer.call(pid, {:put_tables, tables})
  end

  @doc """
  Returns a list of ETS table names managed by the cache.
  """
  def table_names(pid \\ @default_name) do
    GenServer.call(pid, :table_names)
  end

  ###
  # Server API
  ###

  @doc false
  @impl true
  def init(nil) do
    {:ok, %State{}}
  end

  @doc false
  @impl true
  def handle_call({:delete_table, table}, _from, state) do
    {:reply, delete_if_exists(table), update_in(state.table_names, &MapSet.delete(&1, table))}
  end

  def handle_call({:fetch, table, key}, _from, state) do
    {:reply, lookup(table, key), state}
  end

  def handle_call({:put_table, table, pairs}, _from, state) do
    {:reply, :ok, replace_table(state, table, pairs)}
  end

  def handle_call({:put_tables, tables}, _from, state) do
    state =
      Enum.reduce(tables, state, fn {table, pairs}, state ->
        replace_table(state, table, pairs)
      end)

    {:reply, :ok, state}
  end

  def handle_call(:table_names, _from, state) do
    {:reply, MapSet.to_list(state.table_names), state}
  end

  defp replace_table(state, table, pairs) when is_map(pairs) do
    replace_table(state, table, Enum.to_list(pairs))
  end

  defp replace_table(state, table, pairs) when is_list(pairs) do
    temp_table = :"#{table}_temp_"

    ^temp_table = :ets.new(temp_table, [:named_table, read_concurrency: true])
    true = :ets.insert(temp_table, pairs)

    delete_if_exists(table)
    ^table = :ets.rename(temp_table, table)

    update_in(state.table_names, &MapSet.put(&1, table))
  end

  defp delete_if_exists(table) do
    case :ets.whereis(table) do
      :undefined ->
        {:error, :no_table}

      tid ->
        true = :ets.delete(tid)
        :ok
    end
  end

  defp lookup(table, key) do
    case :ets.lookup(table, key) do
      [] -> {:error, :not_found}
      [{_key, value}] -> {:ok, value}
    end
  rescue
    ArgumentError ->
      {:error, :no_table}
  end
end
