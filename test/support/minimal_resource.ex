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

  @impl true
  def primary_key(item), do: item._id
end
