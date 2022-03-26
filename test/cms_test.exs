defmodule CMSTest do
  use ExUnit.Case, async: true
  doctest CMS

  alias CMS.CacheServer
  alias CMSTest.Page

  describe "CMSTest.Page" do
    setup do
      CMS.update(Page)
      :ok
    end

    test "get_by" do
      assert {:ok, %{_id: "page-1"}} = CMS.get_by(Page, path: "/")
    end

    test "update" do
      assert {:ok, %{_id: "page-1"}} = CacheServer.fetch(Page, "page-1")

      assert {:ok, "page-1"} = CacheServer.fetch(:"Elixir.CMSTest.Page.path", "/")
    end
  end
end
