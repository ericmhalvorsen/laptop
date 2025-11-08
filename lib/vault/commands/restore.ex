defmodule Vault.Commands.Restore do
  @moduledoc """
  Command to restore macOS configuration from the vault.
  """
  import Bitwise

  def run(_args, opts) do
    vault_path = get_vault_path(opts)
    dry_run = opts[:dry_run] == true
    home_dir = System.user_home!()

    Owl.IO.puts([
      Owl.Data.tag("\n📂 Vault Restore", :cyan),
      "\n\n",
      "Vault path: ",
      Owl.Data.tag(vault_path, :yellow),
      "\n"
    ])

    Owl.IO.puts(["\n", Owl.Data.tag("▶ Restoring home directories", :cyan), "\n"])
    restore_home_dirs(vault_path, home_dir, dry_run)

    Owl.IO.puts(["\n", Owl.Data.tag("▶ Restoring fonts", :cyan), "\n"])
    restore_fonts(vault_path, home_dir, dry_run)

    Owl.IO.puts(["\n", Owl.Data.tag("▶ Restoring dotfiles and ~/.local/bin", :cyan), "\n"])
    restore_dotfiles_and_local_bin(vault_path, home_dir, dry_run)

    Owl.IO.puts(["\n", Owl.Data.tag("▶ Restoring Application Support", :cyan), "\n"])
    restore_app_support(vault_path, home_dir, dry_run)

    Owl.IO.puts(["\n", Owl.Data.tag("▶ Running app install", :cyan), "\n"])
    Vault.Commands.Install.run([], opts)

    Owl.IO.puts(["\n", Owl.Data.tag("✓ Restore complete", :green), "\n"])
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
      Owl.IO.puts([Owl.Data.tag("  ℹ ", :yellow), "No home data found in vault/home/"])
    end
  end

  # -- Step 2a: Fonts --
  defp restore_fonts(vault_path, home_dir, dry_run) do
    fonts_src = Path.join(vault_path, "fonts")
    fonts_dest = Path.join([home_dir, "Library", "Fonts"])
    if File.dir?(fonts_src) do
      copy_tree(fonts_src, fonts_dest, dry_run)
    else
      Owl.IO.puts([Owl.Data.tag("  ℹ ", :yellow), "No fonts found in vault/fonts/"])
    end
  end

  # -- Step 2b: Dotfiles and local-bin --
  defp restore_dotfiles_and_local_bin(vault_path, home_dir, dry_run) do
    # Dotfiles (including .config) live under vault/dotfiles
    dotfiles_src = Path.join(vault_path, "dotfiles")
    if File.dir?(dotfiles_src) do
      case File.ls(dotfiles_src) do
        {:ok, items} ->
          items
          |> Enum.each(fn name ->
            src = Path.join(dotfiles_src, name)
            dest = Path.join(home_dir, name)
            copy_tree(src, dest, dry_run)
          end)
        _ -> :ok
      end
    else
      Owl.IO.puts([Owl.Data.tag("  ℹ ", :yellow), "No dotfiles found in vault/dotfiles/"])
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
      Owl.IO.puts([Owl.Data.tag("  ℹ ", :yellow), "No Application Support data found in vault/app-support/"])
    end
  end

  defp copy_tree(src, dest, true) do
    Owl.IO.puts(["  ", Owl.Data.tag("dry-run:", :light_black), " would copy ", src, " -> ", dest])
    :ok
  end

  defp copy_tree(src, dest, false) do
    cond do
      not File.exists?(src) -> :ok
      rsync_available?() ->
        File.mkdir_p!(dest)
        args = ["-a"] ++ [src <> "/", dest]
        case System.cmd("rsync", args, stderr_to_stdout: true) do
          {_out, 0} -> :ok
          {out, code} -> Owl.IO.puts([Owl.Data.tag("✗ rsync failed (#{code})\n", :red), out])
        end
      true ->
        File.mkdir_p!(dest)
        case File.cp_r(src, dest, fn _src, _dest -> true end) do
          {:ok, _} -> :ok
          {:error, reason, _file} -> Owl.IO.puts([Owl.Data.tag("✗ copy failed: ", :red), to_string(reason)])
        end
    end
  end

  defp rsync_available? do
    case System.cmd("which", ["rsync"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Path.join(System.user_home!(), "VaultBackup")
  end
end
