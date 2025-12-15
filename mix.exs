defmodule Vault.MixProject do
  use Mix.Project

  @author "Eric Halvorsen"
  @version "0.1.0"
  @description """
    Vault is a tool for backing up and restoring macOS configurations and data.
  """

  def project do
    [
      app: :vault,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      test_coverage: [tool: ExCoveralls],
      test_ignore_filters: ["test/support/test_helpers.ex"],
      description: @description,
      authors: [@author]
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
      name: "bin/.vault-escript"
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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:memoize, "~> 1.4"},
      {:owl, "~> 0.13"},
      {:ucwidth, "~> 0.2"},
      {:yaml_elixir, "~> 2.9"}
    ]
  end
end
