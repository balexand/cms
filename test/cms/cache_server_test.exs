defmodule CMS.CacheServerTest do
  use ExUnit.Case, async: true
  doctest CMS.CacheServer, import: true

  alias CMS.CacheServer

  setup do
    {:ok, pid} = CacheServer.start_link()
    %{pid: pid}
  end

  describe "fetch" do
    setup %{pid: pid} do
      CacheServer.put_table(pid, :my_table, [{"/", "home page"}])

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
    assert CacheServer.put_table(pid, :my_table, [{"/", "one"}]) == :ok

    assert CacheServer.fetch(pid, :my_table, "/") == {:ok, "one"}

    # replace table
    assert CacheServer.put_table(pid, :my_table, [{"/two", "two"}]) == :ok

    assert CacheServer.fetch(pid, :my_table, "/") == {:error, :not_found}
    assert CacheServer.fetch(pid, :my_table, "/two") == {:ok, "two"}

    assert CacheServer.delete_table(pid, :my_table) == :ok

    assert CacheServer.fetch(pid, :my_table, "anything") == {:error, :no_table}
  end

  test "create with map", %{pid: pid} do
    assert CacheServer.put_table(pid, :my_table, %{my_key: "value"}) == :ok

    assert CacheServer.fetch(pid, :my_table, :my_key) == {:ok, "value"}
  end

  test "cast_put_table", %{pid: pid} do
    assert CacheServer.cast_put_table(pid, :casted_table, %{"/" => "home page"})
    :timer.sleep(500)

    assert CacheServer.fetch(pid, :casted_table, "/") == {:ok, "home page"}
  end
end
