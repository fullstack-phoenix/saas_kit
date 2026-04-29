defmodule SaasKit.PatcherTest do
  use ExUnit.Case, async: false

  alias SaasKit.Patcher

  setup do
    cwd = File.cwd!()

    tmp_dir =
      Path.join(System.tmp_dir!(), "saas_kit_patcher_test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    File.cd!(tmp_dir)

    on_exit(fn ->
      File.cd!(cwd)
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  describe "inject_before/1 for non-Elixir files" do
    test "injects template before target with newline" do
      write_file!("assets/js/app.js", "const x = 1;\nconst y = 2;\n")

      result =
        Patcher.inject_before(%{
          "filename" => "assets/js/app.js",
          "template" => "const z = 3;",
          "target" => "const y = 2;",
          "new_line" => true
        })

      assert result == "const x = 1;\nconst z = 3;\nconst y = 2;\n"
    end

    test "injects template before target without newline" do
      write_file!(".gitignore", "foo bar baz")

      result =
        Patcher.inject_before(%{
          "filename" => ".gitignore",
          "template" => "ZZZ",
          "target" => "bar",
          "new_line" => false
        })

      assert result == "foo ZZZbar baz"
    end
  end

  describe "inject_after/1 for non-Elixir files" do
    test "injects template after target with newline" do
      write_file!("assets/js/app.js", "const x = 1;\nconst y = 2;\n")

      result =
        Patcher.inject_after(%{
          "filename" => "assets/js/app.js",
          "template" => "const z = 3;",
          "target" => "const x = 1;",
          "new_line" => true
        })

      assert result == "const x = 1;\nconst z = 3;\nconst y = 2;\n"
    end

    test "injects template after target without newline" do
      write_file!(".env", "A=1\nB=2\n")

      result =
        Patcher.inject_after(%{
          "filename" => ".env",
          "template" => "X",
          "target" => "A=1",
          "new_line" => false
        })

      assert result == "A=1X\nB=2\n"
    end
  end

  describe "replace/1 for non-Elixir files" do
    test "replaces target with template" do
      write_file!(".gitignore", "node_modules\ndist\n")

      result =
        Patcher.replace(%{
          "filename" => ".gitignore",
          "template" => "build",
          "target" => "dist"
        })

      assert result == "node_modules\nbuild\n"
    end

    test "replaces every occurrence" do
      write_file!("README.md", "foo bar foo baz foo")

      result =
        Patcher.replace(%{
          "filename" => "README.md",
          "template" => "qux",
          "target" => "foo"
        })

      assert result == "qux bar qux baz qux"
    end
  end

  describe "inject_dependency/1" do
    test "injects a single dependency before the deps list closing bracket" do
      write_file!("mix.exs", mix_project())

      result = Patcher.inject_dependency(~s|{:req, "~> 0.5"}|)

      assert result =~ ~s|{:phoenix, "~> 1.8"},|
      assert result =~ ~s|{:jason, "~> 1.4"},|
      assert result =~ ~s|{:req, "~> 0.5"}|
      assert index_of(result, ~s|{:jason, "~> 1.4"}|) < index_of(result, ~s|{:req, "~> 0.5"}|)
    end

    test "extracts and injects multiple dependencies from surrounding template text" do
      write_file!("mix.exs", mix_project())

      result =
        Patcher.inject_dependency("""
        # install these
        {:req, "~> 0.5"}
        {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
        """)

      assert result =~ ~s|{:req, "~> 0.5"},|
      assert result =~ ~s|{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}|
      assert index_of(result, ~s|{:jason, "~> 1.4"}|) < index_of(result, ~s|{:req, "~> 0.5"}|)

      assert index_of(result, ~s|{:req, "~> 0.5"}|) <
               index_of(result, ~s|{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}|)
    end

    test "preserves content outside the deps list" do
      write_file!("mix.exs", mix_project())

      result = Patcher.inject_dependency(~s|{:req, "~> 0.5"}|)

      assert result =~ "defmodule Demo.MixProject do"
      assert result =~ "def application do"
      assert result =~ "extra_applications: [:logger]"
    end
  end

  describe "inject_before/1 for Elixir files uses ExAST" do
    test "injects template before AST-matched target" do
      source = """
      defmodule Demo do
        def run do
          IO.puts("hi")
        end
      end
      """

      write_file!("lib/demo.ex", source)

      result =
        Patcher.inject_before(%{
          "filename" => "lib/demo.ex",
          "template" => ~s{IO.inspect(:before)},
          "target" => ~s{IO.puts("hi")},
          "ast_edit" => true,
          "new_line" => true
        })

      assert result =~ "IO.inspect(:before)"
      assert result =~ ~s{IO.puts("hi")}
      assert index_of(result, "IO.inspect(:before)") < index_of(result, ~s{IO.puts("hi")})
    end

    test "matches piped calls via pipe normalization" do
      source = """
      defmodule Demo do
        def run(data) do
          data |> Enum.map(&to_string/1)
        end
      end
      """

      write_file!("lib/demo.ex", source)

      result =
        Patcher.inject_before(%{
          "filename" => "lib/demo.ex",
          "template" => "require Logger",
          "target" => "Enum.map(data, &to_string/1)",
          "ast_edit" => true,
          "new_line" => true
        })

      assert result =~ "require Logger"
      assert result =~ "Enum.map"
    end
  end

  describe "inject_after/1 for Elixir files uses ExAST" do
    test "injects template after AST-matched target" do
      source = """
      defmodule Demo do
        def run do
          IO.puts("hi")
        end
      end
      """

      write_file!("lib/demo.ex", source)

      result =
        Patcher.inject_after(%{
          "filename" => "lib/demo.ex",
          "template" => ~s{IO.inspect(:after)},
          "target" => ~s{IO.puts("hi")},
          "ast_edit" => true,
          "new_line" => true
        })

      assert result =~ "IO.inspect(:after)"
      assert result =~ ~s{IO.puts("hi")}
      assert index_of(result, ~s{IO.puts("hi")}) < index_of(result, "IO.inspect(:after)")
    end
  end

  describe "replace/1 for Elixir files uses ExAST" do
    test "replaces AST-matched target with template" do
      source = """
      defmodule Demo do
        def run do
          IO.puts("hello")
        end
      end
      """

      write_file!("lib/demo.ex", source)

      result =
        Patcher.replace(%{
          "filename" => "lib/demo.ex",
          "template" => ~s{IO.puts("goodbye")},
          "target" => ~s{IO.puts("hello")},
          "ast_edit" => true
        })

      assert result =~ ~s{IO.puts("goodbye")}
      refute result =~ ~s{IO.puts("hello")}
    end

    test "replaces piped target via pipe normalization" do
      source = """
      defmodule Demo do
        def run(data) do
          data |> Enum.map(&to_string/1)
        end
      end
      """

      write_file!("lib/demo.ex", source)

      result =
        Patcher.replace(%{
          "filename" => "lib/demo.ex",
          "template" => "Enum.map(data, &String.upcase/1)",
          "target" => "Enum.map(data, &to_string/1)",
          "ast_edit" => true
        })

      assert result =~ "String.upcase"
      refute result =~ "to_string"
    end

    test "dispatches .exs files through ExAST too" do
      source = """
      config = %{foo: 1}
      IO.inspect(config)
      """

      write_file!("config/runtime.exs", source)

      result =
        Patcher.replace(%{
          "filename" => "config/runtime.exs",
          "template" => "IO.inspect(config, label: :cfg)",
          "target" => "IO.inspect(config)",
          "ast_edit" => true
        })

      assert result =~ "label: :cfg"
    end
  end

  defp index_of(string, substring) do
    {pos, _} = :binary.match(string, substring)
    pos
  end

  defp write_file!(filename, content) do
    filename
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(filename, content)
  end

  defp mix_project do
    """
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
  end
end
