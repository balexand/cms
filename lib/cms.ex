defmodule CMS do
  @callback fetch_by(Keyword.t()) :: {:ok, map()} | {:error, :not_found}
  @callback list() :: [map()]
  @callback lookup_key(atom(), map()) :: any()
  @callback order_by(atom(), [map()]) :: [any()]
  @callback primary_key(map()) :: atom()

  @optional_callbacks fetch_by: 1, lookup_key: 2, order_by: 2

  alias CMS.{CacheServer, NotFoundError}

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

      def child_spec(opts \\ []) do
        opts = Keyword.put(opts, :module, __MODULE__)

        %{id: __MODULE__, start: {CMS.Updater, :start_link, [opts]}}
      end

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

  def get_by!(mod, pair) do
    case get_by(mod, pair) do
      {:ok, value} -> value
      {:error, :not_found} -> raise NotFoundError, "could not find result for #{inspect(pair)}"
    end
  end

  @list_by_opts_validation [
    range: [
      type: {:custom, __MODULE__, :validate_range, []}
    ]
  ]

  @doc """
  TODO

  ## Examples

  #{NimbleOptions.docs(@list_by_opts_validation)}
  """
  def list_by(mod, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @list_by_opts_validation)
    list_table = list_table(mod, name)

    case CacheServer.fetch(list_table, 0) do
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

      {:error, :no_table} ->
        # Results not cached so we need to make a request to the CMS to fetch them. The efficient
        # way to do this would be to add a mod.list_by callback that queries the CMS such that the
        # CMS will return the results sorted and paginated. I'm not worried about optimizing this
        # since all results will come from the cache in production. Instead, fetch all results and
        # paginate them manually in this function.
        all_items = mod.order_by(name, mod.list())

        case Keyword.fetch(opts, :range) do
          {:ok, range} -> Enum.slice(all_items, range)
          :error -> all_items
        end
    end
  end

  @doc false
  def validate_range(%Range{} = range), do: {:ok, range}
  def validate_range(value), do: {:error, "not a range: #{inspect(value)}"}

  # TODO opts: update_all_nodes
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

    :ok
  end

  defp list_table(mod, name) do
    unless name in mod.__cms_list_keys__() do
      raise ArgumentError,
            "invalid list key #{inspect(name)}; allowed values are #{inspect(mod.__cms_list_keys__())}"
    end

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
