defmodule Mix.Tasks.Saaskit.Feature.Install do
  @moduledoc """
  Installs a SaaS Kit feature.

  Usage:
    mix saaskit.feature.install <feature_name>
    mix saaskit.feature.install <feature_name> --token <token>
    mix saaskit.feature.install <feature_name> --step <uuid>
  """
  use Mix.Task

  @impl Mix.Task
  def run([feature]) do
    install_feature(feature)
  end

  def run([feature | args]) do
    opts =
      args
      |> OptionParser.parse(switches: [token: :string, step: :string])
      |> case do
        {opts, _, _} -> opts
        _ -> []
      end

    install_feature(feature, opts)
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

  defp install_feature(feature, opts \\ []) do
    token = Keyword.get(opts, :token) || get_token()
    Application.ensure_all_started([:req, :hex])

    Mix.shell().info("#{IO.ANSI.blue()}* Installing feature:#{IO.ANSI.reset()} #{feature}")
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/install/#{token}/#{feature}"

    url =
      case Keyword.get(opts, :step) do
        nil -> url
        step -> "#{url}?step=#{step}"
      end

    case Req.get(url) do
      {:ok, %{body: %{"instructions" => instructions}}} ->
        SaasKit.follow_instructions(instructions, feature)

      _ ->
        Mix.shell().error(
          "#{IO.ANSI.red()}* Failed to install feature:#{IO.ANSI.reset()} #{feature}"
        )
    end
  end
end
