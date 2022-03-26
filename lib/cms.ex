defmodule CMS do
  # TODO review callbacks; do we need to use map() or can we use any()
  @callback fetch_by(Keyword.t()) :: {:ok, map()} | {:error, :not_found}
  @callback list() :: [map()]
  @callback lookup_key(atom(), map()) :: any()
  @callback order_by(atom(), [map()]) :: [any()]
  @callback primary_key(map()) :: atom()

  @optional_callbacks fetch_by: 1, lookup_key: 2, order_by: 2

  alias CMS.CacheServer

  @using_opts_validation [
    list_keys: [
      type: {:list, :atom},
      default: []
    ],
    lookup_keys: [
      type: {:list, :atom},
      default: []
    ]
  ]

  defmacro __using__(opts) do
    quote do
      opts = NimbleOptions.validate!(unquote(opts), unquote(@using_opts_validation))

      @behaviour CMS

      @cms_list_keys Keyword.fetch!(opts, :list_keys)
      @cms_lookup_keys Keyword.fetch!(opts, :lookup_keys)

      @doc false
      def __cms_list_keys__, do: @cms_list_keys

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

  # TODO validate opts: order, page
  def list_by(mod, name, opts \\ []) do
    list_table = list_table(mod, name)

    case CacheServer.fetch(list_table, 0) do
      # TODO table not found

      {:ok, _} ->
        Keyword.get(opts, :range, Stream.unfold(0, &{&1, &1 + 1}))
        |> Stream.map(fn i -> CacheServer.fetch(list_table, i) end)
        |> Enum.take_while(fn
          {:ok, _} -> true
          {:error, :not_found} -> false
        end)
        |> Enum.map(fn {:ok, primary_key} ->
          {:ok, item} = CacheServer.fetch(mod, primary_key)
          item
        end)

      {:error, :not_found} ->
        []
    end
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

    list_tables =
      Enum.map(mod.__cms_list_keys__(), fn name ->
        list_pairs =
          mod.order_by(name, items)
          |> Enum.with_index()
          |> Enum.map(fn {item, index} -> {index, mod.primary_key(item)} end)

        {list_table(mod, name), list_pairs}
      end)

    # TODO send all tables in one request
    # TODO cast tables to all nodes

    CacheServer.put_table(mod, pairs)

    Enum.each(list_tables ++ lookup_tables, fn {name, pairs} ->
      CacheServer.put_table(name, pairs)
    end)
  end

  defp list_table(mod, name) do
    # TODO check valid name

    :"#{mod}.ListBy#{name |> Atom.to_string() |> Macro.camelize()}"
  end

  defp lookup_table(mod, name) do
    unless name in mod.__cms_lookup_keys__() do
      raise ArgumentError,
            "invalid lookup key #{inspect(name)}; allowed values are #{inspect(mod.__cms_lookup_keys__())}"
    end

    :"#{mod}.By#{name |> Atom.to_string() |> Macro.camelize()}"
  end
end
