defmodule SaasKit.Patcher do
  @moduledoc false

  def inject_before(
        %{
          "filename" => filename,
          "template" => "" <> template,
          "target" => "" <> target
        } = instruction
      ) do
    source = File.read!(filename)
    new_line = Map.get(instruction, "new_line", true)

    if ast_edit?(instruction) && elixir_file?(filename) do
      ast_inject_before(source, template, target)
    else
      string_inject_before(source, template, target, new_line)
    end
  end

  def inject_after(
        %{
          "filename" => filename,
          "template" => "" <> template,
          "target" => "" <> target
        } = instruction
      ) do
    source = File.read!(filename)
    new_line = Map.get(instruction, "new_line", true)

    if ast_edit?(instruction) && elixir_file?(filename) do
      ast_inject_after(source, template, target)
    else
      string_inject_after(source, template, target, new_line)
    end
  end

  def replace(
        %{
          "filename" => filename,
          "template" => "" <> string_to_insert,
          "target" => "" <> string_to_replace
        } = instruction
      ) do
    source = File.read!(filename)

    if ast_edit?(instruction) && elixir_file?(filename) do
      ast_replace(source, string_to_insert, string_to_replace)
    else
      string_replace(source, string_to_insert, string_to_replace)
    end
  end

  def inject_dependency(deps_string) do
    source = File.read!("mix.exs")

    new_deps =
      ~r/\{:\w+,[^}]*\}/
      |> Regex.scan(deps_string)
      |> List.flatten()

    injection =
      new_deps
      |> Enum.map(&"      #{&1}")
      |> Enum.join(",\n")

    Regex.replace(
      ~r/(\{:\w+,[^}]*\})(\s*\])/,
      source,
      "\\1,\n#{injection}\\2"
    )
  end

  defp string_inject_before(source, template, target, new_line) do
    new_line = if new_line, do: "\n", else: ""
    String.replace(source, target, template <> new_line <> target)
  end

  defp string_inject_after(source, template, target, new_line) do
    new_line = if new_line, do: "\n", else: ""
    String.replace(source, target, target <> new_line <> template)
  end

  defp string_replace(source, string_to_insert, string_to_replace) do
    String.replace(source, string_to_replace, string_to_insert)
  end

  defp ast_inject_before(source, template, target) do
    ExAST.Patcher.replace_all(source, target, template <> "\n" <> target)
  end

  defp ast_inject_after(source, template, target) do
    ExAST.Patcher.replace_all(source, target, target <> "\n" <> template)
  end

  defp ast_replace(source, string_to_insert, string_to_replace) do
    ExAST.Patcher.replace_all(source, string_to_replace, string_to_insert)
  end

  defp ast_edit?(%{"ast_edit" => ast_edit}) when ast_edit in [true, "true"] do
    true
  end

  defp ast_edit?(_), do: false

  defp elixir_file?("" <> filename) do
    String.ends_with?(filename, [".ex", ".exs"])
  end
end
