defmodule CMS do
  # TODO review callbacks; do we need to use map() or can we use any()
  @callback fetch_by(Keyword.t()) :: {:ok, map()} | {:error, :not_found}
  @callback list() :: [map()]
  @callback lookup_key(atom(), map()) :: any()
  @callback order_by(atom()) :: [any()]
  @callback primary_key(map()) :: atom()

  alias CMS.CacheServer

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour CMS

      @cms_lookup_keys Keyword.fetch!(opts, :lookup_keys)

      @doc false
      def __cms_lookup_keys__, do: @cms_lookup_keys
    end
  end

  def get_by(mod, [{name, value}]) do
    case CacheServer.fetch(lookup_table(mod, name), value) do
      {:ok, primary_key} ->
        {:ok, item} = CacheServer.fetch(mod, primary_key)
        {:ok, item}

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :no_table} ->
        mod.fetch_by([{name, value}])
    end
  end

  def get_by!(_mod, _pair) do
    # TODO
  end

  # TODO opts: order, page
  def list_by(_mod, _opts \\ []) do
    # TODO order is required if page is specified
    # TODO assert that order is one of supported values

    # TODO
  end

  # TODO opts: cast_update_to_nodes
  def update(mod, _opts \\ []) do
    items = mod.list()

    pairs = Enum.map(items, fn item -> {mod.primary_key(item), item} end)

    lookup_tables =
      Enum.map(mod.__cms_lookup_keys__(), fn name ->
        lookup_pairs =
          Enum.map(pairs, fn {primary_key, item} ->
            {mod.lookup_key(name, item), primary_key}
          end)

        {lookup_table(mod, name), lookup_pairs}
      end)

    # TODO create pagination tables by calling mod.order_by

    # TODO send all tables in one request
    # TODO cast tables to all nodes
    CacheServer.put_table(mod, pairs)

    Enum.each(lookup_tables, fn {name, pairs} ->
      CacheServer.put_table(name, pairs)
    end)
  end

  defp lookup_table(mod, name) do
    # TODO should raise if invalid name is passed
    :"#{mod}.#{name}"
  end
end
