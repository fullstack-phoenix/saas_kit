defmodule Mix.Tasks.Saaskit.Gen.Kit do
  @shortdoc "Generates coded based on a token provided as argument"

  use Mix.Task
  import SaasKit.MixUtils
  alias SaasKit.ApiAdapter.Kit

  @name "saaskit.gen.kit"

  @doc false
  def run(args) do
    refute_umbrella(@name)

    Application.ensure_all_started(:hackney)

    token = case args do
      [""|_] -> raise_with_help()
      ["" <> token|_] -> token
      _ -> raise_with_help()
    end

    token
    |> Kit.get_instructions()
    |> follow_instructions()
  end

  def raise_with_help do
    Mix.raise """
    There was an issue parsing the arguments. Use a pattern like:

        mix saaskit.gen.kit zxy123asdf

    """
  end
end
