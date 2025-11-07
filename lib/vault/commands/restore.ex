defmodule Vault.Commands.Restore do
  @moduledoc """
  Command to restore macOS configuration from the vault.
  """

  def run(_args, opts) do
    vault_path = get_vault_path(opts)

    Owl.IO.puts([
      Owl.Data.tag("\n📂 Vault Restore", :cyan),
      "\n\n",
      "Vault path: ",
      Owl.Data.tag(vault_path, :yellow),
      "\n"
    ])

    # TODO: Implement actual restore logic
    Owl.Box.new([
      Owl.Data.tag("🚧 Coming Soon!", :yellow),
      "\n\n",
      "The restore command will restore:\n",
      "  • Dotfiles\n",
      "  • Homebrew packages\n",
      "  • Application configurations\n",
      "  • Browser data\n",
      "  • Obsidian vaults\n",
      "  • Home directories\n"
    ])
    |> Owl.IO.puts()
  end

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Path.join(System.user_home!(), "VaultBackup")
  end
end
