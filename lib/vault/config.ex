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
        # Resolve step references for git and vault
        resolve_config_steps(config)

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

  # Resolves step names to full step definitions from the master steps list
  defp resolve_config_steps(config) do
    master_steps = config[:steps] || []
    step_map = Map.new(master_steps, fn step -> {step[:name], step} end)

    git_steps = resolve_steps(config.git[:steps] || [], step_map)
    vault_steps = resolve_steps(config.vault[:steps] || [], step_map)

    config
    |> Map.put(:git, Map.put(config.git, :steps, git_steps))
    |> Map.put(:vault, Map.put(config.vault, :steps, vault_steps))
  end

  # Resolve a list of step names to their full definitions
  defp resolve_steps(step_names, step_map) do
    Enum.map(step_names, fn step_name ->
      case Map.get(step_map, step_name) do
        nil ->
          Progress.puts([
            Progress.tag("✗ Warning: Step '#{step_name}' not found in :steps list", :yellow)
          ])

          %{name: step_name}

        step ->
          step
      end
    end)
  end
end
