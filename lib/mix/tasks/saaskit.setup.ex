defmodule Mix.Tasks.Saaskit.Setup do
  @shortdoc "Generates coded based on a token provided as argument"

  use Mix.Task
  import SaasKit.MixUtils
  alias SaasKit.ApiAdapter.SetupQuestions
  alias SaasKit.ApiAdapter.Kit

  @name "saaskit.setup"

  @doc false
  def run(_args) do
    refute_umbrella(@name)

    Application.ensure_all_started(:hackney)

    if !Application.get_env(:saas_kit, :api_key) do
      Mix.raise """
      It seems that you have not yet added the api_key to the config.
      You can cet the api key from your sites page at https://livesaaskit.com/
      Install it like:

          config :saas_kit,
            api_key: "secretapikey"

      """
    end

    options =
      SetupQuestions.get_questions()
      |> Enum.reduce(%{}, fn option, memo ->
        key = Map.keys(option) |> List.first()
        question = Map.get(option, key)
        Map.put(memo, key, ask_question(question))
      end)

    # IO.inspect options
    # %{"uuid_for_ids" => true}

    "setup"
    |> Kit.get_instructions(options)
    |> follow_instructions()

    ask_about_users_auth(options)

    "complete-setup"
    |> Kit.get_instructions(options)
    |> follow_instructions()

    :ok
  end

  defp ask_question(question) do
    Mix.shell().yes?(
      """
      Install #{IO.ANSI.green}#{question}#{IO.ANSI.reset}?
      """ |> String.trim_trailing())
  end

  defp ask_about_users_auth(%{"uuid_for_ids" => binary_id}) do
    if Mix.shell().yes?(
      """
      A lot of features expects that there is a User schema and users table.
      And the same goes for user authentication.

      Generate users and auth with #{IO.ANSI.green}phx.gen.auth#{IO.ANSI.reset}?
      """ |> String.trim_trailing()) do

      base_args = ~w(Users User users --live)
      args = if binary_id, do: base_args ++ ["--binary-id"], else: base_args

      Mix.Task.run("phx.gen.auth", args)
    end
  end
end
