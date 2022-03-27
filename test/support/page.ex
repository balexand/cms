defmodule CMSTest.Page do
  use CMS, list_keys: [:display_order], lookup_keys: [:path]

  @impl true
  def fetch_by([{:path, path}]), do: MockCMSClient.fetch(path: path)

  @impl true
  def list do
    # items returned by API call to headless CMS
    [
      %{
        _id: "page-1",
        display_order: 2,
        path: %{
          current: "/"
        }
      },
      %{
        _id: "page-2",
        display_order: 1,
        path: %{
          current: "/page"
        }
      },
      %{
        _id: "page-3",
        display_order: 3,
        path: %{
          current: "/page-3"
        }
      }
    ]
  end

  @impl true
  def lookup_key(:path, item), do: item.path.current

  @impl true
  def order_by(:display_order, items), do: Enum.sort_by(items, & &1.display_order)

  @impl true
  def primary_key(item), do: item._id
end
