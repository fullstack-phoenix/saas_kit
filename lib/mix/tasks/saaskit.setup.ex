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
      Mix.raise("""
      It seems that you have not yet added the api_key to the config.
      You can cet the api key from your sites page at https://livesaaskit.com/
      Install it like:

          config :saas_kit,
            api_key: "secretapikey"

      """)
    end

    options =
      SetupQuestions.get_questions()
      |> Enum.reduce(%{}, fn option, memo ->
        key = Map.keys(option) |> List.first()
        question = Map.get(option, key)
        Map.put(memo, key, ask_question(question))
      end)

    "setup"
    |> Kit.get_instructions(options)
    |> follow_instructions()

    users_auth = ask_about_users_auth(options)
    options = Map.put(options, "users_auth", users_auth)

    Mix.Shell.Quiet.cmd("mkdir priv/templates")

    Enum.each(~w(context embedded html json live notifier schema), fn type ->
      Mix.Shell.Quiet.cmd("cp -r deps/phoenix/priv/templates/phx.gen.#{type} priv/templates")
    end)

    "complete-setup"
    |> Kit.get_instructions(options)
    |> follow_instructions()

    app_name = Mix.Project.config()[:app]

    if options["uuid_for_ids"] == false do
      SaasKit.RemoveBinaryId.run(app_name)
    end

    :ok
  end

  defp ask_question(question) do
    Mix.shell().yes?(
      """
      Install #{IO.ANSI.green()}#{question}#{IO.ANSI.reset()}?
      """
      |> String.trim_trailing()
    )
  end

  defp ask_about_users_auth(%{"uuid_for_ids" => _binary_id}) do
    if Mix.shell().yes?(
         """
         A lot of features expects that there is a User schema and users table.
         And the same goes for user authentication.

         Generate users and auth with #{IO.ANSI.green()}phx.gen.auth#{IO.ANSI.reset()}?
         """
         |> String.trim_trailing()
       ) do
      # base_args = ~w(Users User users --live)
      # args = if binary_id, do: base_args ++ ["--binary-id"], else: base_args
      args = ~w(Users User users --live --binary-id)

      Mix.Task.run("phx.gen.auth", args)

      true
    else
      false
    end
  end
end
