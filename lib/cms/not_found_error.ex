defmodule CMS.NotFoundError do
  @moduledoc """
  Error that is raised when an item is not found. If you are using Plug or Phoenix then this error
  will automatically be converted to an HTTP 404 error.
  """

  defexception [:message, plug_status: 404]
end
