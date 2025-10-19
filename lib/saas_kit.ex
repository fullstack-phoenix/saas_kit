defmodule SaasKit do
  @moduledoc false

  @allowed_rules ~w(generate_file inject_before inject_after append prepend replace)

  def follow_instructions(instructions, feature) do
    instructions
    |> Enum.filter(fn %{"rule" => rule} -> rule in @allowed_rules end)
    |> Enum.sort_by(fn %{"rule" => rule} -> if rule == "generate_file", do: -1, else: 0 end)
    |> Enum.each(&follow_instruction(&1, feature))
  end

  defp follow_instruction(
         %{
           "rule" => "generate_file",
           "filename" => filename,
           "template" => template
         },
         _feature
       ) do
    if warn_if_file_exists(filename) do
      write_file!(filename, template)
      Mix.shell().info("#{IO.ANSI.green()}* Created file:#{IO.ANSI.reset()} #{filename}")
    end
  end

  defp follow_instruction(
         %{
           "rule" => "inject_before",
           "last_end" => true,
           "filename" => filename,
           "template" => template
         } = _instruction,
         _feature
       ) do
    if warn_if_file_is_missing(filename) do
      new_content =
        File.read!(filename)
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>(template)
        |> String.trim_trailing()
        |> Kernel.<>("\nend\n")

      new_content = String.replace(new_content, ~r/([ \t]*\n){3,}/, "\n\n")

      write_file!(filename, new_content)

      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    end
  end

  defp follow_instruction(
         %{
           "rule" => "append",
           "filename" => filename,
           "template" => "" <> template
         },
         _feature
       ) do
    if warn_if_file_is_missing(filename) do
      existing_content = File.read!(filename)

      new_content =
        existing_content
        |> Kernel.<>(template)

      write_file!(filename, new_content)

      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    end
  end

  defp follow_instruction(
         %{
           "rule" => "prepend",
           "filename" => filename,
           "template" => "" <> template
         },
         _feature
       ) do
    if warn_if_file_is_missing(filename) do
      existing_content = File.read!(filename)

      new_content =
        template
        |> Kernel.<>(existing_content)

      write_file!(filename, new_content)

      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    end
  end

  defp follow_instruction(
         %{
           "rule" => "replace",
           "filename" => filename,
           "string_to_insert" => "" <> string_to_insert,
           "string_to_replace" => "" <> string_to_replace
         },
         _feature
       ) do
    if warn_if_file_is_missing(filename) do
      new_content =
        File.read!(filename)
        |> String.replace(string_to_replace, string_to_insert)

      write_file!(filename, new_content)

      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    end
  end

  defp follow_instruction(
         %{
           "rule" => rule,
           "filename" => filename
         } = instruction,
         feature
       )
       when rule in ~w(inject_before inject_after) do
    with true <- warn_if_file_is_missing(filename),
         {:ok, content} <- File.read(filename),
         {:ok, updated_content} <-
           get_updated_file(Map.put(instruction, "content", content), feature) do
      write_file!(filename, updated_content)
      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    else
      false ->
        :ok

      _ ->
        Mix.shell().error(
          "#{IO.ANSI.red()}* Failed to install feature:#{IO.ANSI.reset()} #{feature}"
        )
    end
  end

  defp follow_instruction(_instruction, _feature) do
    :ok
  end

  defp get_updated_file(instruction, feature) do
    token = Application.get_env(:saas_kit, :boilerplate_token)
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/patch_file/#{token}"

    params = %{
      feature: feature,
      content: Map.get(instruction, "content"),
      id: Map.get(instruction, "id")
    }

    case Req.post(url, json: params) do
      {:ok, %{body: %{"template" => "" <> template}}} ->
        {:ok, template}

      _ ->
        {:error, :failed_to_patch}
    end
  end

  defp write_file!(filename, content) do
    content = String.trim_trailing(content) <> "\n"

    File.mkdir_p!(Path.dirname(filename))
    File.write!(filename, content)
  end

  defp warn_if_file_exists(filename) do
    if File.exists?(filename) do
      Mix.shell().info("#{IO.ANSI.yellow()}* file exists, skipping#{IO.ANSI.reset()} #{filename}")

      false
    else
      true
    end
  end

  defp warn_if_file_is_missing(filename) do
    if !File.exists?(filename) do
      Mix.shell().info(
        "#{IO.ANSI.yellow()}* file missing, skipping#{IO.ANSI.reset()} #{filename}"
      )

      false
    else
      true
    end
  end
end
