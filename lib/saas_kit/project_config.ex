defmodule SaasKit.ProjectConfig do
  @moduledoc """
  Manages local SaaS Kit project state.
  """

  @filename ".saaskit.yml"
  @initial_content "initial_install: false\n"

  @doc """
  Creates the initial SaaS Kit state file unless one already exists.
  """
  def ensure_initial_file do
    if File.exists?(@filename) do
      :exists
    else
      File.write!(@filename, @initial_content)
      Mix.shell().info("#{IO.ANSI.green()}* Created file:#{IO.ANSI.reset()} #{@filename}")
      :created
    end
  end
end
