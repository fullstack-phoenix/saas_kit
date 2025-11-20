defmodule SaasKit.MixProject do
  use Mix.Project

  @version "2.6.1"

  def project do
    [
      app: :saas_kit,
      version: @version,
      elixir: "~> 1.16",
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
      {:jason, ">= 1.2.0"},
      {:req, ">= 0.5.0"},
      {:mimic, "~> 1.7", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
