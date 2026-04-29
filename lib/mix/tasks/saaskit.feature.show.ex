defmodule Mix.Tasks.Saaskit.Feature.Show do
  @moduledoc """
  Shows full detail for a single SaaS Kit feature.

  Usage:
    mix saaskit.feature.show <slug>
    mix saaskit.feature.show <slug> --json

  JSON shape:

      {
        "schema_version": 1,
        "ok": true,
        "feature": {
          "slug": "auth",
          "name": "Authentication",
          "public_description": "...",
          "packages": ["bcrypt_elixir"],
          "dependencies": [],
          "installed": false
        }
      }
  """
  use Mix.Task

  alias SaasKit.API
  alias SaasKit.Task.Helpers

  @impl Mix.Task
  def run(args) do
    {opts, positional} = Helpers.parse_opts(args)
    Helpers.enter_json_mode(opts)

    case positional do
      [slug | _] -> show(slug, opts)
      _ -> Helpers.fail!(:usage, "Usage: mix saaskit.feature.show <slug>", opts, 1)
    end
  end

  defp show(slug, opts) do
    cond do
      is_nil(API.token()) ->
        Helpers.fail!(
          :not_configured,
          "boilerplate_token is not set. See mix saaskit.status for setup instructions.",
          opts,
          1
        )

      true ->
        fetch_and_show(slug, opts)
    end
  end

  defp fetch_and_show(slug, opts) do
    case API.fetch_features() do
      {:ok, _bp, features} ->
        case Enum.find(features, &(&1["slug"] == slug)) do
          nil ->
            Helpers.fail!(
              :feature_not_found,
              "Feature '#{slug}' does not exist. Run `mix saaskit.feature.list` to see available features.",
              opts,
              1
            )

          feature ->
            payload = %{feature: normalize(feature)}
            Helpers.emit(payload, opts, &print_human/1)
        end

      {:error, :not_found} ->
        Helpers.fail!(:api_unreachable, "Boilerplate not found at #{API.base_url()}.", opts, 1)

      {:error, :api_unreachable} ->
        Helpers.fail!(:api_unreachable, "Failed to reach #{API.base_url()}.", opts, 1)
    end
  end

  defp normalize(feature) do
    %{
      slug: feature["slug"],
      name: feature["name"],
      public_description: feature["public_description"],
      packages: feature["packages"] || [],
      dependencies: feature["dependencies"] || [],
      installed: feature["installed"] == true
    }
  end

  defp print_human(%{feature: f}) do
    status_label =
      if f.installed,
        do: "#{IO.ANSI.green()}[installed]#{IO.ANSI.reset()}",
        else: "#{IO.ANSI.yellow()}[not installed]#{IO.ANSI.reset()}"

    Mix.shell().info("#{IO.ANSI.blue()}#{f.name}#{IO.ANSI.reset()} (#{f.slug}) #{status_label}")
    Mix.shell().info("")

    if f.public_description do
      Mix.shell().info(f.public_description)
      Mix.shell().info("")
    end

    packages = if f.packages == [], do: "(none)", else: Enum.join(f.packages, ", ")
    deps = if f.dependencies == [], do: "(none)", else: Enum.join(f.dependencies, ", ")

    Mix.shell().info("  #{IO.ANSI.blue()}Packages:#{IO.ANSI.reset()}     #{packages}")
    Mix.shell().info("  #{IO.ANSI.blue()}Dependencies:#{IO.ANSI.reset()} #{deps}")

    unless f.installed do
      Mix.shell().info("")
      Mix.shell().info("  Install with: mix saaskit.feature.install #{f.slug}")
    end
  end
end
