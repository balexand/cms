defmodule CMSTest do
  use ExUnit.Case
  doctest CMS

  alias CMS.CacheServer
  alias CMSTest.{MinimalResource, Page}

  import Mox, only: [verify_on_exit!: 1]
  setup :verify_on_exit!

  describe "CMSTest.MinimalResource" do
    test "get_by" do
      assert_raise ArgumentError,
                   "invalid lookup key :path; allowed values are []",
                   fn -> CMS.get_by(MinimalResource, path: "/") end
    end

    test "update" do
      CMS.update(MinimalResource)

      assert CacheServer.fetch(MinimalResource, "item-2") == {:ok, %{_id: "item-2"}}
    end
  end

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
                   "invalid lookup key :invalid_key; allowed values are [:path]",
                   fn -> CMS.get_by(Page, invalid_key: "/") end
    end

    test "list_by from cache" do
      CMS.update(Page)

      assert [%{_id: "page-2"}, %{_id: "page-1"}, %{_id: "page-3"}] =
               CMS.list_by(Page, :display_order)

      assert [%{_id: "page-2"}] = CMS.list_by(Page, :display_order, range: [0])
      assert [%{_id: "page-2"}, %{_id: "page-1"}] = CMS.list_by(Page, :display_order, range: 0..1)

      assert [%{_id: "page-2"}, %{_id: "page-1"}, %{_id: "page-3"}] =
               CMS.list_by(Page, :display_order, range: 0..200)

      assert [%{_id: "page-3"}] = CMS.list_by(Page, :display_order, range: 2..2)
    end

    test "list_by from empty cache" do
      CMS.update(Page)
      CacheServer.put_table(Page.ListByDisplayOrder, [])

      assert CMS.list_by(Page, :display_order) == []
    end

    test "list_by not cached" do
      assert [%{_id: "page-2"}, %{_id: "page-1"}, %{_id: "page-3"}] =
               CMS.list_by(Page, :display_order)

      assert [%{_id: "page-2"}, %{_id: "page-1"}] = CMS.list_by(Page, :display_order, range: 0..1)

      assert [%{_id: "page-1"}, %{_id: "page-3"}] =
               CMS.list_by(Page, :display_order, range: 1..1000)
    end

    test "update" do
      CMS.update(Page)

      assert {:ok, %{_id: "page-1"}} = CacheServer.fetch(Page, "page-1")

      assert CacheServer.fetch(Page.ListByDisplayOrder, 0) == {:ok, "page-2"}
      assert CacheServer.fetch(Page.ListByDisplayOrder, 1) == {:ok, "page-1"}
      assert CacheServer.fetch(Page.ListByDisplayOrder, 2) == {:ok, "page-3"}
      assert CacheServer.fetch(Page.ListByDisplayOrder, 3) == {:error, :not_found}

      assert CacheServer.fetch(Page.ByPath, "/") == {:ok, "page-1"}
    end
  end
end
