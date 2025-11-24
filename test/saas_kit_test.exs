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

      expect(File, :exists?, fn ^filename -> false end)

      expect(Path, :dirname, fn ^filename -> "." end)
      expect(File, :mkdir_p!, fn "." -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, ".env", "API_KEY=foo\n"}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Created file:"
    end

    test "skips if file already exists" do
      filename = ".env"
      template = "API_KEY=foo"

      instructions = [
        %{
          "rule" => "generate_file",
          "filename" => filename,
          "template" => template
        }
      ]

      expect(File, :exists?, fn ^filename -> true end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, _, _}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "file exists, skipping"
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

      original_content = "defmodule Sample do\nend\n"
      # The implementation strips end, adds template, then adds end back with proper spacing
      expected_content = "defmodule Sample do\n\n  def hello, do: :world\nend\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, 2, fn ^filename -> original_content end)

      expect(Path, :dirname, fn ^filename -> "lib" end)
      expect(File, :mkdir_p!, fn "lib" -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, "lib/sample.ex", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips if content already exists" do
      filename = "lib/sample.ex"
      template = "def hello, do: :world"

      instructions = [
        %{
          "rule" => "inject_before",
          "last_end" => true,
          "filename" => filename,
          "template" => template
        }
      ]

      existing_content = "defmodule Sample do\n  def hello, do: :world\nend\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, fn ^filename -> existing_content end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, _, _}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "file has content, skipping"
    end
  end

  describe "inject_before and inject_after" do
    test "inject_before inserts content before target" do
      filename = "lib/sample.ex"
      target = "def bar, do: :bar"
      template = "def foo, do: :foo\n"

      instructions = [
        %{
          "rule" => "inject_before",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      original_content = "defmodule Sample do\n  def bar, do: :bar\nend\n"
      # inject_before adds a newline between template and target by default
      expected_content = "defmodule Sample do\n  def foo, do: :foo\n\ndef bar, do: :bar\nend\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, 2, fn ^filename -> original_content end)

      expect(Path, :dirname, fn ^filename -> "lib" end)
      expect(File, :mkdir_p!, fn "lib" -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, "lib/sample.ex", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "inject_after inserts content after target" do
      filename = "lib/sample.ex"
      target = "def foo, do: :foo"
      template = "def bar, do: :bar"

      instructions = [
        %{
          "rule" => "inject_after",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      original_content = "defmodule Sample do\n  def foo, do: :foo\nend\n"
      # inject_after adds a newline between target and template by default
      expected_content = "defmodule Sample do\n  def foo, do: :foo\ndef bar, do: :bar\nend\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, 2, fn ^filename -> original_content end)

      expect(Path, :dirname, fn ^filename -> "lib" end)
      expect(File, :mkdir_p!, fn "lib" -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

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

      expect(File, :exists?, fn ^filename -> false end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, _, _}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "file missing, skipping"
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

      original_content = "*.beam\n*.ez\n"

      # Note: append adds template directly, so there will be an extra newline from the template itself
      expected_content = "*.beam\n*.ez\n\n.DS_Store\n.env\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, 2, fn ^filename -> original_content end)

      expect(Path, :dirname, fn ^filename -> "." end)
      expect(File, :mkdir_p!, fn "." -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, ".gitignore", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips append if content already exists" do
      filename = ".gitignore"
      template = ".DS_Store"

      instructions = [
        %{
          "rule" => "append",
          "filename" => filename,
          "template" => template
        }
      ]

      existing_content = "*.beam\n.DS_Store\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, fn ^filename -> existing_content end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, _, _}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "file has content, skipping"
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

      original_content = "API_KEY=secret\n"
      expected_content = "# Environment variables\nAPI_KEY=secret\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, 2, fn ^filename -> original_content end)

      expect(Path, :dirname, fn ^filename -> "." end)
      expect(File, :mkdir_p!, fn "." -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:file_write!, ".env", ^expected_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end

    test "skips prepend if content already exists" do
      filename = ".env"
      template = "# Environment variables\n"

      instructions = [
        %{
          "rule" => "prepend",
          "filename" => filename,
          "template" => template
        }
      ]

      existing_content = "# Environment variables\nAPI_KEY=secret\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, fn ^filename -> existing_content end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, _, _}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "file has content, skipping"
    end
  end

  describe "replace" do
    test "replaces target string with template" do
      filename = "assets/js/app.js"
      target = "...colocatedHooks"
      template = "...colocatedHooks, ...Hooks"

      instructions = [
        %{
          "rule" => "replace",
          "filename" => filename,
          "template" => template,
          "target" => target
        }
      ]

      original_content =
        "let liveSocket = new LiveSocket(\"/live\", Socket, {hooks: {...colocatedHooks}})\n"

      expected_content =
        "let liveSocket = new LiveSocket(\"/live\", Socket, {hooks: {...colocatedHooks, ...Hooks}})\n"

      expect(File, :exists?, fn ^filename -> true end)
      expect(File, :read!, fn ^filename -> original_content end)

      expect(Path, :dirname, fn ^filename -> "assets/js" end)
      expect(File, :mkdir_p!, fn "assets/js" -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

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

      expect(File, :exists?, fn ^filename -> false end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      refute_receive {:file_write!, _, _}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "file missing, skipping"
    end
  end

  describe "mix_command" do
    test "runs mix commands from instructions" do
      instructions = [
        %{
          "rule" => "mix_command",
          "mix_command" => "mix format"
        }
      ]

      # System.cmd is used for deps.get
      expect(System, :cmd, fn cmd, args ->
        send(self(), {:system_cmd, cmd, args})
        {"", 0}
      end)

      expect(Mix.Task, :run, fn task, args ->
        send(self(), {:mix_task_run, task, args})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:mix_task_run, "format", []}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Run mix command:"
    end

    test "handles mix commands with arguments" do
      instructions = [
        %{
          "rule" => "mix_command",
          "mix_command" => "mix test --only integration"
        }
      ]

      expect(System, :cmd, fn cmd, args ->
        send(self(), {:system_cmd, cmd, args})
        {"", 0}
      end)

      expect(Mix.Task, :run, fn task, args ->
        send(self(), {:mix_task_run, task, args})
        :ok
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:mix_task_run, "test", ["--only", "integration"]}
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

      original_content = "defmodule Sample do\nend\n"
      patched_content = "defmodule Sample do\n  def hello, do: :world\nend\n"

      expect(File, :exists?, 2, fn ^filename -> true end)
      # First call is from warn_if_file_has_content, second is from File.read
      expect(File, :read!, fn ^filename -> original_content end)
      expect(File, :read, fn ^filename -> {:ok, original_content} end)

      expect(Req, :post, fn url, opts ->
        send(self(), {:req_post, url, opts})
        {:ok, %{body: %{"template" => patched_content}}}
      end)

      expect(Path, :dirname, fn ^filename -> "lib" end)
      expect(File, :mkdir_p!, fn "lib" -> :ok end)

      expect(File, :write!, fn ^filename, content ->
        send(self(), {:file_write!, filename, content})
        :ok
      end)

      Application.put_env(:saas_kit, :boilerplate_token, "token")
      Application.put_env(:saas_kit, :base_url, "https://example.com")

      on_exit(fn ->
        Application.delete_env(:saas_kit, :boilerplate_token)
        Application.delete_env(:saas_kit, :base_url)
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      assert_receive {:req_post, "https://example.com/api/boilerplate/patch_file/token", opts}
      assert opts[:json][:content] == original_content
      assert opts[:json][:feature] == "demo_feature"
      assert opts[:json][:id] == "abc-123"
      assert opts[:connect_options] == [timeout: 60_000]

      assert_receive {:file_write!, "lib/sample.ex", ^patched_content}
      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "* Updated file:"
    end
  end

  describe "wrap_up" do
    test "sends completion notification and runs cleanup commands" do
      instructions = [
        %{
          "rule" => "wrap_up"
        }
      ]

      expect(Req, :post, fn url, opts ->
        send(self(), {:req_post, url, opts})
        {:ok, %{body: %{}}}
      end)

      # wrap_up runs deps.get and format via System.cmd
      expect(System, :cmd, 2, fn cmd, args ->
        send(self(), {:system_cmd, cmd, args})
        {"", 0}
      end)

      Application.put_env(:saas_kit, :boilerplate_token, "token123")
      Application.put_env(:saas_kit, :base_url, "https://example.com")

      on_exit(fn ->
        Application.delete_env(:saas_kit, :boilerplate_token)
        Application.delete_env(:saas_kit, :base_url)
      end)

      assert [] = SaasKit.follow_instructions(instructions, "my_feature")

      assert_receive {:req_post,
                      "https://example.com/api/boilerplate/installed/token123/my_feature",
                      json: %{}}

      assert_receive {:system_cmd, "mix", ["deps.get"]}
      assert_receive {:system_cmd, "mix", ["format"]}
    end

    test "uses default base_url if not configured" do
      instructions = [
        %{
          "rule" => "wrap_up"
        }
      ]

      expect(Req, :post, fn url, opts ->
        send(self(), {:req_post, url, opts})
        {:ok, %{body: %{}}}
      end)

      expect(System, :cmd, 2, fn cmd, args ->
        send(self(), {:system_cmd, cmd, args})
        {"", 0}
      end)

      Application.put_env(:saas_kit, :boilerplate_token, "token456")
      Application.delete_env(:saas_kit, :base_url)

      on_exit(fn ->
        Application.delete_env(:saas_kit, :boilerplate_token)
      end)

      assert [] = SaasKit.follow_instructions(instructions, "test_feature")

      assert_receive {:req_post,
                      "https://livesaaskit.com/api/boilerplate/installed/token456/test_feature",
                      json: %{}}

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

      # Should process without errors and return empty list
      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      # Should not attempt any file operations
      refute_receive {:file_write!, _, _}
    end
  end

  describe "error handling" do
    test "stops processing on smart patch failure" do
      filename = "lib/sample.ex"

      instructions = [
        %{
          "rule" => "inject_after",
          "smart" => true,
          "filename" => filename,
          "template" => "code",
          "id" => "abc-123"
        },
        %{
          "rule" => "generate_file",
          "filename" => "should_not_create.ex",
          "template" => "content"
        }
      ]

      expect(File, :exists?, 2, fn ^filename -> true end)
      expect(File, :read!, fn ^filename -> "original" end)
      expect(File, :read, fn ^filename -> {:ok, "original"} end)

      # Simulate API failure
      expect(Req, :post, fn _url, _opts ->
        {:error, :timeout}
      end)

      Application.put_env(:saas_kit, :boilerplate_token, "token")
      Application.put_env(:saas_kit, :base_url, "https://example.com")

      on_exit(fn ->
        Application.delete_env(:saas_kit, :boilerplate_token)
        Application.delete_env(:saas_kit, :base_url)
      end)

      assert [] = SaasKit.follow_instructions(instructions, "demo_feature")

      # Should not process the second instruction
      refute_receive {:file_write!, "should_not_create.ex", _}
      assert_receive {:mix_shell, :error, [message]}
      assert message =~ "Failed to install file"
    end
  end
end
