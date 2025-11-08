defmodule Vault.Commands.Save do
  @moduledoc """
  Command to backup current macOS configuration to the vault.
  """

  alias Vault.Backup.AppSupport
  alias Vault.Backup.Dotfiles
  alias Vault.Backup.Fonts
  alias Vault.Backup.Homebrew
  alias Vault.Backup.HomeDirs
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    vault_path = get_vault_path(opts)
    home_dir = System.user_home!()

    Owl.IO.puts([
      Owl.Data.tag("\n📦 Vault Save", :cyan),
      "\n\n",
      "Backing up to: ",
      Owl.Data.tag(vault_path, :yellow),
      "\n"
    ])

    # All backups go to vault directory
    backup_dotfiles(home_dir, vault_path)
    backup_local_bin(home_dir, vault_path)
    backup_homebrew(vault_path)
    backup_fonts(home_dir, vault_path)
    backup_app_support(home_dir, vault_path)
    backup_home_directories(home_dir, vault_path)

    # Show success summary
    Owl.Box.new([
      Owl.Data.tag("✓ Backup Complete!", :green),
      "\n\n",
      "Saved to vault:\n",
      Owl.Data.tag("  ✓ Dotfiles (.config included)", :green),
      "\n",
      Owl.Data.tag("  ✓ Local scripts", :green),
      "\n",
      Owl.Data.tag("  ✓ Homebrew", :green),
      "\n",
      Owl.Data.tag("  ✓ Fonts", :green),
      "\n",
      Owl.Data.tag("  ✓ Application Support", :green),
      "\n",
      Owl.Data.tag("  ✓ Home directories", :green),
      "\n\n",
      Owl.Data.tag("Coming soon:", :yellow),
      " Browser, Obsidian\n"
    ])
    |> Owl.IO.puts()
  end

  defp backup_homebrew(vault_path) do
    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up Homebrew packages...", :cyan)])

    case Homebrew.backup(vault_path) do
      {:ok, result} ->
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("✓", :green),
          " Brewfile created"
        ])

        Owl.IO.puts([
          "    ",
          Owl.Data.tag("#{result.formulas}", :cyan),
          " formulas, ",
          Owl.Data.tag("#{result.casks}", :cyan),
          " casks, ",
          Owl.Data.tag("#{result.taps}", :cyan),
          " taps"
        ])

      {:error, reason} ->
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_dotfiles(home_dir, vault_path) do
    dest = Path.join(vault_path, "dotfiles")

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

  defp backup_local_bin(home_dir, vault_path) do
    dest = Path.join(vault_path, "local-bin")

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

  defp backup_fonts(home_dir, vault_path) do
    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up fonts...", :cyan)])

    case Fonts.backup(home_dir, vault_path) do
      {:ok, result} ->
        if result.fonts_copied > 0 do
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("✓", :green),
            " Copied ",
            Owl.Data.tag("#{result.fonts_copied}", :cyan),
            " fonts (",
            Owl.Data.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])
        else
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("ℹ", :yellow),
            " No custom fonts found in ~/Library/Fonts"
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

  defp backup_app_support(home_dir, vault_path) do
    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up Application Support...", :cyan)])

    case AppSupport.backup(home_dir, vault_path) do
      {:ok, result} ->
        if length(result.backed_up) > 0 do
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("✓", :green),
            " Backed up ",
            Owl.Data.tag("#{length(result.backed_up)}", :cyan),
            " apps (",
            Owl.Data.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])

          Owl.IO.puts([
            "    Apps: ",
            Enum.join(result.backed_up, ", ")
          ])
        else
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("ℹ", :yellow),
            " No application data found"
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

  defp backup_home_directories(home_dir, vault_path) do
    Owl.IO.puts(["\n", Owl.Data.tag("→ Backing up home directories...", :cyan)])

    # Auto-discover all public (non-dot) directories
    case HomeDirs.backup(home_dir, vault_path) do
      {:ok, result} ->
        if length(result.backed_up) > 0 do
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("✓", :green),
            " Backed up ",
            Owl.Data.tag("#{length(result.backed_up)}", :cyan),
            " directories"
          ])

          Owl.IO.puts([
            "    Directories: ",
            Enum.join(result.backed_up, ", ")
          ])
        end

        if length(result.skipped) > 0 do
          Owl.IO.puts([
            "  ",
            Owl.Data.tag("ℹ", :yellow),
            " Skipped ",
            "#{length(result.skipped)} (not found): ",
            Enum.join(result.skipped, ", ")
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
