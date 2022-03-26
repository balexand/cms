defmodule CMS do
  @callback fetch_by(Keyword.t()) :: map()
  @callback list() :: [map()]
  @callback list(Keyword.t()) :: [map()]
  @callback lookup_keys() :: Keyword.t()
  @callback order_by(atom()) :: [any()]
  @callback primary_key(map()) :: atom()

  defmacro __using__(_opts) do
    quote do
      @behaviour CMS
    end
  end

  def get_by(_mod, _pair) do
    # TODO
  end

  # TODO opts: order, page
  def list(_mod, _opts \\ []) do
    # TODO order is required if page is specified
    # TODO assert that order is one of supported values

    # TODO
  end

  # TODO opts: cast_update_to_nodes
  def update(_mod, _opts \\ []) do
    # TODO items = mod.list()
    # TODO create pairs by calling mod.primary_key on each item
    # TODO create lookup tables by calling mod.lookup_keys
    # TODO create pagination tables by calling mod.order_by
    # TODO send all tables to CacheServer in single call/cast
  end
end
