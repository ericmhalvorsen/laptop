defmodule Vault.Commands.Install do
  @moduledoc """
  Bootstrap a fresh system by installing packages and restoring dotfiles from git.

  This is the main bootstrap command - it will:
  1. Detect platform (macOS or Ubuntu)
  2. Restore package managers (brew on macOS, apt + snap on Ubuntu)
  3. Restore all git steps (dotfiles, scripts, etc) to home directory
  """

  alias Vault.Config
  alias Vault.Restore
  alias Vault.UI.Progress
  alias Vault.Sync
  alias Vault.Utils.FileUtils

  def run(_args, opts) do
    config = Config.load(opts)
    git_path = File.cwd!()
    home_dir = config.defaults.relative_root

    Progress.puts([
      Progress.tag("\n🚀 Vault Install (Bootstrap)", :cyan),
      "\n\n",
      "Installing from: ",
      Progress.tag(git_path, :green),
      "\n"
    ])

    # Detect platform
    platform = detect_platform()

    Progress.puts([
      "Platform: ",
      Progress.tag(platform_name(platform), :yellow),
      "\n"
    ])

    # Restore package managers
    restore_package_managers(platform, git_path, opts)

    # Restore git steps (dotfiles, scripts, etc)
    restore_git_steps(config, git_path, home_dir, opts)

    # Setup Neovim config
    setup_nvim(home_dir, opts)

    Progress.puts(["\n", Progress.tag("✓ Install complete", :green), "\n"])
  end

  defp detect_platform do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, :linux} -> :ubuntu
      _ -> :unknown
    end
  end

  defp platform_name(:macos), do: "macOS"
  defp platform_name(:ubuntu), do: "Ubuntu/Linux"
  defp platform_name(:unknown), do: "Unknown"

  defp restore_package_managers(:macos, git_path, opts) do
    Progress.puts(["\n", Progress.tag("▶ Restoring Homebrew packages", :cyan), "\n"])

    case Restore.homebrew(git_path, opts) do
      {:ok, result} ->
        Progress.puts(["  ", Progress.tag("✓", :green), " ", hd(result.summary)])

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed to restore Homebrew: ",
          to_string(reason)
        ])
    end
  end

  defp restore_package_managers(:ubuntu, git_path, opts) do
    Progress.puts(["\n", Progress.tag("▶ Restoring APT packages", :cyan), "\n"])

    case Restore.apt(git_path, opts) do
      {:ok, result} ->
        Progress.puts(["  ", Progress.tag("✓", :green), " ", hd(result.summary)])

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed to restore APT: ",
          to_string(reason)
        ])
    end

    Progress.puts(["\n", Progress.tag("▶ Restoring Snap packages", :cyan), "\n"])

    case Restore.snap(git_path, opts) do
      {:ok, result} ->
        Progress.puts(["  ", Progress.tag("✓", :green), " ", hd(result.summary)])
    end
  end

  defp restore_package_managers(:unknown, _git_path, _opts) do
    Progress.puts([
      "\n",
      Progress.tag("! Unknown platform, skipping package manager restore", :yellow),
      "\n"
    ])
  end

  defp restore_git_steps(config, git_path, home_dir, opts) do
    dry_run = Keyword.get(opts, :dry_run, false)

    Progress.puts(["\n", Progress.tag("▶ Restoring dotfiles and scripts", :cyan), "\n"])

    # Get git steps, excluding package managers (brew, apt, snap)
    file_steps =
      config.git.steps
      |> Enum.filter(fn step ->
        step_name = if is_map(step), do: step.name, else: step
        step_name not in ["brew", "apt", "snap"]
      end)

    Enum.each(file_steps, fn step ->
      step_config =
        Enum.find(config.steps, fn s -> s.name == if is_map(step), do: step.name, else: step end)

      step_name = if is_map(step), do: step.name, else: step
      step_dir = Path.join(git_path, step_name)
      contents = if step_config, do: step_config.contents, else: []

      if File.exists?(step_dir) and File.dir?(step_dir) do
        restore_step_directory(step_name, step_dir, home_dir, contents, dry_run)
      else
        Progress.puts([
          "  ",
          Progress.tag("•", :light_black),
          " Skipping ",
          step_name,
          " (not found)"
        ])
      end
    end)
  end

  defp restore_step_directory(step_name, step_dir, home_dir, contents, dry_run) do
    # Copy contents of step directory to home directory
    # e.g., dotfiles/.bashrc -> ~/.bashrc
    #       scripts/.local/bin/foo -> ~/.local/bin/foo

    if dry_run do
      Progress.puts([
        "  ",
        Progress.tag("dry-run:", :light_black),
        " would restore ",
        step_name,
        " to ",
        home_dir
      ])
    else
      expanded_contents = FileUtils.expand_contents(contents, step_dir)

      case Sync.copy_tree(step_dir, home_dir, dry_run: false, delete: false, dirs: expanded_contents) do
        {:ok, _size, count} ->
          Progress.puts([
            "  ",
            Progress.tag("✓", :green),
            " Restored ",
            step_name,
            " (",
            to_string(count),
            " files)"
          ])

        {:error, reason, _} ->
          Progress.puts([
            "  ",
            Progress.tag("✗", :red),
            " Failed to restore ",
            step_name,
            ": ",
            to_string(reason)
          ])
      end
    end
  end

  defp setup_nvim(home_dir, opts) do
    dry_run = Keyword.get(opts, :dry_run, false)
    nvim_config = Path.join(home_dir, ".config/nvim")
    code_dir = Path.join(home_dir, "code")
    nvim_repo_dir = Path.join(code_dir, "nvim")
    nvim_repo_url = "https://github.com/ericmhalvorsen/nvim.git"

    Progress.puts(["\n", Progress.tag("▶ Setting up Neovim config", :cyan), "\n"])

    cond do
      File.exists?(nvim_config) ->
        Progress.puts([
          "  ",
          Progress.tag("•", :light_black),
          " Neovim config already exists at ",
          nvim_config
        ])

      dry_run ->
        Progress.puts([
          "  ",
          Progress.tag("dry-run:", :light_black),
          " would clone nvim to ",
          nvim_repo_dir,
          " and symlink to ",
          nvim_config
        ])

      true ->
        # Ensure ~/code directory exists
        unless File.exists?(code_dir) do
          File.mkdir_p!(code_dir)
        end

        # Clone repo if it doesn't exist
        clone_result =
          if File.exists?(nvim_repo_dir) do
            :ok
          else
            Progress.puts([
              "  ",
              Progress.tag("→", :blue),
              " Cloning nvim config to ",
              nvim_repo_dir
            ])

            case System.cmd("git", ["clone", nvim_repo_url, nvim_repo_dir],
                   stderr_to_stdout: true
                 ) do
              {_output, 0} ->
                Progress.puts([
                  "  ",
                  Progress.tag("✓", :green),
                  " Cloned nvim repository"
                ])

                :ok

              {output, _code} ->
                Progress.puts([
                  "  ",
                  Progress.tag("✗", :red),
                  " Failed to clone nvim: ",
                  String.trim(output)
                ])

                :error
            end
          end

        # Create symlink only if clone succeeded
        if clone_result == :ok do
          config_dir = Path.join(home_dir, ".config")
          File.mkdir_p!(config_dir)

          case File.ln_s(nvim_repo_dir, nvim_config) do
            :ok ->
              Progress.puts([
                "  ",
                Progress.tag("✓", :green),
                " Created symlink ",
                nvim_config,
                " -> ",
                nvim_repo_dir
              ])

            {:error, reason} ->
              Progress.puts([
                "  ",
                Progress.tag("✗", :red),
                " Failed to create symlink: ",
                to_string(reason)
              ])
          end
        end
    end
  end
end
