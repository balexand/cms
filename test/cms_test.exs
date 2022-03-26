defmodule CmsTest do
  use ExUnit.Case
  doctest Cms

  test "greets the world" do
    assert Cms.hello() == :world
  end
end
