defmodule Vault.Commands.Status do
  @moduledoc """
  Command to show the status of the vault.
  """

  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    vault_target = get_vault_target(opts)

    Progress.puts([
      Progress.tag("\n📊 Vault Status", :cyan),
      "\n\n",
      "Vault target: ",
      Progress.tag(vault_target, :yellow),
      "\n"
    ])

    if FileUtils.remote_target?(vault_target) do
      show_remote_vault_status(vault_target)
    else
      if File.exists?(vault_target) do
        show_vault_status(vault_target)
      else
        Progress.puts([
          "\n",
          Progress.tag("⚠ Vault not found", :yellow),
          "\n\n",
          "Run ",
          Progress.tag("vault save", :cyan),
          " to create your first backup.\n"
        ])
      end
    end
  end

  defp show_vault_status(vault_target) do
    Owl.Box.new([
      Progress.tag("✓ Vault exists", :green),
      "\n\n",
      "Location: #{vault_target}\n",
      "\nThis doesn't do anything right now"
    ])
    |> Progress.puts()
  end

  defp show_remote_vault_status(vault_target) do
    Owl.Box.new([
      Progress.tag("Remote vault target", :cyan),
      "\n\n",
      "Location: #{vault_target}\n",
      "\nCannot verify remote vault existence from CLI.\n",
      "Use ",
      Progress.tag("vault save", :cyan),
      " to sync to this target."
    ])
    |> Progress.puts()
  end

  defp get_vault_target(opts) do
    opts[:vault_target] || get_default_vault_target()
  end

  defp get_default_vault_target do
    Path.join(System.user_home!(), "VaultBackup")
  end
end
