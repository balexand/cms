defmodule CMS.UpdaterTest do
  use ExUnit.Case, async: true

  alias CMS.Updater
  alias CMSTest.SlowResource

  # slightly more than the delay in SlowResource
  @timeout 800

  setup do
    {:ok, pid} = Updater.start_link(module: SlowResource)
    %{pid: pid}
  end

  defp assert_no_extra_messages_received, do: refute_receive(_, @timeout)

  test "await_initialization waits then receives :ok", %{pid: pid} do
    assert :ok == Updater.await_initialization(pid, timeout: @timeout)

    assert_no_extra_messages_received()
  end

  test "await_initialization times out", %{pid: pid} do
    assert {:error, :timeout} == Updater.await_initialization(pid, timeout: 1)

    assert_no_extra_messages_received()
  end

  test "await_initialization instant response", %{pid: pid} do
    :timer.sleep(@timeout)

    assert :ok == Updater.await_initialization(pid, timeout: 1)
  end
end
