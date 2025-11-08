defmodule Vault.MixProject do
  use Mix.Project

  def project do
    [
      app: :vault,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp escript do
    [
      main_module: Vault.CLI,
      name: "vault"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Vault.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:owl, "~> 0.13"},
      {:ucwidth, "~> 0.2"},
      {:excoveralls, "~> 0.18", only: :test},
      {:yaml_elixir, "~> 2.9"}
    ]
  end
end
