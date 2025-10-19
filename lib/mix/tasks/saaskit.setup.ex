defmodule Mix.Tasks.Saaskit.Setup do
  @moduledoc """
  Installs a SaaS Kit feature.
  """
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    if !Application.get_env(:saas_kit, :boilerplate_token) do
      Mix.raise("""
      It seems that you have not yet added the api_key to the config.
      You can cet the api key from your boilerplate page at https://livesaaskit.com/
      Install it like:

          config :saas_kit,
            boilerplate_token: "secretapikey"

      """)
    end

    install_setup()
  end

  defp install_setup do
    Application.ensure_all_started(:req)
    token = Application.get_env(:saas_kit, :boilerplate_token)

    Mix.shell().info("#{IO.ANSI.blue()}* Performing setup:#{IO.ANSI.reset()}")
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/install/#{token}/setup"

    case Req.get(url) do
      {:ok, %{body: %{"instructions" => instructions}}} ->
        create_files(instructions)

      _ ->
        Mix.shell().error("#{IO.ANSI.red()}* Failed to run setup#{IO.ANSI.reset()}")
    end
  end

  defp create_files(instructions) do
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

    Mix.shell().info("#{IO.ANSI.green()}* Setup completed!#{IO.ANSI.reset()}")
  end
end
