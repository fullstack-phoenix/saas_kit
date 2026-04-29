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

  def setup_mix_generator(_) do
    mix_generator =
      Mix.Generator
      |> stub(:create_file, fn filename, template ->
        send(self(), {:mix_generator, [filename: filename, template: template]})
        :ok
      end)
      |> stub(:create_file, fn filename, template, _ ->
        send(self(), {:mix_generator, [filename: filename, template: template]})
        :ok
      end)

    [mix_generator: mix_generator]
  end

  def setup_system(_) do
    system =
      System
      |> stub(:cmd, fn cmd, args ->
        send(self(), {:system_cmd, cmd, args})
        :ok
      end)

    [system: system]
  end
end
