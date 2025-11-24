defmodule SaasKit.TestMocks do
  @moduledoc """
  Test mocks so we don't hit the real API.

  This module provides a base for tests that use Mimic for mocking.
  Individual tests should use `expect` to define their specific mock behavior.
  """
  use ExUnit.CaseTemplate
  use Mimic

  using do
    quote do
      use Mimic
      import SaasKit.TestMocks
    end
  end
end
