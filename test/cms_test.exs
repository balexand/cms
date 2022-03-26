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

    test "get_by with invalid table name" do
      assert_raise ArgumentError,
                   "invalid lookup key: :invalid_key was not specified in `lookup_keys` when `use CMS` was called",
                   fn -> CMS.get_by(Page, invalid_key: "/") end
    end

    test "update" do
      CMS.update(Page)

      assert {:ok, %{_id: "page-1"}} = CacheServer.fetch(Page, "page-1")
      assert {:ok, "page-1"} = CacheServer.fetch(:"Elixir.CMSTest.Page.path", "/")
    end
  end
end
