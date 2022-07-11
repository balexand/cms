# Example from docs

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
