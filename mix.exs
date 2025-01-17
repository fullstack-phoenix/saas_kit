defmodule SaasKit.MixProject do
  use Mix.Project

  @version "1.0.7"

  def project do
    [
      app: :saas_kit,
      version: @version,
      elixir: "~> 1.15",
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
      }
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
      {:phoenix, ">= 1.7.0 and < 1.8.0"},
      {:phoenix_live_view, ">= 0.18.0 and < 2.0.0"},
      {:phoenix_html, ">= 3.1.0 and < 5.0.0"},
      {:jason, ">= 1.2.0"},
      {:httpoison, ">= 1.8.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
