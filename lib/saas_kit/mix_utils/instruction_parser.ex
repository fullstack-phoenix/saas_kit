defmodule SaasKit.MixUtils.InstructionParser do
  def follow_instructions(instructions) do
    instructions
    |> Enum.sort_by(fn %{"rule" => rule} -> if rule == "delete_file", do: -2, else: 0 end)
    |> Enum.sort_by(fn %{"rule" => rule} -> if rule == "create_file", do: -1, else: 0 end)
    |> Enum.sort_by(fn %{"rule" => rule} -> if rule == "print_shell", do: 1, else: 0 end)
    |> Enum.each(&parse/1)
  end

  def parse(%{"rule" => "print_shell", "filename" => "shell", "template" => template}) do
    Mix.shell().info("""

    #{IO.ANSI.green}Install complete#{IO.ANSI.reset}

    #{template}
    """)
  end

  def parse(%{"rule" => "print_shell", "filename" => filename, "template" => template}) do
    Mix.shell().info("""

    Add the code in #{filename}:

    #{template}
    """)
  end

  def parse(%{"rule" => "delete_file", "filename" => filename}) do
    Oden.delete_file(filename)
  end

  def parse(%{
        "rule" => "create_or_append_file",
        "filename" => filename,
        "string_to_replace" => "LAST_END",
        "template" => template,
        "string_to_insert" => string_to_insert
      }) do
    if File.exists?(filename) == false do
      Oden.create_file filename do
        template
      end
    end

    Oden.inject_into_file filename, before: "LAST_END" do
      string_to_insert
    end
  end

  def parse(%{
        "rule" => "create_or_append",
        "filename" => filename,
        "template" => template,
        "target" => target,
        "lines" => [_ | _] = lines
      }) do
    if File.exists?(filename) do
      Enum.each(lines, fn [start, stop] ->
        range = Range.new(start, stop)

        template =
          template
          |> String.split("\n")
          |> Enum.slice(range)
          |> Enum.concat(["\n"])
          |> Enum.join("\n")

        Oden.inject_into_file filename, before: target do
          template
        end
      end)
    else
      Oden.create_file filename do
        template
      end
    end
  end

  def parse(%{"rule" => "create_file", "filename" => filename, "template" => template}) do
    Oden.create_file filename do
      template
    end
  end

  def parse(%{
        "rule" => "inject_before",
        "target" => target,
        "filename" => filename,
        "template" => template
      }) do
    Oden.inject_into_file filename, before: target do
      template
    end
  end

  def parse(%{
        "rule" => "inject_after",
        "target" => target,
        "filename" => filename,
        "template" => template
      }) do
    Oden.inject_into_file filename, after: target do
      template
    end
  end

  def parse(%{"rule" => "append", "filename" => filename, "template" => template}) do
    Oden.append_to_file filename do
      template
    end
  end

  def parse(%{"rule" => "prepend", "filename" => filename, "template" => template}) do
    Oden.prepend_to_file filename do
      template
    end
  end

  def parse(%{
        "rule" => "replace",
        "filename" => filename,
        "string_to_replace" => string_to_replace,
        "string_to_insert" => string_to_insert
      }) do
    Oden.gsub_file(filename, string_to_replace, string_to_insert)
  end

  def parse(%{
        "rule" => "regex_replace",
        "filename" => filename,
        "string_to_replace" => string_to_replace,
        "string_to_insert" => string_to_insert
      }) do
    Oden.gsub_file(filename, string_to_replace, string_to_insert, true)
  end

  def parse(template), do: template
end
