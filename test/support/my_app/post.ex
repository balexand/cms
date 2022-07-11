# Example from docs

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
