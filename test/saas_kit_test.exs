defmodule Mix.Tasks.Saaskit.TestTask do
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    :saas_kit
    |> Application.fetch_env!(:test_pid)
    |> send({:mix_task_run, args})
  end
end

defmodule SaasKitTest do
  use ExUnit.Case, async: false
  use SaasKit.TestMocks

  setup :set_mimic_from_context

  setup do
    original_shell = Mix.shell()
    cwd = File.cwd!()
    tmp_dir = Path.join(System.tmp_dir!(), "saas_kit_test-#{System.unique_integer([:positive])}")

    Mix.shell(Mix.Shell.Process)
    File.mkdir_p!(tmp_dir)
    File.cd!(tmp_dir)

    on_exit(fn ->
      Mix.shell(original_shell)
      File.cd!(cwd)
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "generate_file" do
    setup :setup_mix_generator

    test "creates files for generate_file instructions" do
      filename = ".env"
      template = "API_KEY=foo\n\n"

      instructions = [
        %{
          "rule" => "generate_file",
          "filename" => filename,
          "template" => template
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:mix_generator, [filename: ^filename, template: ^template]}
    end
  end

  describe "inject_before with last_end: true" do
    test "injects code before last 'end' statement" do
      filename = "lib/sample.ex"
      template = "\n  def hello, do: :world\n"
      write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "inject_before",
          "last_end" => true,
          "filename" => filename,
          "template" => template
        }
      ]

      expected_content =
        """
        defmodule Sample do
          def hello do
            IO.puts("Hello, World!")
          end

          def hello, do: :world
        end
        """

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert File.read!(filename) == expected_content
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end
  end

  describe "mix.exs dependency injection" do
    test "inject_before inserts dependency templates through the dependency patcher" do
      write_mix_project!()

      instructions = [
        %{
          "rule" => "inject_before",
          "filename" => "mix.exs",
          "template" => ~s|{:req, "~> 0.5"}|,
          "target" => "{:phoenix, \"~> 1.8\"}"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      content = File.read!("mix.exs")

      assert content =~ ~s|{:phoenix, "~> 1.8"},|
      assert content =~ ~s|{:jason, "~> 1.4"},|
      assert content =~ ~s|{:req, "~> 0.5"}|

      assert :binary.match(content, ~s|{:jason, "~> 1.4"}|) <
               :binary.match(content, ~s|{:req, "~> 0.5"}|)

      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
      assert message =~ "mix.exs"
    end

    test "inject_after extracts multiple dependencies from a larger template" do
      write_mix_project!()

      instructions = [
        %{
          "rule" => "inject_after",
          "filename" => "mix.exs",
          "template" => """
          Add the dependencies below:

          {:req, "~> 0.5"}
          {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
          """,
          "target" => "{:jason, \"~> 1.4\"}"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      content = File.read!("mix.exs")

      assert content =~ ~s|{:req, "~> 0.5"}|
      assert content =~ ~s|{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}|

      assert :binary.match(content, ~s|{:jason, "~> 1.4"}|) <
               :binary.match(content, ~s|{:req, "~> 0.5"}|)

      assert :binary.match(content, ~s|{:req, "~> 0.5"}|) <
               :binary.match(content, ~s|{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}|)

      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
      assert message =~ "mix.exs"
    end

    test "falls back to normal injection when mix.exs template is not a dependency" do
      write_mix_project!()

      instructions = [
        %{
          "rule" => "inject_before",
          "filename" => "mix.exs",
          "template" => "# project config",
          "target" => "def project do"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      content = File.read!("mix.exs")
      assert content =~ "# project config"
      assert :binary.match(content, "# project config") < :binary.match(content, "def project do")

      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
      assert message =~ "mix.exs"
    end
  end

  describe "inject_before and inject_after" do
    test "inject_before inserts content before target" do
      filename = "lib/sample.ex"
      target = "IO.puts(\"Hello, World!\")"
      template = "IO.inspect(:before)\n    "
      write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "inject_before",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      content = File.read!(filename)
      assert content =~ "IO.inspect(:before)"
      assert content =~ target
      assert :binary.match(content, "IO.inspect(:before)") < :binary.match(content, target)
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "inject_after inserts content after target" do
      filename = "lib/sample.ex"
      target = "IO.puts(\"Hello, World!\")"
      template = "\n    IO.inspect(:after)"
      write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "inject_after",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      content = File.read!(filename)
      assert content =~ target
      assert content =~ "IO.inspect(:after)"
      assert :binary.match(content, target) < :binary.match(content, "IO.inspect(:after)")
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips inject_before if file is missing" do
      filename = "lib/missing.ex"
      target = "def bar, do: :bar"
      template = "def foo, do: :foo"

      instructions = [
        %{
          "rule" => "inject_before",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute File.exists?(filename)
    end
  end

  describe "append" do
    test "appends content to file" do
      filename = ".gitignore"
      template = "\n.DS_Store\n.env"
      write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "append",
          "filename" => filename,
          "template" => template
        }
      ]

      expected_content =
        """
        defmodule Sample do
          def hello do
            IO.puts("Hello, World!")
          end
        end


        .DS_Store
        .env
        """

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert File.read!(filename) == expected_content
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips append if content already exists" do
      filename = ".gitignore"
      template = "IO.puts"
      original_content = write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "append",
          "filename" => filename,
          "template" => template
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert File.read!(filename) == original_content
    end
  end

  describe "prepend" do
    test "prepends content to file" do
      filename = ".env"
      template = "# Environment variables\n"
      write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "prepend",
          "filename" => filename,
          "template" => template
        }
      ]

      expected_content =
        """
        # Environment variables

        defmodule Sample do
          def hello do
            IO.puts("Hello, World!")
          end
        end
        """

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert File.read!(filename) == expected_content
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips prepend if content already exists" do
      filename = ".env"
      template = "defmodule Sample"
      original_content = write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "prepend",
          "filename" => filename,
          "template" => template
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert File.read!(filename) == original_content
    end
  end

  describe "replace" do
    test "replaces target string with template" do
      filename = "assets/js/app.js"
      target = "IO.puts(\"Hello, World!\")"
      template = "IO.puts(\"Goodbye, World!\")"
      write_sample_file!(filename)

      instructions = [
        %{
          "rule" => "replace",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      expected_content =
        """
        defmodule Sample do
          def hello do
            IO.puts("Goodbye, World!")
          end
        end
        """

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert File.read!(filename) == expected_content
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips replace if file is missing" do
      filename = "missing.js"
      target = "old"
      template = "new"

      instructions = [
        %{
          "rule" => "replace",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute File.exists?(filename)
    end
  end

  describe "mix_command" do
    setup :setup_system

    setup do
      Application.put_env(:saas_kit, :test_pid, self())
      Mix.Task.reenable("saaskit.test_task")

      on_exit(fn ->
        Application.delete_env(:saas_kit, :test_pid)
      end)

      :ok
    end

    test "runs mix commands from instructions" do
      instructions = [
        %{
          "rule" => "mix_command",
          "mix_command" => "mix saaskit.test_task"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:mix_task_run, []}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Run mix command:"
    end

    test "handles mix commands with arguments" do
      instructions = [
        %{
          "rule" => "mix_command",
          "mix_command" => "mix saaskit.test_task --names"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      # First call is always deps.get
      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:mix_task_run, ["--names"]}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Run mix command:"
    end
  end

  describe "smart inject_after" do
    test "fetches remote content for smart patch instructions" do
      filename = "lib/sample.ex"
      template = "def hello, do: :world"
      write_sample_file!(filename)
      base_url = start_http_server(%{"template" => "updated content"})

      Application.put_env(:saas_kit, :base_url, base_url)
      Application.put_env(:saas_kit, :boilerplate_token, "test-token")

      instructions = [
        %{
          "rule" => "inject_after",
          "smart" => true,
          "filename" => filename,
          "template" => template,
          "id" => "abc-123"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:http_request, "POST", path, request}
      assert path == "/api/boilerplate/patch_file/test-token"

      content =
        request
        |> request_body()
        |> Jason.decode!()
        |> Map.fetch!("content")

      assert content ==
               "defmodule Sample do\n  def hello do\n    IO.puts(\"Hello, World!\")\n  end\nend\n"

      assert File.read!(filename) == "updated content\n"
    end
  end

  describe "wrap_up" do
    setup :setup_system

    test "sends completion notification and runs cleanup commands" do
      base_url = start_http_server(%{})

      Application.put_env(:saas_kit, :base_url, base_url)
      Application.put_env(:saas_kit, :boilerplate_token, "test-token")

      instructions = [
        %{
          "rule" => "wrap_up"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:http_request, "POST", "/api/boilerplate/installed/test-token/demo_feature",
                      _}

      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:system_cmd, "mix", ["format"]}
    end
  end

  describe "filtering unknown rules" do
    test "filters out instructions with unknown rules" do
      instructions = [
        %{
          "rule" => "unknown_rule",
          "filename" => "test.ex"
        },
        %{
          "rule" => "invalid_operation",
          "data" => "something"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute File.exists?("test.ex")
    end
  end

  defp write_sample_file!(filename) do
    content = """
    defmodule Sample do
      def hello do
        IO.puts("Hello, World!")
      end
    end
    """

    filename
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(filename, content)
    content
  end

  defp write_mix_project! do
    content = """
    defmodule Demo.MixProject do
      use Mix.Project

      def project do
        [
          app: :demo,
          deps: deps()
        ]
      end

      def application do
        [
          extra_applications: [:logger]
        ]
      end

      defp deps do
        [
          {:phoenix, "~> 1.8"},
          {:jason, "~> 1.4"}
        ]
      end
    end
    """

    File.write!("mix.exs", content)
    content
  end

  defp start_http_server(response_body) do
    parent = self()

    {:ok, listen_socket} =
      :gen_tcp.listen(0, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true,
        ip: {127, 0, 0, 1}
      ])

    {:ok, port} = :inet.port(listen_socket)

    pid =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        request = recv_request(socket)
        [request_line | _] = String.split(request, "\r\n", parts: 2)
        [method, path | _] = String.split(request_line, " ", parts: 3)

        send(parent, {:http_request, method, path, request})

        body = Jason.encode!(response_body)

        :gen_tcp.send(socket, [
          "HTTP/1.1 200 OK\r\n",
          "content-type: application/json\r\n",
          "content-length: #{byte_size(body)}\r\n",
          "connection: close\r\n",
          "\r\n",
          body
        ])

        :gen_tcp.close(socket)
        :gen_tcp.close(listen_socket)
      end)

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
      :gen_tcp.close(listen_socket)
      Application.delete_env(:saas_kit, :base_url)
      Application.delete_env(:saas_kit, :boilerplate_token)
    end)

    "http://127.0.0.1:#{port}"
  end

  defp recv_request(socket) do
    data = recv_headers(socket, "")
    [headers, body] = String.split(data, "\r\n\r\n", parts: 2)
    content_length = content_length(headers)
    body = recv_body(socket, body, content_length)

    headers <> "\r\n\r\n" <> body
  end

  defp recv_headers(socket, acc) do
    {:ok, data} = :gen_tcp.recv(socket, 0, 1_000)
    acc = acc <> data

    if String.contains?(acc, "\r\n\r\n") do
      acc
    else
      recv_headers(socket, acc)
    end
  end

  defp recv_body(_socket, body, content_length) when byte_size(body) >= content_length do
    binary_part(body, 0, content_length)
  end

  defp recv_body(socket, body, content_length) do
    {:ok, data} = :gen_tcp.recv(socket, content_length - byte_size(body), 1_000)
    recv_body(socket, body <> data, content_length)
  end

  defp content_length(headers) do
    case Regex.run(~r/content-length:\s*(\d+)/i, headers) do
      [_, content_length] -> String.to_integer(content_length)
      _ -> 0
    end
  end

  defp request_body(request) do
    request
    |> String.split("\r\n\r\n", parts: 2)
    |> List.last()
  end
end
