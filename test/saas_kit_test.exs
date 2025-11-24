defmodule SaasKitTest do
  use ExUnit.Case, async: false
  use SaasKit.TestMocks

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    original_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(original_shell)
    end)

    :ok
  end

  describe "generate_file" do
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

      assert_receive {:file_write!, "lib/sample.ex", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end
  end

  describe "inject_before and inject_after" do
    test "inject_before inserts content before target" do
      filename = "lib/sample.ex"
      target = "IO.puts(\"Hello, World!\")"
      template = "IO.inspect(:before)\n    "

      instructions = [
        %{
          "rule" => "inject_before",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      expected_content =
        "defmodule Sample do\n  def hello do\n    IO.inspect(:before)\n    \nIO.puts(\"Hello, World!\")\n  end\nend\n"

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, "lib/sample.ex", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "inject_after inserts content after target" do
      filename = "lib/sample.ex"
      target = "IO.puts(\"Hello, World!\")"
      template = "\n    IO.inspect(:after)"

      instructions = [
        %{
          "rule" => "inject_after",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      expected_content =
        """
        defmodule Sample do
          def hello do
            IO.puts("Hello, World!")

            IO.inspect(:after)
          end
        end
        """

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, "lib/sample.ex", ^expected_content}
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

      refute_receive {:file_write!, "lib/missing.ex", _}
    end
  end

  describe "append" do
    test "appends content to file" do
      filename = ".gitignore"
      template = "\n.DS_Store\n.env"

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

      assert_receive {:file_write!, ".gitignore", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips append if content already exists" do
      filename = ".gitignore"
      template = "IO.puts"

      instructions = [
        %{
          "rule" => "append",
          "filename" => filename,
          "template" => template
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, ".gitignore", _}
    end
  end

  describe "prepend" do
    test "prepends content to file" do
      filename = ".env"
      template = "# Environment variables\n"

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

      assert_receive {:file_write!, ".env", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips prepend if content already exists" do
      filename = ".env"
      template = "defmodule Sample"

      instructions = [
        %{
          "rule" => "prepend",
          "filename" => filename,
          "template" => template
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, ".env", _}
    end
  end

  describe "replace" do
    test "replaces target string with template" do
      filename = "assets/js/app.js"
      target = "IO.puts(\"Hello, World!\")"
      template = "IO.puts(\"Goodbye, World!\")"

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

      assert_receive {:file_write!, "assets/js/app.js", ^expected_content}
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

      refute_receive {:file_write!, "missing.js", _}
    end
  end

  describe "mix_command" do
    test "runs mix commands from instructions" do
      instructions = [
        %{
          "rule" => "mix_command",
          "mix_command" => "mix help"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Run mix command:"
    end

    test "handles mix commands with arguments" do
      instructions = [
        %{
          "rule" => "mix_command",
          "mix_command" => "mix help --names"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      # First call is always deps.get
      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:mix_task_run, "help", ["--names"]}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Run mix command:"
    end
  end

  describe "smart inject_after" do
    test "fetches remote content for smart patch instructions" do
      filename = "lib/sample.ex"
      template = "def hello, do: :world"

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

      assert_receive {:req_post, url, args}
      assert url =~ "/api/boilerplate/patch_file/"
      content = Keyword.get(args, :json) |> Map.get(:content)

      assert content ==
               "defmodule Sample do\n  def hello do\n    IO.puts(\"Hello, World!\")\n  end\nend\n"

      assert_receive {:file_write!, "lib/sample.ex", "updated content\n"}
    end
  end

  describe "wrap_up" do
    test "sends completion notification and runs cleanup commands" do
      instructions = [
        %{
          "rule" => "wrap_up"
        }
      ]

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

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

      refute_receive {:file_write!, _, _}
    end
  end
end
