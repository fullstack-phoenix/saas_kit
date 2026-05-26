defmodule SaasKit.Decisions do
  @moduledoc """
  Resolves feature decisions exposed by the Live SaaS Kit API.

  Interactive installs ask for missing choices. Automated installs can provide
  explicit values with `--decision key=variant_slug`.
  """

  @type decisions :: %{optional(String.t()) => String.t()}

  @doc """
  Parses repeated `--decision key=value` arguments into a decision map.
  """
  @spec parse_args!([String.t()]) :: decisions()
  def parse_args!(args) do
    Enum.reduce(args, %{}, fn arg, acc ->
      case String.split(arg, "=", parts: 2) do
        [key, value] when key != "" and value != "" -> Map.put(acc, key, value)
        _other -> Mix.raise("Invalid --decision value '#{arg}'. Expected key=option_slug.")
      end
    end)
  end

  @doc """
  Resolves the decisions for one feature.

  `chooser` receives one unresolved decision and returns an option slug or nil.
  """
  @spec resolve(map() | nil, decisions(), (map() -> String.t() | nil)) :: decisions()
  def resolve(feature, supplied \\ %{}, chooser \\ &prompt_choice/1)

  def resolve(nil, supplied, _chooser) when supplied == %{}, do: %{}

  def resolve(nil, _supplied, _chooser) do
    Mix.raise("Cannot apply --decision values because the feature was not found in the catalog.")
  end

  def resolve(%{} = feature, supplied, chooser) do
    decisions = feature["decisions"] || []
    valid_keys = MapSet.new(decisions, & &1["key"])

    Enum.each(Map.keys(supplied), fn key ->
      unless MapSet.member?(valid_keys, key) do
        Mix.raise("Feature '#{feature["slug"]}' does not declare decision '#{key}'.")
      end
    end)

    Enum.reduce(decisions, supplied, fn decision, acc ->
      key = decision["key"]
      choice = Map.get(acc, key) || chooser.(decision)
      required? = decision["required"] == true

      case choice do
        nil when required? ->
          Mix.raise("Decision '#{key}' is required.")

        nil ->
          acc

        value ->
          validate_choice!(decision, value)
          Map.put(acc, key, value)
      end
    end)
  end

  @doc """
  Builds an install URL with optional resume step and decision query values.
  """
  @spec install_url(String.t(), String.t() | nil, decisions()) :: String.t()
  def install_url(url, step, decisions) do
    params =
      decisions
      |> Map.new(fn {key, value} -> {"decisions[#{key}]", value} end)
      |> maybe_put_step(step)

    if map_size(params) == 0 do
      url
    else
      "#{url}?#{URI.encode_query(params)}"
    end
  end

  defp maybe_put_step(params, nil), do: params
  defp maybe_put_step(params, step), do: Map.put(params, "step", step)

  defp validate_choice!(decision, choice) do
    option_slugs = Enum.map(decision["options"] || [], & &1["slug"])

    unless choice in option_slugs do
      Mix.raise(
        "Invalid choice '#{choice}' for decision '#{decision["key"]}'. " <>
          "Choose one of: #{Enum.join(option_slugs, ", ")}."
      )
    end
  end

  defp prompt_choice(%{"key" => key, "question" => question, "options" => options} = decision) do
    Mix.shell().info("")
    Mix.shell().info("#{IO.ANSI.blue()}* Decision:#{IO.ANSI.reset()} #{question}")

    if description = decision["description"] do
      Mix.shell().info("  #{description}")
    end

    Enum.with_index(options, 1)
    |> Enum.each(fn {option, index} ->
      Mix.shell().info("  #{index}. #{option["name"] || option["slug"]} (#{option["slug"]})")
    end)

    case options do
      [%{"slug" => slug} = option] ->
        label = option["name"] || slug

        if Mix.shell().yes?("Use #{label} for #{key}?") do
          slug
        else
          Mix.raise("Installation cancelled while selecting '#{key}'.")
        end

      _many ->
        ask_for_option(decision)
    end
  end

  defp ask_for_option(%{"key" => key, "options" => options} = decision) do
    answer =
      "Select #{key} by number or slug: "
      |> Mix.shell().prompt()
      |> String.trim()

    choice =
      case Integer.parse(answer) do
        {number, ""} -> options |> Enum.at(number - 1) |> then(&(&1 && &1["slug"]))
        _not_number -> answer
      end

    option_slugs = Enum.map(options, & &1["slug"])

    if choice in option_slugs do
      choice
    else
      Mix.shell().error("Choose one of: #{Enum.join(option_slugs, ", ")}.")
      ask_for_option(decision)
    end
  end
end
