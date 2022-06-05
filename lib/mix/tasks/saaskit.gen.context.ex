defmodule Mix.Tasks.Saaskit.Gen.Context do
  @shortdoc "Generates a context with functions around an Ecto schema"

  use Mix.Task
  import SaasKit.MixUtils

  @name "saaskit.gen.context"

  @doc false
  def run(args) do
    refute_umbrella(@name)

    Application.ensure_all_started(:hackney)

    args
    |> account_scoped_question()
    |> build_resource_from_args(__MODULE__)
    |> load_templates(@name)
    |> follow_instructions()
  end

  def raise_with_help(msg) do
    Mix.raise """
    #{msg}

    mix saaskit.gen.html, saaskit.gen.json, saaskit.gen.live, and saaskit.gen.context
    expect a context module name, followed by singular and plural names
    of the generated resource, ending with any number of attributes.
    For example:

        mix saaskit.gen.html Accounts User users name:string
        mix saaskit.gen.json Accounts User users name:string
        mix saaskit.gen.live Accounts User users name:string
        mix saaskit.gen.context Accounts User users name:string

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Payments.User).
    """
  end
end
