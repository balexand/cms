defmodule CMS.NotFoundError do
  @moduledoc """
  Error that is raised when an item is not found. If `plug` is installed in your project then the
  `Plug.Exception` will be implemented for this type. This means that Phoenix will automatically
  convert this exception to a 404 HTTP response.
  """

  defexception [:message]
end

if function_exported?(Plug, :__info__, 1) do
  defimpl Plug.Exception, for: CMS.NotFoundError do
    def status(_), do: :not_found
    def actions(_), do: []
  end
end
