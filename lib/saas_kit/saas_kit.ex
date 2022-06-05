defmodule SaasKit do
  @moduledoc """
  Documentation for `SaasKit`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> SaasKit.hello()
      :world

  """
  def hello do
    "world #{Application.get_env(:saas_kit, :api_key)}"
  end
end
