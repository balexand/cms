defmodule CMS do
  @moduledoc """
  TODO

  ## Examples

  ### Lookup a page by path

      defmodule MyApp.Page do
        use CMS, lookup_keys: [:path]

        # This is an example of what a document from Sanity CMS might look like.
        @dummy_result %{
          _id: "page-1",
          display_order: 2,
          path: %{
            current: "/"
          }
        }

        @impl true
        def fetch_by([{:path, path}]) do
          # Make an API call to the headless CMS and return document...

          case path do
            "/" -> {:ok, @dummy_result}
            _ -> {:error, :not_found}
          end
        end

        @impl true
        def list do
          # Make an API call to the headless CMS and return documents...
          [
            @dummy_result
            # ...
          ]
        end

        @impl true
        def lookup_key(:path, item), do: item.path.current

        @impl true
        def primary_key(item), do: item._id
      end

  To look up a page by path:

      iex> CMS.get_by!(MyApp.Page, path: "/")
      %{_id: "page-1", display_order: 2, path: %{current: "/"}}

  ### List blog posts

      defmodule MyApp.Post do
        use CMS, list_keys: [:display_order]

        @impl true
        def list do
          # Make an API call to the headless CMS and return document...
          [
            %{
              _id: "post-1",
              display_order: 2
            },
            %{
              _id: "post-2",
              display_order: 1
            }
          ]
        end

        @impl true
        def order_by(:display_order, items), do: Enum.sort_by(items, & &1.display_order)

        @impl true
        def primary_key(item), do: item._id
      end

  To list pages:

      iex> CMS.list_by(MyApp.Post, :display_order)
      [%{_id: "post-2", display_order: 1}, %{_id: "post-1", display_order: 2}]
  """

  @doc """
  Fetches a single CMS document given one or more keys. Generally implementations of this callback
  will make an API call to the headless CMS. Returns `{:ok, doc}` or `{:error, :not_found}`. This
  callback is optional and is only needed if you intend to call `CMS.get_by/2` or `CMS.get_by!/2`
  without having initialized the cache.
  """
  @callback fetch_by(Keyword.t()) :: {:ok, map()} | {:error, :not_found}

  @doc """
  Returns a list of all CMS documents. Generally implementations of this callback will make an API
  call to the headless CMS.
  """
  @callback list() :: [map()]

  @doc """
  Returns the lookup key for a document given a key name and a CMS document. Only required if you
  will be looking up documents by key. See `CMS.get_by/2` and `CMS.get_by!/2`.
  """
  @callback lookup_key(atom(), map()) :: any()

  @doc """
  Orders documents by list key. Only required if you will be listing documents using
  `CMS.list_by/3`.
  """
  @callback order_by(atom(), [map()]) :: [any()]

  @doc """
  Returns the primary key of the given CMS document.
  """
  @callback primary_key(map()) :: atom()

  @optional_callbacks fetch_by: 1, lookup_key: 2, order_by: 2

  alias CMS.{CacheServer, NotFoundError}
  require Logger

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

  @doc """
  TODO
  """
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

  @doc """
  TODO
  """
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
  TODO docs

  ## Options

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

  @update_opts_validation [
    update_all_nodes: [
      type: :boolean,
      default: false,
      doc: "If `true` then update will be sent to all Erlang nodes in cluster."
    ]
  ]

  @doc """
  TODO docs

  ## Options

  #{NimbleOptions.docs(@update_opts_validation)}
  """
  def update(mod, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @update_opts_validation)

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

    tables = [{mod, pairs}] ++ list_tables ++ lookup_tables

    if Keyword.fetch!(opts, :update_all_nodes) do
      case CacheServer.put_tables_on_all_nodes(tables) do
        {_, []} ->
          :ok

        {_, bad_nodes} ->
          Logger.error("failed to update nodes: #{inspect(bad_nodes)}")
          :error
      end
    else
      CacheServer.put_tables(tables)
      :ok
    end
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
