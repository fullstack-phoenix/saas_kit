defmodule Mix.Tasks.Saaskit.Setup do
  @moduledoc """
  Installs the initial SaaS Kit feature and creates local project state.

  Options:
    --agent-skills     Install agent guidance without prompting.
    --no-agent-skills  Skip the optional agent guidance prompt.
  """
  use Mix.Task

  alias SaasKit.AgentSkills
  alias SaasKit.ProjectConfig

  @impl Mix.Task
  def run(args) do
    {opts, _args, _invalid} =
      OptionParser.parse(args, switches: [agent_skills: :boolean])

    if !Application.get_env(:saas_kit, :boilerplate_token) do
      Mix.raise("""
      It seems that you have not yet added the api_key to the config.
      You can cet the api key from your boilerplate page at https://livesaaskit.com/
      Install it like:

          config :saas_kit,
            boilerplate_token: "secretapikey"

      """)
    end

    case install_setup() do
      :ok ->
        ProjectConfig.ensure_initial_file()
        maybe_install_agent_skills(opts)

      {:error, _step} ->
        System.halt(1)
    end
  end

  defp install_setup do
    Application.ensure_all_started([:req, :hex])
    token = Application.get_env(:saas_kit, :boilerplate_token)

    Mix.shell().info("#{IO.ANSI.blue()}* Performing setup:#{IO.ANSI.reset()}")
    base_url = Application.get_env(:saas_kit, :base_url) || "https://livesaaskit.com"
    url = "#{base_url}/api/boilerplate/install/#{token}/setup"

    case Req.get(url) do
      {:ok, %{body: %{"instructions" => instructions}}} ->
        SaasKit.follow_instructions(instructions, "initial_setup", token: token)

      _ ->
        Mix.shell().error("#{IO.ANSI.red()}* Failed to run setup#{IO.ANSI.reset()}")
        {:error, :request_failed}
    end
  end

  defp maybe_install_agent_skills(opts) do
    case Keyword.fetch(opts, :agent_skills) do
      {:ok, true} -> AgentSkills.install()
      {:ok, false} -> :skipped
      :error -> AgentSkills.offer_install()
    end
  end
end
