defmodule Vault.Config do
  @moduledoc """
  Loads and provides access to vault.yaml configuration.
  """

  alias Vault.UI.Progress

  @doc """
  Loads the vault configuration from vault.yaml.

  ## Options

    * `:config_path` - Path to the config file (default: config/vault.yaml)
  """
  def load(opts \\ []) do
    repo_config = Path.expand("config", File.cwd!())
    config_path = opts[:config_path] || Path.join(repo_config, "vault.yaml")

    case YamlElixir.read_from_file(config_path, atoms: true) do
      {:ok, config} ->
        config

      {:error, reason} ->
        Progress.puts([
          Progress.tag("✗ Failed to read #{config_path}: ", :red),
          inspect(reason)
        ])

        System.halt(1)
    end
  end

  @doc """
  Returns the default exclude patterns from the configuration.
  """
  def default_excludes(opts \\ []) do
    config = load(opts)
    config.defaults.exclude_patterns || []
  end
end
