defmodule CMSTest.MinimalResource do
  use CMS

  @impl true
  def list do
    # items returned by API call to headless CMS
    [
      %{_id: "item-1"},
      %{_id: "item-2"}
    ]
  end

  # TODO optional when there are no order/pagination keys
  @impl true
  def order_by(_key) do
    # TODO [published_at_desc: &Enum.chunk_by(&1, 10)]
    []
  end

  @impl true
  def primary_key(item), do: item._id
end
