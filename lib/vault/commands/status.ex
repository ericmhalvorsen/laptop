defmodule Vault.Commands.Status do
  @moduledoc """
  Command to show the status of the vault.
  """

  alias Vault.UI.Progress

  def run(_args, opts) do
    vault_path = get_vault_path(opts)

    Progress.puts([
      Progress.tag("\n📊 Vault Status", :cyan),
      "\n\n",
      "Vault path: ",
      Progress.tag(vault_path, :yellow),
      "\n"
    ])

    if File.exists?(vault_path) do
      show_vault_status(vault_path)
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

  defp show_vault_status(vault_path) do
    Owl.Box.new([
      Progress.tag("✓ Vault exists", :green),
      "\n\n",
      "Location: #{vault_path}\n",
      "\nThis doesn't do anything right now"
    ])
    |> Progress.puts()
  end

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Path.join(System.user_home!(), "VaultBackup")
  end
end
