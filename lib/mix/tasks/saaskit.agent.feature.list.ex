defmodule Mix.Tasks.Saaskit.Agent.Feature.List do
  @moduledoc """
  Lists all available SaaS Kit features and their installation status.

  Usage:
    mix saaskit.agent.feature.list
    mix saaskit.agent.feature.list --filter "auth,billing"
    mix saaskit.agent.feature.list --json

  Options:
    --filter  Comma-separated words to filter features by name, slug, or description.
    --json    Emit machine-readable JSON instead of human-friendly text.

  JSON shape:

      {
        "schema_version": 1,
        "ok": true,
        "app": { "name": "MyApp", "slug": "my_app" },
        "features": [
          {
            "slug": "auth",
            "name": "Authentication",
            "public_description": "...",
            "packages": ["bcrypt_elixir"],
            "dependencies": [],
            "installed": false
          }
        ]
      }
  """
  use Mix.Task

  alias SaasKit.API
  alias SaasKit.Task.Helpers

  @impl Mix.Task
  def run(args) do
    {opts, _} = Helpers.parse_opts(args, filter: :string)
    Helpers.enter_json_mode(opts)

    if is_nil(API.token()) do
      Helpers.fail!(
        :not_configured,
        "boilerplate_token is not set. See mix saaskit.status for setup instructions.",
        opts,
        1
      )
    end

    case API.fetch_features() do
      {:ok, boilerplate, features} ->
        filtered = apply_filter(features, opts[:filter])

        payload = %{
          app: %{
            name: boilerplate["app_name"],
            slug: boilerplate["app_name_lower"]
          },
          features: Enum.map(filtered, &normalize/1)
        }

        Helpers.emit(payload, opts, &print_human/1)

      {:error, :not_found} ->
        Helpers.fail!(:api_unreachable, "Boilerplate not found at #{API.base_url()}.", opts, 1)

      {:error, :api_unreachable} ->
        Helpers.fail!(:api_unreachable, "Failed to reach #{API.base_url()}.", opts, 1)
    end
  end

  defp apply_filter(features, nil), do: features
  defp apply_filter(features, ""), do: features

  defp apply_filter(features, filter_str) do
    words =
      filter_str
      |> String.downcase()
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case words do
      [] ->
        features

      _ ->
        Enum.filter(features, fn f ->
          haystack =
            "#{f["slug"]} #{f["name"]} #{f["public_description"]}"
            |> String.downcase()

          Enum.any?(words, &String.contains?(haystack, &1))
        end)
    end
  end

  defp normalize(f) do
    %{
      slug: f["slug"],
      name: f["name"],
      public_description: f["public_description"],
      packages: f["packages"] || [],
      dependencies: f["dependencies"] || [],
      installed: f["installed"] == true
    }
  end

  defp print_human(%{app: app, features: features}) do
    Mix.shell().info(
      "#{IO.ANSI.blue()}* App:#{IO.ANSI.reset()} #{app.name} (#{app.slug})"
    )

    Enum.each(features, fn f ->
      status =
        if f.installed,
          do: "#{IO.ANSI.green()}[installed]#{IO.ANSI.reset()}",
          else: "[ ]        "

      desc = if f.public_description && f.public_description != "", do: " — #{f.public_description}", else: ""
      Mix.shell().info("  #{status} #{f.slug}#{desc}")
    end)
  end
end
