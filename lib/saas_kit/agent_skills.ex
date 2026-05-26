defmodule SaasKit.AgentSkills do
  @moduledoc """
  Installs optional SaaS Kit guidance for common coding assistants.
  """

  @guidance """
  # SaaS Kit

  This Phoenix application uses the `saas_kit` Mix tasks to install starter-kit features.

  ## Workflow

  1. Run `mix saaskit.status --json` before making feature-installation changes.
  2. Inspect available features with `mix saaskit.feature.list --json`.
  3. Inspect one feature with `mix saaskit.feature.show <slug> --json`.
  4. Install only after confirming the desired feature and dependencies:
     `mix saaskit.feature.install <slug>`.
  5. When a feature requires a decision, either answer the prompt or run:
     `mix saaskit.feature.install <slug> --decision <key>=<option_slug>`.
  6. Run `mix format` and `mix test` after installation.

  Treat `.saaskit.yml` as project-local SaaS Kit state. Do not edit generated
  application files to fix a reusable feature bug; fix the owning feature
  template or installer when working in the Live SaaS Kit workspace.
  """

  @skill """
  ---
  name: saaskit
  description: Install and maintain SaaS Kit features in this Phoenix application.
  ---

  #{@guidance}
  """

  @cursor """
  ---
  description: Use SaaS Kit installer tasks safely in this Phoenix application
  alwaysApply: true
  ---

  #{@guidance}
  """

  @copilot """
  ---
  applyTo: "**"
  ---

  #{@guidance}
  """

  @files [
    {".claude/skills/saaskit/SKILL.md", @skill},
    {".codex/skills/saaskit/SKILL.md", @skill},
    {".cursor/rules/saaskit.mdc", @cursor},
    {".github/instructions/saaskit.instructions.md", @copilot}
  ]

  @doc """
  Offers installation of guidance for Claude Code, Codex, Cursor, and GitHub Copilot.
  """
  def offer_install do
    if Mix.shell().yes?(
         "Install SaaS Kit agent guidance for Claude Code, Codex, Cursor, and GitHub Copilot?"
       ) do
      install()
    else
      :skipped
    end
  end

  @doc """
  Installs guidance files for the supported assistants.
  """
  def install do
    Enum.each(@files, fn {filename, contents} ->
      Mix.Generator.create_file(filename, contents)
    end)

    :ok
  end
end
