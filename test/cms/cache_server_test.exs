defmodule CMS.CacheServerTest do
  use ExUnit.Case, async: true
  doctest CMS.CacheServer, import: true

  alias CMS.CacheServer

  setup do
    CacheServer.table_names()
    |> Enum.each(&CacheServer.delete_table/1)

    {:ok, pid} = CacheServer.start_link()
    %{pid: pid}
  end

  describe "fetch" do
    setup %{pid: pid} do
      CacheServer.put_tables(pid, my_table: [{"/", "home page"}])

      :ok
    end

    test "missing table", %{pid: pid} do
      assert CacheServer.fetch(pid, :does_not_exist, "key") == {:error, :no_table}
    end

    test "table doesn't contain key", %{pid: pid} do
      assert CacheServer.fetch(pid, :my_table, "wrong key") == {:error, :not_found}
    end

    test "table contains key", %{pid: pid} do
      assert CacheServer.fetch(pid, :my_table, "/") == {:ok, "home page"}
    end
  end

  test "create, replaces, and delete table", %{pid: pid} do
    assert CacheServer.put_tables(pid, my_table: [{"/", "one"}]) == :ok

    assert CacheServer.values(pid, :my_table) == {:ok, ["one"]}
    assert CacheServer.fetch(pid, :my_table, "/") == {:ok, "one"}

    # replace table
    assert CacheServer.put_tables(pid, my_table: [{"/two", "two"}]) == :ok

    assert CacheServer.fetch(pid, :my_table, "/") == {:error, :not_found}
    assert CacheServer.fetch(pid, :my_table, "/two") == {:ok, "two"}

    assert CacheServer.delete_table(pid, :my_table) == :ok

    assert CacheServer.fetch(pid, :my_table, "anything") == {:error, :no_table}
  end

  test "create multiple tables", %{pid: pid} do
    assert CacheServer.put_tables(pid, table_1: [{"/", "one"}], table_2: %{"/" => "two"}) == :ok

    assert CacheServer.fetch(pid, :table_1, "/") == {:ok, "one"}
    assert CacheServer.fetch(pid, :table_2, "/") == {:ok, "two"}
  end

  test "create with map", %{pid: pid} do
    assert CacheServer.put_tables(pid, my_table: %{my_key: "value"}) == :ok

    assert CacheServer.fetch(pid, :my_table, :my_key) == {:ok, "value"}
  end

  test "table_names", %{pid: pid} do
    assert CacheServer.table_names(pid) == []

    CacheServer.put_tables(pid, table_1: %{my_key: "value"})
    CacheServer.put_tables(pid, table_2: %{my_key: "value"})

    assert CacheServer.table_names(pid) == [:table_1, :table_2]

    CacheServer.delete_table(pid, :table_2)

    assert CacheServer.table_names(pid) == [:table_1]

    CacheServer.delete_table(pid, :table_1)
    assert CacheServer.table_names(pid) == []
  end

  test "values", %{pid: pid} do
    assert CacheServer.values(pid, :doesnt_exist) == {:error, :no_table}
  end
end
