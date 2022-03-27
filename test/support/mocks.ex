defmodule MockCMSClientBehaviour do
  @callback fetch(any()) :: any()
end

Mox.defmock(MockCMSClient, for: MockCMSClientBehaviour)
