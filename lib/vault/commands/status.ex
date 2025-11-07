defmodule Vault.Commands.Status do
  @moduledoc """
  Command to show the status of the vault.
  """

  def run(_args, opts) do
    vault_path = get_vault_path(opts)

    Owl.IO.puts([
      Owl.Data.tag("\n📊 Vault Status", :cyan),
      "\n\n",
      "Vault path: ",
      Owl.Data.tag(vault_path, :yellow),
      "\n"
    ])

    if File.exists?(vault_path) do
      show_vault_status(vault_path)
    else
      Owl.IO.puts([
        "\n",
        Owl.Data.tag("⚠ Vault not found", :yellow),
        "\n\n",
        "Run ",
        Owl.Data.tag("vault save", :cyan),
        " to create your first backup.\n"
      ])
    end
  end

  defp show_vault_status(vault_path) do
    # TODO: Implement actual status checking
    Owl.Box.new([
      Owl.Data.tag("✓ Vault exists", :green),
      "\n\n",
      "Location: #{vault_path}\n",
      "\nStatus checking coming soon!"
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
