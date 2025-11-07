defmodule Vault.Commands.Save do
  @moduledoc """
  Command to backup current macOS configuration to the vault.
  """

  alias Vault.Backup.Dotfiles
  alias Vault.Backup.Config
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    vault_path = get_vault_path(opts)
    home_dir = System.user_home!()
    repo_dir = File.cwd!()

    Owl.IO.puts([
      Owl.Data.tag("\n📦 Vault Save", :cyan),
      "\n\n",
      "Backing up to: ",
      Owl.Data.tag(vault_path, :yellow),
      "\n"
    ])

    # Backup dotfiles to repo
    backup_dotfiles(home_dir, repo_dir)

    # Backup local-bin scripts to repo
    backup_local_bin(home_dir, repo_dir)

    # Backup configs to repo
    backup_configs(home_dir, repo_dir)

    # Show success summary
    Owl.Box.new([
      Owl.Data.tag("✓ Backup Complete!", :green),
      "\n\n",
      "Repository backups (committed to git):\n",
      Owl.Data.tag("  ✓ Dotfiles", :green),
      "\n",
      Owl.Data.tag("  ✓ Local scripts", :green),
      "\n",
      Owl.Data.tag("  ✓ Configuration", :green),
      "\n\n",
      Owl.Data.tag("Coming soon:", :yellow),
      " Homebrew, Browser, Home dirs, etc.\n"
    ])
    |> Owl.IO.puts()
  end

  defp backup_configs(home_dir, repo_dir) do
    dest = Path.join(repo_dir, "config")

    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up configuration...", :cyan)])

    case Config.backup(home_dir, dest) do
      {:ok, result} ->
        if result.configs_backed_up > 0 do
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("✓", :green),
            " Backed up ",
            Owl.Data.tag("#{result.configs_backed_up}", :cyan),
            " config(s) (",
            Owl.Data.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])

          if not Enum.empty?(result.backed_up_configs) do
            Owl.IO.puts([
              "    Apps: ",
              Enum.join(result.backed_up_configs, ", ")
            ])
          end
        else
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("ℹ", :yellow),
            " No supported configs found"
          ])
        end

      {:error, reason} ->
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_dotfiles(home_dir, repo_dir) do
    dest = Path.join(repo_dir, "dotfiles")

    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up dotfiles...", :cyan)])

    case Dotfiles.backup(home_dir, dest) do
      {:ok, result} ->
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("✓", :green),
          " Copied ",
          Owl.Data.tag("#{result.files_copied}", :cyan),
          " dotfiles (",
          Owl.Data.tag(FileUtils.format_size(result.total_size), :yellow),
          ")"
        ])

        if result.files_copied > 0 do
          Owl.IO.puts([
            "    Files: ",
            Enum.join(result.backed_up_files, ", ")
          ])
        end

      {:error, reason} ->
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_local_bin(home_dir, repo_dir) do
    dest = Path.join(repo_dir, "local-bin")

    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up local scripts...", :cyan)])

    case Dotfiles.backup_local_bin(home_dir, dest) do
      {:ok, result} ->
        if result.files_copied > 0 do
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("✓", :green),
            " Copied ",
            Owl.Data.tag("#{result.files_copied}", :cyan),
            " scripts (",
            Owl.Data.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])

          Owl.IO.puts([
            "    Scripts: ",
            Enum.join(result.backed_up_files, ", ")
          ])
        else
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("ℹ", :yellow),
            " No scripts found in ~/.local/bin"
          ])
        end

      {:error, reason} ->
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Path.join(System.user_home!(), "VaultBackup")
  end
end
