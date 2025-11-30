defmodule Vault.Commands.Save do
  @moduledoc """
  Command to backup current macOS configuration to the vault.
  """

  alias Vault.Backup
  alias Vault.Config
  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils
  alias Vault.State

  def run(_args, opts) do
    config = Config.load(opts)
    relative_root = config.defaults.relative_root || "~/"

    # Merge in the real steps - filter vault steps by git step names
    git_steps =
      MapSet.new(config.git.steps)
      |> Enum.map(fn step_name ->
        Enum.find(config.vault.steps, fn step -> step[:name] == step_name end)
      end)

    git_config = %{config.git | steps: git_steps}

    git_path = FileUtils.expand_path(config.git.dest)
    vault_path = FileUtils.expand_path(opts[:vault_path] || config.vault.dest)

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

    git_only? = Keyword.get(opts, :git_only, false)
    vault_only? = Keyword.get(opts, :vault_only, false)

    if !vault_only? do
      git_config.steps
      |> Enum.each(fn step ->
        step_name = step[:name] || step.name
        step_config = step |> Map.new() |> Map.delete(:name)

        execute_step(
          step_name,
          Map.merge(step_config, %{dest: git_config.dest}),
          relative_root,
          Keyword.put(opts, :flatten_paths, true)
        )
      end)
    end

    if !git_only? do
      State.update(fn state -> Map.put(state, :backup_tracker, MapSet.new()) end)

      config.vault.steps
      |> Enum.each(fn step ->
        step_config = step |> Map.new() |> Map.delete(:name)

        execute_step(
          step.name,
          Map.merge(step_config, %{dest: config.vault.dest}),
          relative_root,
          Keyword.put(opts, :exclude, excludes)
        )
      end)
    end

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
    source_path = FileUtils.expand_path(root)
    dest_path = FileUtils.expand_path(config.dest)

    Progress.puts(["\n", Progress.tag("→ Backing up #{Map.get(config, :label, step)}...", :cyan)])

    result =
      case step do
        "brew" ->
          Backup.homebrew(dest_path, opts)

        _ ->
          rel_paths = FileUtils.expand_contents(source_path, config.contents || [])

          Backup.backup(
            source_path,
            Path.join(dest_path, step),
            rel_paths,
            opts || []
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
end
