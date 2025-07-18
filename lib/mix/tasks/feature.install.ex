defmodule Mix.Tasks.Feature.Install do
  @moduledoc """
  Installs a SaaS Kit feature.

  Usage:
    mix feature.install <feature_name>
    mix feature.install <feature_name> <token>
  """
  use Mix.Task

  @impl Mix.Task
  def run([feature]) do
    token = get_token()
    install_feature(token, feature)
  end

  def run([feature, token]) when is_binary(token) do
    install_feature(token, feature)
  end

  def run(_) do
    Mix.shell().info("Usage: mix saaskit.feature.install <feature_name>")
    System.halt(1)
  end

  defp get_token do
    token = Application.get_env(:saas_kit, :boilerplate_token)

    if !token do
      Mix.raise("""
      It seems that you have not yet added the api_key to the config.
      You can cet the api key from your boilerplate page at https://livesaaskit.com/
      Install it like:

          config :saas_kit,
            boilerplate_token: "secretapikey"

      """)
    end

    token
  end

  defp install_feature(token, feature) do
    Application.ensure_all_started(:req)

    Mix.shell().info("#{IO.ANSI.blue()}* Installing feature:#{IO.ANSI.reset()} #{feature}")
    url = "https://livesaaskit.com/api/boilerplate/install/#{token}/#{feature}"

    case Req.get(url) do
      {:ok, %{body: %{"instructions" => instructions}}} ->
        create_files(instructions, feature)

      _ ->
        Mix.shell().error(
          "#{IO.ANSI.red()}* Failed to install feature:#{IO.ANSI.reset()} #{feature}"
        )
    end
  end

  defp create_files(instructions, feature) do
    installed =
      instructions
      |> Enum.map(fn %{"filename" => filename, "template" => template} ->
        File.mkdir_p!(Path.dirname(filename))
        File.write!(filename, template)
        filename
      end)

    Enum.each(installed, fn file ->
      Mix.shell().info("#{IO.ANSI.green()}* Created file:#{IO.ANSI.reset()} #{file}")
    end)

    Mix.shell().info(
      "#{IO.ANSI.green()}* Installed feature:#{IO.ANSI.reset()} #{feature} (#{length(installed)} files)"
    )
  end
end
