defmodule CMS do
  @moduledoc """
  TODO

  ## Examples

  ### Lookup a page by path

      defmodule MyApp.CMS.Page do
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
        def fetch_by(path: path) do
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

      iex> CMS.get_by!(MyApp.CMS.Page, path: "/")
      %{_id: "page-1", display_order: 2, path: %{current: "/"}}

  To start a `GenServer` to fetch and cache results:

      defmodule MyApp.Application do
        # See https://hexdocs.pm/elixir/Application.html
        # for more information on OTP Applications
        @moduledoc false

        use Application

        @impl true
        def start(_type, _args) do
          children = [
            # ...
            MyApp.CMS.Page
          ]

          # See https://hexdocs.pm/elixir/Supervisor.html
          # for other strategies and supported options
          opts = [strategy: :one_for_one, name: MyApp.Supervisor]
          Supervisor.start_link(children, opts)
        end

        # ...
      end
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
  Returns the primary key of the given CMS document.
  """
  @callback primary_key(map()) :: atom()

  @optional_callbacks fetch_by: 1, lookup_key: 2

  alias CMS.{CacheServer, NotFoundError}
  require Logger

  @using_opts_validation [
    lookup_keys: [
      type: {:list, :atom},
      default: []
    ]
  ]

  defmacro __using__(opts) do
    quote do
      opts = NimbleOptions.validate!(unquote(opts), unquote(@using_opts_validation))

      @behaviour CMS

      @cms_lookup_keys Keyword.fetch!(opts, :lookup_keys)

      @doc """
      [Child spec](https://hexdocs.pm/elixir/Supervisor.html#module-child-specification) that
      starts a `CMS.Updater` instance to fetch content for this module. The
      [name](https://hexdocs.pm/elixir/GenServer.html#module-name-registration) of the updater
      process will be `#{inspect(__MODULE__)}`.
      """
      def child_spec(opts \\ []) do
        opts = Keyword.put(opts, :module, __MODULE__)

        %{id: __MODULE__, start: {CMS.Updater, :start_link, [opts]}}
      end

      @doc false
      def __cms_lookup_keys__, do: @cms_lookup_keys
    end
  end

  @doc """
  TODO
  """
  def all(mod) do
    case CacheServer.values(mod) do
      {:ok, values} -> values
      {:error, :no_table} -> mod.list()
    end
  end

  def get(mod, primary_key) do
    case CacheServer.fetch(mod, primary_key) do
      {:error, :no_table} ->
        update(mod)
        CacheServer.fetch(mod, primary_key)

      result ->
        result
    end
  end

  def get!(mod, primary_key) do
    case get(mod, primary_key) do
      {:ok, value} ->
        value

      {:error, :not_found} ->
        raise NotFoundError, "could not find result with primary key #{inspect(primary_key)}"
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

  @put_opts_validation [
    update_all_nodes: [
      type: :boolean,
      default: false,
      doc: "If `true` then update will be sent to all Erlang nodes in cluster."
    ]
  ]

  @doc """
  Replaces all ETS tables associated with the specified module.

  ## Options

  #{NimbleOptions.docs(@put_opts_validation)}
  """
  def put(mod, items, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @put_opts_validation)

    pairs = Enum.map(items, fn item -> {mod.primary_key(item), item} end)

    lookup_tables =
      Enum.map(mod.__cms_lookup_keys__(), fn name ->
        lookup_pairs =
          Enum.map(pairs, fn {primary_key, item} ->
            {mod.lookup_key(name, item), primary_key}
          end)

        {lookup_table(mod, name), lookup_pairs}
      end)

    tables = [{mod, pairs}] ++ lookup_tables

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

  @doc """
  Fetches new items by calling the `c:list/0` callback then passes resulting items to `put/3`. See
  `put/3` for available opts.
  """
  def update(mod, opts \\ []) do
    metadata = %{module: mod}

    :telemetry.span([:cms, :update], metadata, fn ->
      {put(mod, mod.list(), opts), metadata}
    end)
  end

  defp lookup_table(mod, name) do
    unless name in mod.__cms_lookup_keys__() do
      raise ArgumentError,
            "invalid lookup key #{inspect(name)}; allowed values are #{inspect(mod.__cms_lookup_keys__())}"
    end

    :"#{mod}.By#{name |> Atom.to_string() |> Macro.camelize()}"
  end
end
