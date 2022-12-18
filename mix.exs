defmodule RestApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :rest_api,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RestApi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.3"},
      {:mongodb_driver, "~> 0.8"},
      {:dotenv, "~> 3.0.0", only: [:dev, :test]}
    ]
  end
end
