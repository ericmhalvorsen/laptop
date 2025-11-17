defmodule Vault.MixProject do
  use Mix.Project

  @author "Eric M. Halvorsen"
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
      releases: releases(),
      test_coverage: [tool: ExCoveralls],
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
      {:yaml_elixir, "~> 2.9"},
      {:burrito, "~> 1.0"}
    ]
  end

  defp releases do
    [
      vault: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_intel: [os: :darwin, cpu: :x86_64],
            macos_arm: [os: :darwin, cpu: :aarch64],
            linux: [os: :linux, cpu: :x86_64]
          ],
          extra_steps: [
            # Ensure executable permissions
            {:chmod, "+x", "vault"}
          ]
        ]
      ]
    ]
  end
end
