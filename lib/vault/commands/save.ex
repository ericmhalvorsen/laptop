defmodule Vault.Commands.Save do
  @moduledoc """
  Command to backup current macOS configuration to the vault.
  """

  alias Vault.Backup
  alias Vault.Sync
  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    config = parse_config_yaml(opts)
    relative_root = config.defaults.relative_root || "~/"

    # Merge in the real steps - filter vault steps by git step names
    git_steps =
      MapSet.new(config.git.steps)
      |> Enum.map(fn step_name ->
        Enum.find(config.vault.steps, fn step -> step[:name] == step_name end)
      end)

    git_config = %{config.git | steps: git_steps}

    git_path = expand_path(config.git.dest)
    vault_path = expand_path(opts[:vault_path] || config.vault.dest)

    Progress.puts([
      Progress.tag("\n📦 Vault Save", :cyan),
      "\n\n",
      "Backing up vault to: ",
      Progress.tag(vault_path, :green),
      "\n"
    ])

    if git_path do
      Progress.puts([
        "Using git repo: ",
        Progress.tag(git_path, :green),
        "\n"
      ])
    end

    excludes = config.defaults.exclude_patterns

    git_config.steps
    |> Enum.each(fn step ->
      step_name = step[:name] || step.name
      step_config = step |> Map.new() |> Map.delete(:name)

      execute_step(
        step_name,
        Map.merge(step_config, %{dest: git_config.dest}),
        relative_root,
        opts
      )
    end)

    config.vault.steps
    |> Enum.each(fn step ->
      step_name = step[:name] || step.name
      step_config = step |> Map.new() |> Map.delete(:name)

      execute_step(
        step_name,
        Map.merge(step_config, %{dest: config.vault.dest}),
        relative_root,
        opts
      )
    end)

    Owl.Box.new([
      Progress.tag("✓ Backup Complete!", :green),
      "\n\n",
      "Saved to vault:\n",
      Progress.tag("  ✓ Dotfiles", :green),
      "\n",
      Progress.tag("  ✓ Local scripts", :green),
      "\n"
    ])
    |> Progress.puts()
  end

  def execute_step(step, config, root, opts \\ nil) do
    source_path = expand_path(root)
    dest_path = expand_path(config.dest)

    Progress.puts(["\n", Progress.tag("→ Backing up #{Map.get(config, :label, step)}...", :cyan)])

    result =
      case step do
        "brew" ->
          Backup.homebrew(dest_path, opts)

        _ ->
          Backup.backup(
            source_path,
            dest_path,
            config.contents |> Enum.map(fn dir -> expand_path(dir, root) end),
            opts
          )
      end

    case result do
      {:ok, result} ->
        Progress.puts([
          "  ",
          Progress.tag("✓", :green),
          " Created backup (",
          Progress.tag(FileUtils.format_size(result.stats.total_size), :yellow),
          "): \n",
          Progress.tag("#{result.summary}", :cyan)
        ])

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp expand_path(path, root) when is_binary(path) do
    cond do
      String.starts_with?(path, "~") ->
        Path.join(System.user_home!(), String.trim_leading(path, "~/"))

      String.starts_with?(path, "/") ->
        path

      true ->
        Path.expand("#{root}/#{path}")
    end
  end

  defp expand_path(nil, nil), do: nil
  defp expand_path(path, nil), do: expand_path(path, File.cwd!())
  defp expand_path(path), do: expand_path(path, File.cwd!())

  defp parse_config_yaml(opts) do
    repo_config = Path.expand("config", File.cwd!())
    config_path = opts[:config_path] || Path.join(repo_config, "vault.yaml")

    case YamlElixir.read_from_file(config_path, atoms: true) do
      {:ok, config} ->
        config

      {:error, reason} ->
        Progress.puts([
          Progress.tag("✗ Failed to read #{config_path}: ", :red),
          inspect(reason)
        ])

        System.halt(1)
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

  defp get_vault_path(opts) do
    opts[:vault_path] || get_default_vault_path()
  end

  defp get_default_vault_path do
    Settings.default_vault_path() ||
      Path.join(System.user_home!(), "VaultBackup")
  end

  defp get_home_dir(opts) do
    cond do
      is_binary(opts[:home_dir]) -> opts[:home_dir]
      is_binary(System.get_env("HOME")) -> System.get_env("HOME")
      true -> System.user_home!()
    end
  end
end
