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

  #
  # describe "inject_before and inject_after" do
  #   test "inject_before inserts content before target" do
  #     filename = "lib/sample.ex"
  #     target = "def bar, do: :bar"
  #     template = "def foo, do: :foo\n"
  #
  #     instructions = [
  #       %{
  #         "rule" => "inject_before",
  #         "filename" => filename,
  #         "template" => template,
  #         "target" => target
  #       }
  #     ]
  #
  #     original_content = "defmodule Sample do\n  def bar, do: :bar\nend\n"
  #     # inject_before adds a newline between template and target by default
  #     expected_content = "defmodule Sample do\n  def foo, do: :foo\n\ndef bar, do: :bar\nend\n"
  #
  #     expect(File, :exists?, fn ^filename -> true end)
  #     expect(File, :read!, 2, fn ^filename -> original_content end)
  #
  #     expect(Path, :dirname, fn ^filename -> "lib" end)
  #     expect(File, :mkdir_p!, fn "lib" -> :ok end)
  #
  #     expect(File, :write!, fn ^filename, content ->
  #       send(self(), {:file_write!, filename, content})
  #       :ok
  #     end)
  #
  #     assert [] = SaasKit.follow_instructions(instructions, "demo_feature")
  #
  #     assert_receive {:file_write!, "lib/sample.ex", ^expected_content}
  #     assert_receive {:mix_shell, :info, [message]}
  #     assert message =~ "* Updated file:"
  #   end
  #
  #   test "inject_after inserts content after target" do
  #     filename = "lib/sample.ex"
  #     target = "def foo, do: :foo"
  #     template = "def bar, do: :bar"
  #
  #     instructions = [
  #       %{
  #         "rule" => "inject_after",
  #         "filename" => filename,
  #         "template" => template,
  #         "target" => target
  #       }
  #     ]
  #
  #   end
  #
  #   test "skips inject_before if file is missing" do
  #     filename = "lib/missing.ex"
  #     target = "def bar, do: :bar"
  #     template = "def foo, do: :foo"
  #
  #     instructions = [
  #       %{
  #         "rule" => "inject_before",
  #         "filename" => filename,
  #         "template" => template,
  #         "target" => target
  #       }
  #     ]
  #
  #   end
  # end
  #
  # describe "append" do
  #   test "appends content to file" do
  #     filename = ".gitignore"
  #     template = "\n.DS_Store\n.env"
  #
  #     instructions = [
  #       %{
  #         "rule" => "append",
  #         "filename" => filename,
  #         "template" => template
  #       }
  #     ]
  #
  #   end
  #
  #   test "skips append if content already exists" do
  #     filename = ".gitignore"
  #     template = ".DS_Store"
  #
  #     instructions = [
  #       %{
  #         "rule" => "append",
  #         "filename" => filename,
  #         "template" => template
  #       }
  #     ]
  #
  #   end
  # end
  #
  # describe "prepend" do
  #   test "prepends content to file" do
  #     filename = ".env"
  #     template = "# Environment variables\n"
  #
  #     instructions = [
  #       %{
  #         "rule" => "prepend",
  #         "filename" => filename,
  #         "template" => template
  #       }
  #     ]
  #
  #   end
  #
  #   test "skips prepend if content already exists" do
  #     filename = ".env"
  #     template = "# Environment variables\n"
  #
  #     instructions = [
  #       %{
  #         "rule" => "prepend",
  #         "filename" => filename,
  #         "template" => template
  #       }
  #     ]
  #
  #   end
  # end
  #
  # describe "replace" do
  #   test "replaces target string with template" do
  #     filename = "assets/js/app.js"
  #     target = "...colocatedHooks"
  #     template = "...colocatedHooks, ...Hooks"
  #
  #     instructions = [
  #       %{
  #         "rule" => "replace",
  #         "filename" => filename,
  #         "template" => template,
  #         "target" => target
  #       }
  #     ]
  #
  #   end
  #
  #   test "skips replace if file is missing" do
  #     filename = "missing.js"
  #     target = "old"
  #     template = "new"
  #
  #     instructions = [
  #       %{
  #         "rule" => "replace",
  #         "filename" => filename,
  #         "template" => template,
  #         "target" => target
  #       }
  #     ]
  #
  #   end
  # end
  #
  # describe "mix_command" do
  #   test "runs mix commands from instructions" do
  #     instructions = [
  #       %{
  #         "rule" => "mix_command",
  #         "mix_command" => "mix format"
  #       }
  #     ]
  #
  #   end
  #
  #   test "handles mix commands with arguments" do
  #     instructions = [
  #       %{
  #         "rule" => "mix_command",
  #         "mix_command" => "mix test --only integration"
  #       }
  #     ]
  #
  #   end
  # end
  #
  # describe "smart inject_after" do
  #   test "fetches remote content for smart patch instructions" do
  #     filename = "lib/sample.ex"
  #     template = "def hello, do: :world"
  #
  #     instructions = [
  #       %{
  #         "rule" => "inject_after",
  #         "smart" => true,
  #         "filename" => filename,
  #         "template" => template,
  #         "id" => "abc-123"
  #       }
  #     ]
  #
  #   end
  # end
  #
  # describe "wrap_up" do
  #   test "sends completion notification and runs cleanup commands" do
  #     instructions = [
  #       %{
  #         "rule" => "wrap_up"
  #       }
  #     ]
  #
  #     assert_receive {:system_cmd, "mix", ["deps.get"]}
  #     assert_receive {:system_cmd, "mix", ["format"]}
  #   end
  # end
  #
  # describe "filtering unknown rules" do
  #   test "filters out instructions with unknown rules" do
  #     instructions = [
  #       %{
  #         "rule" => "unknown_rule",
  #         "filename" => "test.ex"
  #       },
  #       %{
  #         "rule" => "invalid_operation",
  #         "data" => "something"
  #       }
  #     ]
  #
  #     # Should process without errors and return empty list
  #     assert [] = SaasKit.follow_instructions(instructions, "demo_feature")
  #
  #     # Should not attempt any file operations
  #     refute_receive {:file_write!, _, _}
  #   end
  # end
end
