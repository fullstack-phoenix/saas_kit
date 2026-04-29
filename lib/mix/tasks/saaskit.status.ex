defmodule Mix.Tasks.Saaskit.Status do
  @moduledoc """
  Reports current SaaS Kit state: config status, app name, installed/pending
  feature counts, and the suggested next command.

  Works as both a human snapshot and an agent state probe.

  Usage:
    mix saaskit.status
    mix saaskit.status --json

  JSON shape:

      {
        "schema_version": 1,
        "ok": true,
        "configured": true,
        "app": { "name": "MyApp", "slug": "my_app" },
        "features": { "total": 12, "installed": 3, "pending": 9 },
        "next_command": "mix saaskit.feature.install auth"
      }

  On `not_configured` or `api_unreachable` the JSON envelope is:

      {"schema_version": 1, "ok": false, "error": {"code": "...", "message": "..."}}
  """
  use Mix.Task

  alias SaasKit.API
  alias SaasKit.Task.Helpers

  @impl Mix.Task
  def run(args) do
    {opts, _} = Helpers.parse_opts(args)
    Helpers.enter_json_mode(opts)

    case API.token() do
      nil -> handle_not_configured(opts)
      _ -> fetch_and_report(opts)
    end
  end

  defp handle_not_configured(opts) do
    msg =
      "boilerplate_token is not set in config. Add to config/config.exs:\n\n" <>
        "    config :saas_kit,\n      boilerplate_token: \"your_token\"\n\n" <>
        "Get your token at https://livesaaskit.com/"

    if opts[:json] do
      Helpers.fail!(:not_configured, msg, opts, 1)
    else
      payload = %{configured: false, app: nil, features: nil, next_command: "mix saaskit.setup"}
      Helpers.emit(payload, opts, &print_human/1)
    end
  end

  defp fetch_and_report(opts) do
    case API.fetch_features() do
      {:ok, boilerplate, features} ->
        installed = Enum.count(features, & &1["installed"])
        total = length(features)
        pending = total - installed

        payload = %{
          configured: true,
          app: %{
            name: boilerplate["app_name"],
            slug: boilerplate["app_name_lower"]
          },
          features: %{total: total, installed: installed, pending: pending},
          next_command: next_command(features)
        }

        Helpers.emit(payload, opts, &print_human/1)

      {:error, :not_found} ->
        Helpers.fail!(
          :api_unreachable,
          "Boilerplate not found — the configured token did not resolve at #{API.base_url()}.",
          opts,
          1
        )

      {:error, :api_unreachable} ->
        Helpers.fail!(
          :api_unreachable,
          "Failed to reach #{API.base_url()}. Check your network and try again.",
          opts,
          1
        )
    end
  end

  defp next_command(features) do
    cond do
      Enum.all?(features, &(!&1["installed"])) -> "mix saaskit.setup"
      first = Enum.find(features, &(!&1["installed"])) -> "mix saaskit.feature.install #{first["slug"]}"
      true -> nil
    end
  end

  defp print_human(%{configured: false}) do
    Mix.shell().info("#{IO.ANSI.yellow()}! Not configured#{IO.ANSI.reset()}")
    Mix.shell().info("")
    Mix.shell().info("  Add to config/config.exs:")
    Mix.shell().info("")
    Mix.shell().info("      config :saas_kit,")
    Mix.shell().info("        boilerplate_token: \"your_token\"")
    Mix.shell().info("")
    Mix.shell().info("  Get your token at https://livesaaskit.com/")
    Mix.shell().info("")
    Mix.shell().info("  Next: mix saaskit.setup  (once configured)")
  end

  defp print_human(%{configured: true, app: app, features: f, next_command: next}) do
    Mix.shell().info("#{IO.ANSI.green()}✓ Configured#{IO.ANSI.reset()}")
    Mix.shell().info("")
    Mix.shell().info("  #{IO.ANSI.blue()}App:#{IO.ANSI.reset()}      #{app.name} (#{app.slug})")
    Mix.shell().info("  #{IO.ANSI.blue()}Features:#{IO.ANSI.reset()} #{f.installed} / #{f.total} installed (#{f.pending} pending)")

    if next do
      Mix.shell().info("")
      Mix.shell().info("  #{IO.ANSI.blue()}Next:#{IO.ANSI.reset()}     #{next}")
    else
      Mix.shell().info("")
      Mix.shell().info("  #{IO.ANSI.green()}All features installed.#{IO.ANSI.reset()}")
    end
  end
end
