defmodule CMSTest.Page do
  use CMS, lookup_keys: [:path]

  @impl true
  def fetch_by([{:path, path}]) do
    MockCMSClient.fetch(path: path)
  end

  @impl true
  def list(_opts \\ []) do
    # items returned by API call to headless CMS
    [
      %{
        _id: "page-1",
        path: %{
          current: "/"
        }
      },
      %{
        _id: "page-2",
        path: %{
          current: "/page"
        }
      }
    ]
  end

  # TODO optional when there are no lookup keys
  @impl true
  def lookup_key(:path, item), do: item.path.current

  # TODO optional: defaults to []
  @impl true
  def order_by(_key) do
    # TODO [published_at_desc: &Enum.chunk_by(&1, 10)]
    []
  end

  @impl true
  def primary_key(item), do: item._id
end
