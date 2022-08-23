defmodule Mix.Tasks.Saaskit.Gen.Feature do
  @shortdoc "Generates a feature"

  use Mix.Task
  import SaasKit.MixUtils
  alias SaasKit.ApiAdapter.Feature

  @name "saaskit.gen.feature"

  @doc false
  def run(args) do
    refute_umbrella(@name)

    Application.ensure_all_started(:hackney)

    possible_features = Feature.get_features()

    validate_args!(args, possible_features)
    [feature|_] = args

    %{
      app_name: app_name,
      app_name_lower: app_name_lower,
      binary_id: binary_id
    } =
      ["Examples", "Example", "examples", "name"]
      |> build_resource_from_args(__MODULE__)

    %{
      id: feature,
      data: %{
        app_name: app_name,
        app_name_lower: app_name_lower,
        binary_id: binary_id
      }
    }
    |> Feature.get_feature()
    # |> gather_and_ask_questions()
    |> follow_instructions()
  end

  defp validate_args!([] = _args, features), do: raise_with_help(features)
  defp validate_args!([arg|_] = _args, features) do
    features
    |> Enum.map(&Map.get(&1, "slug"))
    |> Enum.member?(arg)
    |> case do
      true -> nil
      false -> raise_with_help(features)
    end
  end

  def raise_with_help(features) do
    Mix.raise """
    There was an issue parsing the arguments. Use a pattern like:

        mix saaskit.gen.feature waffle

    Possible features are:

    #{for %{"slug" => slug} <- features, do: "    mix saaskit.gen.feature #{slug}\n"}
    """
  end
end
