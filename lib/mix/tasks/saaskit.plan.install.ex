defmodule Mix.Tasks.Saaskit.Plan.Install do
  @moduledoc """
  Installs a SaaS Kit plan with multiple plans.

  Usage:
    mix Saaskit.plan.install <plan_id>
  """
  use Mix.Task

  alias SaasKit.API
  alias SaasKit.Decisions

  @impl Mix.Task
  def run([plan]) do
    token = get_token()
    install_plan(token, plan)
  end

  def run([plan, token]) when is_binary(token) do
    install_plan(token, plan)
  end

  def run(_) do
    Mix.shell().info("Usage: mix saaskit.plan.install <plan_id>")
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

  defp install_plan(token, plan) do
    Application.ensure_all_started([:req])

    Mix.shell().info("#{IO.ANSI.blue()}* Installing plan:#{IO.ANSI.reset()} #{plan}")
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/install/#{token}/#{plan}"

    case Req.get(url) do
      {:ok, %{body: %{"steps" => steps}}} ->
        features =
          case API.fetch_features(token) do
            {:ok, _boilerplate, features} -> features
            _error -> []
          end

        Enum.reduce_while(steps, :ok, fn step, :ok ->
          # if Mix.shell().yes?("Install #{IO.ANSI.yellow()}#{step}#{IO.ANSI.reset()}?") do
          #   Mix.Task.run("saaskit.feature.install", [step, token])
          # else
          #   Mix.shell().info("#{IO.ANSI.yellow()}* Skipping step:#{IO.ANSI.reset()} #{step}")
          # end

          case install_feature(token, step, features) do
            :ok -> {:cont, :ok}
            {:error, _reason} = error -> {:halt, error}
          end
        end)
        |> case do
          :ok -> :ok
          {:error, _reason} -> System.halt(1)
        end

      _ ->
        Mix.shell().error("#{IO.ANSI.red()}* Failed to install plan:#{IO.ANSI.reset()} #{plan}")
        System.halt(1)
    end
  end

  defp install_feature(token, feature, features) do
    Mix.shell().info("#{IO.ANSI.blue()}* Installing feature:#{IO.ANSI.reset()} #{feature}")
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/install/#{token}/#{feature}"
    metadata = Enum.find(features, &(&1["slug"] == feature))
    decisions = Decisions.resolve(metadata)
    url = Decisions.install_url(url, nil, decisions)

    case Req.get(url) do
      {:ok, %{body: %{"instructions" => instructions}}} ->
        SaasKit.follow_instructions(instructions, feature, decisions: decisions, token: token)

      _ ->
        Mix.shell().error(
          "#{IO.ANSI.red()}* Failed to install feature:#{IO.ANSI.reset()} #{feature}"
        )

        {:error, :request_failed}
    end
  end
end
