defmodule Mix.Tasks.Saaskit.Feature.Install do
  @moduledoc """
  Installs a SaaS Kit feature.

  Usage:
    mix saaskit.feature.install <feature_name>
    mix saaskit.feature.install <feature_name> --token <token>
    mix saaskit.feature.install <feature_name> --step <uuid>
    mix saaskit.feature.install <feature_name> --decision provider=stripe_subscription
  """
  use Mix.Task

  alias SaasKit.API
  alias SaasKit.Decisions

  @impl Mix.Task
  def run([feature]) do
    install_feature(feature)
  end

  def run([feature | args]) do
    opts =
      args
      |> OptionParser.parse(switches: [token: :string, step: :string, decision: :string])
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
    supplied_decisions = opts |> Keyword.get_values(:decision) |> Decisions.parse_args!()

    with {:ok, _boilerplate, features} <- API.fetch_features(token) do
      feature_metadata =
        Enum.find(features, &(&1["slug"] == feature)) ||
          %{"slug" => feature, "decisions" => []}

      decisions = Decisions.resolve(feature_metadata, supplied_decisions)
      base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
      url = "#{base_url}/api/boilerplate/install/#{token}/#{feature}"
      url = Decisions.install_url(url, Keyword.get(opts, :step), decisions)

      case Req.get(url) do
        {:ok, %{body: %{"instructions" => instructions}}} ->
          case SaasKit.follow_instructions(instructions, feature,
                 decisions: decisions,
                 token: token
               ) do
            :ok -> :ok
            {:error, _step} -> System.halt(1)
          end

        _ ->
          fail_install(feature)
      end
    else
      _failure ->
        fail_install(feature)
    end
  end

  defp fail_install(feature) do
    Mix.shell().error("#{IO.ANSI.red()}* Failed to install feature:#{IO.ANSI.reset()} #{feature}")
    System.halt(1)
  end
end
