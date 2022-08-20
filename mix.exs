defmodule SaasKit.MixProject do
  use Mix.Project

  @version "0.2.2"

  def project do
    [
      app: :saas_kit,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: "A package for running the code generators from Live SAAS kit.",
      homepage_url: "https://livesaaskit.com/",
      deps: deps(),
      package: package()
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      maintainers: ["Andreas Eriksson"],
      links: %{
        "Github" => "https://github.com/fullstack-phoenix/saas_kit"
      },
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, ">= 1.6.0 and < 1.8.0"},
      {:phoenix_live_view, ">= 0.17.0 and < 0.20.0"},
      {:phoenix_html, ">= 3.1.0 and < 4.0.0"},
      {:jason, ">= 1.2.0"},
      {:httpoison, ">= 1.8.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:scrivener_ecto, ">= 2.7.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
