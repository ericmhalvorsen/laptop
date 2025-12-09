defmodule Vault.Commands.Restore do
  @moduledoc """
  Command to restore macOS configuration from the vault.

  This is the EXACT reverse of the backup/save command (vault part only, ignoring git).
  """

  alias Vault.Restore
  alias Vault.Config
  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    config = Config.load(opts)
    relative_root = config.defaults.relative_root || "~/"

    vault_path = FileUtils.expand_path(opts[:vault_path] || config.vault.dest)
    dest_path = FileUtils.expand_path(relative_root)

    Progress.puts([
      Progress.tag("\n📦 Vault Restore", :cyan),
      "\n\n",
      "Restoring from vault: ",
      Progress.tag(vault_path, :green),
      "\n",
      "Restoring to: ",
      Progress.tag(dest_path, :green),
      "\n"
    ])

    excludes = config.defaults.exclude_patterns

    # Restore vault steps in order
    config.vault.steps
    |> Enum.each(fn step ->
      step_config = step |> Map.new() |> Map.delete(:name)

      execute_step(
        step,
        Map.put(step_config, :source, Path.join(vault_path, step.name)),
        dest_path,
        Keyword.put(opts, :exclude, excludes)
      )
    end)

    Owl.Box.new([
      Progress.tag("✓ Restore Complete!", :green),
      "\n\n",
      "Restored from vault:\n",
      Progress.tag("  ✓ All configured steps", :green),
      "\n"
    ])
    |> Progress.puts()
  end

  defp execute_step(step, config, dest_root, opts) do
    source_path = FileUtils.expand_path(config.source)
    dest_path = FileUtils.expand_path(dest_root)
    label = Map.get(step, :label, step.name)

    # Skip if source doesn't exist in vault
    if !File.exists?(source_path) do
      Progress.puts([
        "\n",
        Progress.tag("→ Skipping #{label}...", :yellow),
        " (not found in vault)"
      ])
    else
      Progress.puts([
        "\n",
        Progress.tag("→ Restoring #{label}...", :cyan)
      ])

      result =
        case step.name do
          "brew" ->
            Restore.homebrew(Path.dirname(source_path), opts)

          _ ->
            Restore.restore(
              source_path,
              dest_path,
              config.contents || [],
              Keyword.put(opts, :label, label)
            )
        end

      # Wait for render to complete
      if Process.whereis(Owl.LiveScreen), do: Owl.LiveScreen.await_render()

      case result do
        {:ok, result} ->
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            Progress.tag("   #{result.stats.count} files transferred (", :blue),
            Progress.tag(["source ", FileUtils.format_size(result.stats.total_size)], :yellow),
            Progress.tag(") \n", :blue)
          ])

        {:error, reason} ->
          Progress.puts([
            "  ",
            Progress.tag("✗", :red),
            " Failed: #{reason}"
          ])
      end
    end
  end
end
