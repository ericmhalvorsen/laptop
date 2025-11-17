defmodule Vault.Commands.Restore do
  @moduledoc """
  Command to restore macOS configuration from the vault.
  """
  import Bitwise
  alias Vault.Sync
  alias Vault.UI.Progress

  def run(_args, opts) do
    vault_path = get_vault_path(opts)
    dry_run = opts[:dry_run] == true
    home_dir = System.user_home!()
    obsidian_dest = opts[:obsidian_dest] || Path.join([home_dir, "Documents", "Obsidian"])

    Progress.puts([
      Progress.tag("\n📂 Vault Restore", :cyan),
      "\n\n",
      "Vault path: ",
      Progress.tag(vault_path, :yellow),
      "\n"
    ])

    Progress.puts(["\n", Progress.tag("▶ Running app install", :cyan), "\n"])
    Vault.Commands.Install.run([], opts)

    Progress.puts(["\n", Progress.tag("▶ Restoring home directories", :cyan), "\n"])
    restore_home_dirs(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring fonts", :cyan), "\n"])
    restore_fonts(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring dotfiles and ~/.local/bin", :cyan), "\n"])
    restore_dotfiles_and_local_bin(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring Application Support", :cyan), "\n"])
    restore_app_support(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring Preferences", :cyan), "\n"])
    restore_preferences(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring sensitive files", :cyan), "\n"])
    restore_sensitive(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring Brave (browser)", :cyan), "\n"])
    restore_brave(vault_path, home_dir, dry_run)

    Progress.puts(["\n", Progress.tag("▶ Restoring Obsidian vaults", :cyan), "\n"])
    restore_obsidian(vault_path, obsidian_dest, dry_run)

    Progress.puts(["\n", Progress.tag("✓ Restore complete", :green), "\n"])
  end

  defp restore_home_dirs(vault_path, home_dir, dry_run) do
    source_home = Path.join(vault_path, "home")
    if File.dir?(source_home) do
      case File.ls(source_home) do
        {:ok, entries} ->
          entries
          |> Enum.filter(fn entry -> entry != "Library" and not String.starts_with?(entry, ".") end)
          |> Enum.each(fn entry ->
            src = Path.join(source_home, entry)
            dest = Path.join(home_dir, entry)
            copy_tree(src, dest, dry_run)
          end)
        _ -> :ok
      end
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No home data found in vault/home/"])
    end
  end

  # -- Step 2a: Fonts --
  defp restore_fonts(vault_path, home_dir, dry_run) do
    fonts_src = Path.join(vault_path, "fonts")
    fonts_dest = Path.join([home_dir, "Library", "Fonts"])
    if File.dir?(fonts_src) do
      copy_tree(fonts_src, fonts_dest, dry_run)
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No fonts found in vault/fonts/"])
    end
  end

  # -- Step 2b: Dotfiles and local-bin --
  defp restore_dotfiles_and_local_bin(vault_path, home_dir, dry_run) do
    # Dotfiles live under vault/dotfiles
    # Skip .config (restored from laptop/config via install command)
    # Skip mise.toml (restored separately below)
    dotfiles_src = Path.join(vault_path, "dotfiles")
    if File.dir?(dotfiles_src) do
      case File.ls(dotfiles_src) do
        {:ok, items} ->
          items
          |> Enum.reject(fn name -> name == ".config" or name == "mise.toml" or name == ".zsh_history" end)
          |> Enum.each(fn name ->
            src = Path.join(dotfiles_src, name)
            dest = Path.join(home_dir, name)
            copy_tree(src, dest, dry_run)
          end)
        _ -> :ok
      end
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No dotfiles found in vault/dotfiles/"])
    end

    # Restore .zsh_history specifically
    zsh_history_src = Path.join([vault_path, "dotfiles", ".zsh_history"])
    zsh_history_dest = Path.join(home_dir, ".zsh_history")
    if File.exists?(zsh_history_src) do
      if dry_run do
        Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " would restore .zsh_history"])
      else
        Vault.Sync.copy_file(zsh_history_src, zsh_history_dest)
        Progress.puts(["  ", Progress.tag("✓", :green), " Restored .zsh_history"])
      end
    end

    # Restore mise.toml specifically
    mise_toml_src = Path.join([vault_path, "dotfiles", "mise.toml"])
    mise_toml_dest = Path.join(home_dir, "mise.toml")
    if File.exists?(mise_toml_src) do
      if dry_run do
        Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " would restore mise.toml"])
      else
        Vault.Sync.copy_file(mise_toml_src, mise_toml_dest)
        Progress.puts(["  ", Progress.tag("✓", :green), " Restored mise.toml"])
      end
    end

    # ~/.local/bin scripts
    local_bin_src = Path.join(vault_path, "local-bin")
    local_bin_dest = Path.join([home_dir, ".local", "bin"])
    if File.dir?(local_bin_src) do
      copy_tree(local_bin_src, local_bin_dest, dry_run)
      if not dry_run do
        # Try to set executable bit for files directly under bin
        case File.ls(local_bin_dest) do
          {:ok, files} ->
            Enum.each(files, fn f ->
              path = Path.join(local_bin_dest, f)
              if File.regular?(path) do
                case File.stat(path) do
                  {:ok, stat} -> File.chmod(path, stat.mode ||| 0o111)
                  _ -> :ok
                end
              end
            end)
          _ -> :ok
        end
      end
    end
  end

  defp restore_app_support(vault_path, home_dir, dry_run) do
    src = Path.join(vault_path, "app-support")
    dest = Path.join([home_dir, "Library", "Application Support"])
    if File.dir?(src) do
      copy_tree(src, dest, dry_run)
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No Application Support data found in vault/app-support/"])
    end
  end

  defp restore_preferences(vault_path, home_dir, dry_run) do
    src = Path.join(vault_path, "preferences")
    dest = Path.join([home_dir, "Library", "Preferences"])
    if File.dir?(src) do
      if dry_run do
        Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " would restore preferences"])
      else
        case File.ls(src) do
          {:ok, files} ->
            File.mkdir_p!(dest)
            Enum.each(files, fn plist ->
              src_file = Path.join(src, plist)
              dest_file = Path.join(dest, plist)
              Vault.Sync.copy_file(src_file, dest_file)
            end)
            Progress.puts(["  ", Progress.tag("✓", :green), " Restored #{length(files)} preference files"])
          _ ->
            Progress.puts([Progress.tag("  ℹ ", :yellow), "Unable to read preferences directory"])
        end
      end
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No preferences found in vault/preferences/"])
    end
  end

  defp restore_sensitive(vault_path, home_dir, dry_run) do
    sensitive_src = Path.join(vault_path, "sensitive")
    if not File.dir?(sensitive_src) do
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No sensitive data found in vault/sensitive/"])
    else
      restore_item = fn {dir_name, home_path} ->
        src = Path.join(sensitive_src, dir_name)
        dest = Path.join(home_dir, home_path)
        if File.dir?(src) do
          if dry_run do
            Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " would restore ", home_path])
          else
            copy_tree(src, dest, false)
            # Set restrictive permissions on sensitive directories
            case dir_name do
              "ssh" ->
                File.chmod!(dest, 0o700)
                # Set permissions on SSH keys
                case File.ls(dest) do
                  {:ok, files} ->
                    Enum.each(files, fn f ->
                      file_path = Path.join(dest, f)
                      if File.regular?(file_path) and not String.ends_with?(f, ".pub") do
                        File.chmod!(file_path, 0o600)
                      end
                    end)
                  _ -> :ok
                end
                Progress.puts(["  ", Progress.tag("✓", :green), " Restored SSH keys with secure permissions"])
              "gnupg" ->
                File.chmod!(dest, 0o700)
                Progress.puts(["  ", Progress.tag("✓", :green), " Restored GPG keys"])
              "aws" ->
                File.chmod!(dest, 0o700)
                Progress.puts(["  ", Progress.tag("✓", :green), " Restored AWS credentials"])
              "private" ->
                Progress.puts(["  ", Progress.tag("✓", :green), " Restored passwords from .config/private"])
              _ -> :ok
            end
          end
        end
      end

      [
        {"ssh", ".ssh"},
        {"gnupg", ".gnupg"},
        {"aws", ".aws"},
        {"private", ".config/private"}
      ]
      |> Enum.each(restore_item)
    end
  end

  # -- Step 3a: Brave --
  defp restore_brave(vault_path, home_dir, dry_run) do
    src = Path.join([vault_path, "browser", "brave"])
    dest = Path.join([home_dir, "Library", "Application Support", "BraveSoftware", "Brave-Browser"])
    if File.dir?(src) do
      Progress.puts(["  ", Progress.tag("ℹ ", :yellow), "Ensure Brave is closed before restoring."])
      copy_tree_with_excludes(src, dest, dry_run, [
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
      ])
      Progress.puts(["  ", Progress.tag("ℹ ", :yellow), "Passwords/cookies are Keychain-bound and may not transfer. Use Brave Sync or password export/import."])
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No Brave data found in vault/browser/brave/"])
    end
  end

  # -- Step 3b: Obsidian --
  defp restore_obsidian(vault_path, dest_base, dry_run) do
    src_base = Path.join([vault_path, "obsidian"])
    if File.dir?(src_base) do
      Progress.puts(["  ", Progress.tag("ℹ ", :yellow), "Ensure Obsidian is closed before restoring."])
      File.mkdir_p!(dest_base)
      case File.ls(src_base) do
        {:ok, entries} ->
          entries
          |> Enum.filter(fn v -> File.dir?(Path.join(src_base, v)) end)
          |> Enum.each(fn v ->
            src = Path.join(src_base, v)
            dest = Path.join(dest_base, v)
            copy_tree(src, dest, dry_run)
          end)
        _ -> :ok
      end
    else
      Progress.puts([Progress.tag("  ℹ ", :yellow), "No Obsidian data found in vault/obsidian/"])
    end
  end

  defp copy_tree(src, dest, dry_run) do
    Sync.copy_tree(src, dest, dry_run: dry_run)
  end

  defp copy_tree_with_excludes(src, dest, dry_run, excludes) do
    Sync.copy_tree(src, dest, exclude: excludes, delete: true, dry_run: dry_run)
  end

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Path.join(System.user_home!(), "VaultBackup")
  end
end
