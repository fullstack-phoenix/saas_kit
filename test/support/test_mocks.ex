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

  setup [:setup_req, :setup_mix_generator, :setup_path, :setup_file, :setup_system]

  def setup_req(_) do
    req =
      Req
      |> stub(:get, fn _, _ -> {:ok, %Req.Response{body: %{}}} end)
      |> stub(:get!, fn _, _ -> %Req.Response{body: %{}} end)
      |> stub(:post, fn _, _ -> {:ok, %Req.Response{body: %{}}} end)
      |> stub(:post!, fn _, _ -> %Req.Response{body: %{}} end)

    [req: req]
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

  def setup_path(_) do
    path =
      Path
      |> stub(:dirname, fn dirname -> dirname end)

    [path: path]
  end

  def setup_file(_) do
    file =
      File
      |> stub(:exists?, fn _ -> true end)
      |> stub(:read, fn filename ->
        send(self(), {:file_read, filename})
        {:ok, file_content()}
      end)
      |> stub(:read!, fn filename ->
        send(self(), {:file_read, filename})
        file_content()
      end)
      |> stub(:write, fn filename, content ->
        send(self(), {:file_write, filename, content})
        true
      end)
      |> stub(:write!, fn filename, content ->
        send(self(), {:file_write!, filename, content})
        true
      end)
      |> stub(:mkdir_p!, fn filename ->
        send(self(), {:file_mkdir_p!, filename})
        true
      end)

    [file_module: file]
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

  defp file_content do
    """
    defmodule Sample do
      def hello do
        IO.puts("Hello, World!")
      end
    end
    """
  end
end
