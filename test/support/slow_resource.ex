defmodule CMSTest.SlowResource do
  use CMS

  @impl true
  def list do
    :timer.sleep(400)
    []
  end

  @impl true
  def primary_key(item), do: item._id
end
