defmodule SaasKit do
  @moduledoc false

  @allowed_rules ~w(mix_command generate_file inject_before inject_after append prepend replace wrap_up)

  def follow_instructions(instructions, feature) do
    instructions
    |> Enum.filter(fn %{"rule" => rule} -> rule in @allowed_rules end)
    |> Enum.reduce_while([], fn instruction, acc ->
      if follow_instruction(instruction, feature) == :ok do
        {:cont, acc}
      else
        step = Map.get(instruction, "id", "")

        Mix.shell().info(
          "#{IO.ANSI.red()}There was an error. Run: mix saaskit.feature.install #{feature} --step #{step}#{IO.ANSI.reset()}"
        )

        {:halt, acc}
      end
    end)
  end

  defp follow_instruction(
         %{
           "rule" => "generate_file",
           "filename" => filename,
           "template" => template
         },
         _feature
       ) do
    Mix.Generator.create_file(filename, template, force: true)

    :ok
  end

  defp follow_instruction(
         %{
           "rule" => rule,
           "smart" => true,
           "filename" => filename,
           "template" => template
         } = instruction,
         feature
       )
       when rule in ~w(inject_before inject_after replace) do
    with true <- warn_if_file_is_missing(filename),
         true <- warn_if_file_has_content(filename, template),
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
          "#{IO.ANSI.red()}* Failed to install file:#{IO.ANSI.reset()} #{filename}"
        )

        :error
    end
  end

  defp follow_instruction(
         %{
           "rule" => "inject_before",
           "last_end" => true,
           "filename" => filename,
           "template" => template
         },
         _feature
       ) do
    if warn_if_file_is_missing(filename) && warn_if_file_has_content(filename, template) do
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

    :ok
  end

  defp follow_instruction(
         %{
           "rule" => rule,
           "filename" => filename,
           "template" => "" <> template,
           "target" => "" <> target
         } = instruction,
         feature
       )
       when rule in ~w(inject_before inject_after) and target != "" do
    with_smart_fallback(instruction, feature) do
      if warn_if_file_is_missing(filename) && warn_if_file_has_content(filename, template) do
        new_line = if Map.get(instruction, "new_line", true), do: "\n", else: ""

        new_string =
          if rule == "inject_before",
            do: template <> new_line <> target,
            else: target <> new_line <> template

        new_content =
          File.read!(filename)
          |> String.replace(target, new_string)

        write_file!(filename, new_content)

        Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
      end

      :ok
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
    if warn_if_file_is_missing(filename) && warn_if_file_has_content(filename, template) do
      existing_content = File.read!(filename)

      new_content =
        existing_content
        |> Kernel.<>("\n")
        |> Kernel.<>(template)

      write_file!(filename, new_content)

      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    end

    :ok
  end

  defp follow_instruction(
         %{
           "rule" => "prepend",
           "filename" => filename,
           "template" => "" <> template
         },
         _feature
       ) do
    if warn_if_file_is_missing(filename) && warn_if_file_has_content(filename, template) do
      existing_content = File.read!(filename)

      new_content =
        template
        |> Kernel.<>("\n")
        |> Kernel.<>(existing_content)

      write_file!(filename, new_content)

      Mix.shell().info("#{IO.ANSI.green()}* Updated file:#{IO.ANSI.reset()} #{filename}")
    end

    :ok
  end

  defp follow_instruction(
         %{
           "rule" => "replace",
           "filename" => filename,
           "template" => "" <> string_to_insert,
           "target" => "" <> string_to_replace
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

    :ok
  end

  defp follow_instruction(%{"rule" => "mix_command", "mix_command" => "" <> template}, _) do
    template = String.replace_prefix(template, "mix ", "")

    Mix.shell().info("#{IO.ANSI.green()}* Run mix command:#{IO.ANSI.reset()} #{template}")
    [cmd | args] = String.split(template, " ")

    System.cmd("mix", ["deps.get"])
    Mix.Task.run(cmd, args)

    :ok
  end

  defp follow_instruction(%{"rule" => "wrap_up"}, feature) do
    token = Application.get_env(:saas_kit, :boilerplate_token)
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/installed/#{token}/#{feature}"

    Req.post(url, json: %{})

    System.cmd("mix", ["deps.get"])
    System.cmd("mix", ["format"])

    :ok
  end

  defp follow_instruction(%{"rule" => "error", "message" => "" <> message}, _) do
    Mix.shell().error("#{IO.ANSI.red()} #{message} #{IO.ANSI.reset()}")
    :ok
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

    req =
      Req.post(
        url,
        json: params,
        max_retries: 8,
        retry_log_level: false,
        connect_options: [timeout: 60_000]
      )

    case req do
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

  defp warn_if_file_has_content(filename, content) do
    with true <- File.exists?(filename),
         existing_content <- File.read!(filename),
         true <- String.contains?("#{existing_content}", "#{content}") do
      Mix.shell().info(
        "#{IO.ANSI.yellow()}* file has content, skipping#{IO.ANSI.reset()} #{filename}"
      )

      false
    else
      _ -> true
    end
  end

  defp with_smart_fallback(%{"filename" => filename, "target" => target} = instruction, feature,
         do: block
       ) do
    with true <- File.exists?(filename),
         existing_content <- File.read!(filename),
         false <- String.contains?("#{existing_content}", "#{target}") do
      Map.put(instruction, "smart", true)
      |> follow_instruction(feature)
    else
      _ -> block
    end
  end
end
