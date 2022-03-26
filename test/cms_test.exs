defmodule CMSTest do
  use ExUnit.Case
  doctest CMS

  alias CMS.CacheServer
  alias CMSTest.Page

  import Mox, only: [verify_on_exit!: 1]
  setup :verify_on_exit!

  describe "CMSTest.Page" do
    setup do
      CacheServer.table_names()
      |> Enum.each(&CacheServer.delete_table/1)

      :ok
    end

    test "get_by from cache" do
      CMS.update(Page)

      assert {:ok, %{_id: "page-1"}} = CMS.get_by(Page, path: "/")
      assert {:error, :not_found} = CMS.get_by(Page, path: "/not-found")
    end

    test "get_by not cached" do
      Mox.expect(MockCMSClient, :fetch, fn [path: "/"] ->
        {:ok, %{_id: "x"}}
      end)

      assert CMS.get_by(Page, path: "/") == {:ok, %{_id: "x"}}
    end

    test "update" do
      CMS.update(Page)

      assert {:ok, %{_id: "page-1"}} = CacheServer.fetch(Page, "page-1")
      assert {:ok, "page-1"} = CacheServer.fetch(:"Elixir.CMSTest.Page.path", "/")
    end
  end
end
