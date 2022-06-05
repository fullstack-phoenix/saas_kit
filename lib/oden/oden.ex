defmodule Oden do
  defp warn_if_file_exists(file_name) do
    if File.exists?(file_name) do
      Mix.shell().info("#{IO.ANSI.yellow}* file exists, skipping#{IO.ANSI.reset} #{file_name}")
      false
    else
      true
    end
  end

  defp warn_if_file_is_missing(file_name) do
    if !File.exists?(file_name) do
      Mix.shell().info("#{IO.ANSI.yellow}* file missing, skipping#{IO.ANSI.reset} #{file_name}")
      false
    else
      true
    end
  end

  def create_file(file_name, do: content) do
    if warn_if_file_exists(file_name) do
      {_file_name, path} = get_file_name_and_path(file_name)
      if path && path != "" do
        File.mkdir_p(path)
      end

      File.touch(file_name)
      File.write(file_name, content)
      Mix.shell().info("#{IO.ANSI.green}* creating#{IO.ANSI.reset} #{file_name}")
    end
  end

  def delete_file(file_name) do
    if warn_if_file_is_missing(file_name) do
      Mix.shell().info("#{IO.ANSI.green}* deleting#{IO.ANSI.reset} #{file_name}")
      File.rm(file_name)
    end
  end

  def inject_into_file(file_name, opts \\ [], do: content) do
    if warn_if_file_is_missing(file_name) do
      existing_content = File.read!(file_name)

      if String.contains?(existing_content, content) == false do
        if after_string = Keyword.get(opts, :after) do
          new_content = String.replace(existing_content, after_string, "#{after_string}#{content}")
          File.write(file_name, new_content)
        end

        if before_string = Keyword.get(opts, :before) do
          if before_string == "LAST_END" do
            new_content =
              existing_content
              |> String.trim_trailing()
              |> String.trim_trailing("end")
              |> Kernel.<>(content)
              |> Kernel.<>("end\n")

            File.write(file_name, new_content)
          else
            new_content = String.replace(existing_content, before_string, "#{content}#{before_string}")
            File.write(file_name, new_content)
          end
        end

        Mix.shell().info("#{IO.ANSI.green}* injecting#{IO.ANSI.reset} #{file_name}")
      else
        Mix.shell().info("#{IO.ANSI.yellow}* file has content, skipping#{IO.ANSI.reset} #{file_name}")
      end
    end
  end

  def append_to_file(file_name, _opts \\ [], do: content) do
    if warn_if_file_is_missing(file_name) do
      existing_content = File.read!(file_name)

      new_content =
        existing_content
        |> Kernel.<>(content)

      File.write(file_name, new_content)
    end
  end

  def prepend_to_file(file_name, _opts \\ [], do: content) do
    if warn_if_file_is_missing(file_name) do
      existing_content = File.read!(file_name)

      new_content =
        content
        |> Kernel.<>(existing_content)

      File.write(file_name, new_content)
    end
  end

  def gsub_file(file_name, "" <> string_to_replace, "" <> string_to_insert) do
    if warn_if_file_is_missing(file_name) do
      existing_content = File.read!(file_name)

      new_content = String.replace(existing_content, string_to_replace, string_to_insert)

      File.write(file_name, new_content)
    end
  end

  defp get_file_name_and_path(file_name_with_path) do
    list = String.split(file_name_with_path, "/")
    file_name = List.last(list)
    path = String.replace(file_name_with_path, file_name, "")
    {file_name, path}
  end
end
