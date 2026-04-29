defmodule Mix.Tasks.Saaskit.Help do
  @moduledoc """
  Displays getting-started information and all available SaaS Kit mix tasks.

  Usage:
    mix saaskit.help
    mix saaskit.help --json    # emit the task catalog as JSON

  By default this runs fully offline — it reports whether `boilerplate_token`
  is set and points humans or agents at `mix saaskit.status` for a deeper,
  API-backed state check.

  JSON shape:

      {
        "schema_version": 1,
        "ok": true,
        "configured": true,
        "tasks": [
          {
            "command": "mix saaskit.status",
            "description": "...",
            "examples": ["mix saaskit.status", "mix saaskit.status --json"]
          }
        ],
        "next_command": "mix saaskit.status"
      }
  """
  use Mix.Task

  alias SaasKit.API
  alias SaasKit.Task.Helpers

  @b IO.ANSI.blue()
  @g IO.ANSI.green()
  @y IO.ANSI.yellow()
  @r IO.ANSI.reset()

  @tasks [
    %{
      command: "mix saaskit.help",
      description: "Show this help text. Use --json to get the task catalog.",
      examples: ["mix saaskit.help", "mix saaskit.help --json"]
    },
    %{
      command: "mix saaskit.status",
      description:
        "Report current state (configured?, app name, installed features, next command).",
      examples: ["mix saaskit.status", "mix saaskit.status --json"]
    },
    %{
      command: "mix saaskit.setup",
      description: "Run the initial project setup (installs the initial_setup feature).",
      examples: ["mix saaskit.setup"]
    },
    %{
      command: "mix saaskit.feature.install <feature>",
      description: "Install a single feature by slug.",
      examples: [
        "mix saaskit.feature.install auth",
        "mix saaskit.feature.install billing --token <token>",
        "mix saaskit.feature.install auth --step <uuid>  # resume from step"
      ]
    },
    %{
      command: "mix saaskit.plan.install <plan_id>",
      description: "Install every feature in a saved plan, in order.",
      examples: ["mix saaskit.plan.install plan_abc123"]
    },
    %{
      command: "mix saaskit.agent.feature.list",
      description:
        "List all available features with installation status. Supports --filter and --json.",
      examples: [
        "mix saaskit.agent.feature.list",
        "mix saaskit.agent.feature.list --filter \"auth,billing\"",
        "mix saaskit.agent.feature.list --json"
      ]
    },
    %{
      command: "mix saaskit.agent.feature.show <slug>",
      description: "Show full detail for a single feature.",
      examples: [
        "mix saaskit.agent.feature.show auth",
        "mix saaskit.agent.feature.show billing --json"
      ]
    }
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = Helpers.parse_opts(args)
    Helpers.enter_json_mode(opts)

    configured? = !is_nil(API.token())

    payload = %{
      configured: configured?,
      tasks: @tasks,
      next_command: static_next_command(configured?)
    }

    Helpers.emit(payload, opts, &print_human/1)
  end

  defp static_next_command(false), do: "mix saaskit.status"
  defp static_next_command(true), do: "mix saaskit.status"

  defp print_human(%{configured: configured?, tasks: tasks}) do
    info("")
    info("#{@b}SaaS Kit#{@r} — Phoenix SaaS boilerplate installer")
    info("https://livesaaskit.com")
    info("")

    if configured? do
      info("#{@g}✓ Configured#{@r}  boilerplate_token is set in config")
      info("           Run #{@g}mix saaskit.status#{@r} for a live state snapshot.")
    else
      info("#{@y}! Not configured#{@r}  Add to config/config.exs:")
      info("")
      info("    config :saas_kit,")
      info("      boilerplate_token: \"your_token\"")
      info("")
      info("  Get your token at https://livesaaskit.com/")
    end

    info("")
    info("#{@b}Available tasks#{@r}")
    info("")

    Enum.each(tasks, &print_task/1)

    info("#{@b}Typical workflow#{@r}")
    info("")
    info("  1. mix phx.new my_app && cd my_app")
    info("  2. Add #{@g}{:saas_kit, \"~> 2.6\", only: :dev, runtime: false}#{@r} to mix.exs deps")
    info("  3. Put your token in config/config.exs (see above)")
    info("  4. mix saaskit.status          # sanity-check config + API")
    info("  5. mix saaskit.setup           # run initial setup")
    info("  6. mix saaskit.agent.feature.list")
    info("  7. mix saaskit.feature.install <slug>")
    info("")
    info("#{@b}Tip for AI agents#{@r}  Most read-only tasks support #{@g}--json#{@r}. Start with:")
    info("  mix saaskit.status --json")
    info("")
  end

  defp print_task(%{command: command, description: description, examples: examples}) do
    info("  #{@g}#{command}#{@r}")
    info("    #{description}")

    unless examples == [] do
      info("    #{@y}Examples:#{@r}")
      Enum.each(examples, fn ex -> info("      #{ex}") end)
    end

    info("")
  end

  defp info(msg), do: Mix.shell().info(msg)
end
