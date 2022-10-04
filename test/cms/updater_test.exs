defmodule CMS.UpdaterTest do
  use ExUnit.Case, async: true

  alias CMS.Updater
  alias CMSTest.SlowResource

  # slightly more than the delay in SlowResource
  @timeout_plus 800

  setup do
    {:ok, pid} = Updater.start_link(module: SlowResource)
    %{pid: pid}
  end

  defp assert_no_extra_messages_received, do: refute_receive(_, @timeout_plus)

  test "await_initialization waits then receives :ok", %{pid: pid} do
    assert :ok == Updater.await_initialization(pid, timeout: @timeout_plus)

    assert_no_extra_messages_received()
  end

  test "await_initialization times out", %{pid: pid} do
    assert {:error, :timeout} == Updater.await_initialization(pid, timeout: 1)

    assert_no_extra_messages_received()
  end

  test "await_initialization called after initialization", %{pid: pid} do
    :timer.sleep(@timeout_plus)

    assert :ok == Updater.await_initialization(pid, timeout: 1)
  end
end
