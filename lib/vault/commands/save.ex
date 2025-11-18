defmodule Vault.Commands.Save do
  @moduledoc """
  Command to backup current macOS configuration to the vault.
  """

  alias Vault.Backup.AppSupport
  alias Vault.Backup.Dotfiles
  alias Vault.Backup.Fonts
  alias Vault.Backup.Homebrew
  alias Vault.Backup.HomeDirs
  alias Vault.Backup.Preferences
  alias Vault.Backup.Sensitive
  alias Vault.Sync
  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    vault_path = get_vault_path(opts)
    home_dir = get_home_dir(opts)

    Progress.puts([
      Progress.tag("\n📦 Vault Save", :cyan),
      "\n\n",
      "Backing up to: ",
      Progress.tag(vault_path, :yellow),
      "\n"
    ])

    backup_dotfiles(home_dir, vault_path)
    backup_local_bin(home_dir, vault_path)

    unless opts[:skip_homebrew] do
      backup_homebrew(vault_path)
    end

    backup_fonts(home_dir, vault_path)
    backup_app_support(home_dir, vault_path)
    backup_preferences(home_dir, vault_path)
    backup_sensitive(home_dir, vault_path)
    backup_obsidian(home_dir, vault_path)
    backup_home_directories(home_dir, vault_path)

    Owl.Box.new([
      Progress.tag("✓ Backup Complete!", :green),
      "\n\n",
      "Saved to vault:\n",
      Progress.tag("  ✓ Dotfiles (.config, .zsh_history included)", :green),
      "\n",
      Progress.tag("  ✓ Local scripts", :green),
      "\n",
      Progress.tag("  ✓ mise.toml", :green),
      "\n",
      Progress.tag("  ✓ Homebrew", :green),
      "\n",
      Progress.tag("  ✓ Fonts", :green),
      "\n",
      Progress.tag("  ✓ Application Support", :green),
      "\n",
      Progress.tag("  ✓ Preferences", :green),
      "\n",
      Progress.tag("  ✓ Sensitive (SSH, GPG, AWS, passwords)", :green),
      "\n",
      Progress.tag("  ✓ Obsidian vaults", :green),
      "\n",
      Progress.tag("  ✓ Home directories", :green),
      "\n"
    ])
    |> Progress.puts()
  end

  defp backup_homebrew(vault_path) do
    Progress.puts(["\n", Progress.tag("→ Backing up Homebrew packages...", :cyan)])

    case Homebrew.backup(vault_path) do
      {:ok, result} ->
        Progress.puts([
          "  ",
          Progress.tag("✓", :green),
          " Brewfile created"
        ])

        Progress.puts([
          "    ",
          Progress.tag("#{result.formulas}", :cyan),
          " formulas, ",
          Progress.tag("#{result.casks}", :cyan),
          " casks, ",
          Progress.tag("#{result.taps}", :cyan),
          " taps"
        ])

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_dotfiles(home_dir, vault_path) do
    dest = Path.join(vault_path, "dotfiles")

    Progress.puts(["\n", Progress.tag("→ Backing up dotfiles...", :cyan)])

    case Dotfiles.backup(home_dir, dest) do
      {:ok, result} ->
        Progress.puts([
          "  ",
          Progress.tag("✓", :green),
          " Copied ",
          Progress.tag("#{result.files_copied}", :cyan),
          " dotfiles (",
          Progress.tag(FileUtils.format_size(result.total_size), :yellow),
          ")"
        ])

        if result.files_copied > 0 do
          Progress.puts([
            "    Files: ",
            Enum.join(result.backed_up_files, ", ")
          ])
        end

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_local_bin(home_dir, vault_path) do
    dest = Path.join(vault_path, "local-bin")

    Progress.puts(["\n", Progress.tag("→ Backing up local scripts...", :cyan)])

    case Dotfiles.backup_local_bin(home_dir, dest) do
      {:ok, result} ->
        if result.files_copied > 0 do
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            " Copied ",
            Progress.tag("#{result.files_copied}", :cyan),
            " scripts (",
            Progress.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])

          Progress.puts([
            "    Scripts: ",
            Enum.join(result.backed_up_files, ", ")
          ])
        else
          Progress.puts([
            "  ",
            Progress.tag("ℹ", :yellow),
            " No scripts found in ~/.local/bin"
          ])
        end

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_fonts(home_dir, vault_path) do
    Progress.puts(["\n", Progress.tag("→ Backing up fonts...", :cyan)])

    case Fonts.backup(home_dir, vault_path) do
      {:ok, result} ->
        if result.fonts_copied > 0 do
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            " Copied ",
            Progress.tag("#{result.fonts_copied}", :cyan),
            " fonts (",
            Progress.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])
        else
          Progress.puts([
            "  ",
            Progress.tag("ℹ", :yellow),
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
    Progress.puts(["\n", Progress.tag("→ Backing up Application Support...", :cyan)])

    case AppSupport.backup(home_dir, vault_path) do
      {:ok, result} ->
        if length(result.backed_up) > 0 do
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            " Backed up ",
            Progress.tag("#{length(result.backed_up)}", :cyan),
            " apps (",
            Progress.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])

          Progress.puts([
            "    Apps: ",
            Enum.join(result.backed_up, ", ")
          ])
        else
          Progress.puts([
            "  ",
            Progress.tag("ℹ", :yellow),
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
    Progress.puts(["\n", Progress.tag("→ Backing up home directories...", :cyan)])

    # Auto-discover all public (non-dot) directories
    case HomeDirs.backup(home_dir, vault_path) do
      {:ok, result} ->
        if length(result.backed_up) > 0 do
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            " Backed up ",
            Progress.tag("#{length(result.backed_up)}", :cyan),
            " directories"
          ])

          Progress.puts([
            "    Directories: ",
            Enum.join(result.backed_up, ", ")
          ])
        end

        if length(result.skipped) > 0 do
          Progress.puts([
            "  ",
            Progress.tag("ℹ", :yellow),
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

  defp backup_preferences(home_dir, vault_path) do
    Progress.puts(["\n", Progress.tag("→ Backing up Library/Preferences...", :cyan)])

    case Preferences.backup(home_dir, vault_path) do
      {:ok, result} ->
        if result.files_copied > 0 do
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            " Backed up ",
            Progress.tag("#{result.files_copied}", :cyan),
            " preference files (",
            Progress.tag(FileUtils.format_size(result.total_size), :yellow),
            ")"
          ])
        else
          Progress.puts([
            "  ",
            Progress.tag("ℹ", :yellow),
            " No preference files found"
          ])
        end

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp backup_sensitive(home_dir, vault_path) do
    Progress.puts(["\n", Progress.tag("→ Backing up sensitive files...", :cyan)])

    {:ok, result} = Sensitive.backup(home_dir, vault_path)

    if length(result.backed_up) > 0 do
      Progress.puts([
        "  ",
        Progress.tag("✓", :green),
        " Backed up: ",
        Enum.join(result.backed_up, ", ")
      ])

      Progress.puts([
        "    Total size: ",
        Progress.tag(FileUtils.format_size(result.total_size), :yellow)
      ])
    else
      Progress.puts([
        "  ",
        Progress.tag("ℹ", :yellow),
        " No sensitive files found"
      ])
    end
  end

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Path.join(System.user_home!(), "VaultBackup")
  end

  defp get_home_dir(opts) do
    cond do
      is_binary(opts[:home_dir]) -> opts[:home_dir]
      is_binary(System.get_env("HOME")) -> System.get_env("HOME")
      true -> System.user_home!()
    end
  end

  # --- Phase 6: Browser & Obsidian backup ---

  defp backup_brave(home_dir, vault_path) do
    Progress.puts(["\n", Progress.tag("→ Backing up Brave browser...", :cyan)])

    src =
      Path.join([home_dir, "Library", "Application Support", "BraveSoftware", "Brave-Browser"])

    dest = Path.join([vault_path, "browser", "brave"])

    if File.dir?(src) do
      File.mkdir_p!(dest)

      excludes = [
        "Cache/",
        "Code Cache/",
        "GPUCache/",
        "ShaderCache/",
        "GrShaderCache/",
        "DawnCache/",
        "Crashpad/",
        "SwReporter/",
        "Safe Browsing/",
        "Service Worker/CacheStorage/"
      ]

      copy_with_excludes(src, dest, excludes)
      Progress.puts(["  ", Progress.tag("✓", :green), " Brave profile copied (excluding caches)"])
    else
      Progress.puts(["  ", Progress.tag("ℹ", :yellow), " Brave data not found; skipping"])
    end
  end

  defp backup_obsidian(home_dir, vault_path) do
    Progress.puts(["\n", Progress.tag("→ Backing up Obsidian vaults...", :cyan)])

    base = Path.join([home_dir, "Documents", "Eric"])
    dest_base = Path.join([vault_path, "obsidian"])

    if File.dir?(base) do
      File.mkdir_p!(dest_base)

      case File.ls(base) do
        {:ok, entries} ->
          vaults = Enum.filter(entries, fn e -> File.dir?(Path.join(base, e)) end)

          if Enum.empty?(vaults) do
            Progress.puts([
              "  ",
              Progress.tag("ℹ", :yellow),
              " No vaults found in ~/Documents/Eric"
            ])
          else
            Enum.each(vaults, fn v ->
              src = Path.join(base, v)
              dest = Path.join(dest_base, v)
              # Clean dest then copy
              File.rm_rf(dest)

              case Vault.Sync.copy_tree(src, dest) do
                :ok -> Progress.puts(["  ", Progress.tag("✓", :green), " Copied vault: ", v])
                _ -> Progress.puts(["  ", Progress.tag("✗", :red), " Failed vault ", v])
              end
            end)
          end

        _ ->
          Progress.puts(["  ", Progress.tag("ℹ", :yellow), " Unable to read ~/Documents/Eric"])
      end
    else
      Progress.puts(["  ", Progress.tag("ℹ", :yellow), " ~/Documents/Eric not found; skipping"])
    end
  end

  defp copy_with_excludes(src, dest, excludes) do
    Sync.copy_tree(src, dest, exclude: excludes, delete: true)
  end
end
