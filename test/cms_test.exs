defmodule CMSTest do
  use ExUnit.Case
  doctest CMS

  alias CMS.CacheServer
  alias CMSTest.Page

  describe "CMSTest.Page" do
    setup do
      CacheServer.table_names()
      |> Enum.each(&CacheServer.delete_table/1)

      :ok
    end

    test "get_by" do
      CMS.update(Page)

      assert {:ok, %{_id: "page-1"}} = CMS.get_by(Page, path: "/")
    end

    test "update" do
      CMS.update(Page)

      assert {:ok, %{_id: "page-1"}} = CacheServer.fetch(Page, "page-1")
      assert {:ok, "page-1"} = CacheServer.fetch(:"Elixir.CMSTest.Page.path", "/")
    end
  end
end
