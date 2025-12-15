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

    State.init_step_stats()

    git_path = FileUtils.expand_path(config.git.dest)
    vault_target = FileUtils.expand_path(opts[:vault_target] || config.vault.dest)

    Progress.puts([
      Progress.tag("\n📦 Vault Save", :cyan),
      "\n\n",
      "Backing up vault to: ",
      Progress.tag(vault_target, :green),
      "\n"
    ])

    # Ensure vault target directory exists
    unless Keyword.get(opts, :dry_run, false) do
      ensure_vault_target_exists(vault_target, opts)
    end

    if git_path do
      Progress.puts([
        "Using git repo: ",
        Progress.tag(git_path, :green),
        "\n"
      ])
    end

    excludes = config.defaults.exclude_patterns

    if !Keyword.get(opts, :vault_only, false) do
      config.git.steps
      |> Enum.each(fn step ->
        step_config = step |> Map.new() |> Map.delete(:name)

        execute_step(
          step,
          Map.merge(step_config, %{dest: config.git.dest}),
          relative_root,
          opts |> Keyword.put(:excludes, excludes) |> Keyword.put(:delete, false)
        )
      end)
    end

    if !Keyword.get(opts, :git_only, false) do
      State.update(fn state -> Map.put(state, :backup_tracker, MapSet.new()) end)

      config.vault.steps
      |> Enum.each(fn step ->
        step_config = step |> Map.new() |> Map.delete(:name)

        execute_step(
          step,
          Map.put(step_config, :dest, vault_target),
          relative_root,
          Keyword.put(opts, :exclude, excludes)
        )
      end)
    end

    display_summary()
  end

  defp execute_step(step, config, root, opts) do
    source_path = FileUtils.expand_path(root)
    dest_path = FileUtils.expand_path(config.dest)
    label = Map.get(step, :label, step.name)

    Progress.puts([
      "\n",
      Progress.tag("→ Backing up #{label}...", :cyan)
    ])

    start_time = System.monotonic_time(:millisecond)

    result =
      case step.name do
        "brew" ->
          Backup.homebrew(dest_path, opts)

        "apt" ->
          Backup.apt(dest_path, opts)

        "snap" ->
          Backup.snap(dest_path, opts)

        _ ->
          Backup.backup(
            source_path,
            Path.join(dest_path, step.name),
            config.contents || [],
            Keyword.put(opts, :label, label)
          )
      end

    runtime_ms = System.monotonic_time(:millisecond) - start_time

    # Yeah thats a good idea dump it
    if Process.whereis(Owl.LiveScreen), do: Owl.LiveScreen.await_render()

    case result do
      {:ok, result} ->
        size_label = if FileUtils.remote_target?(dest_path), do: "source ", else: "target "

        Progress.puts([
          "  ",
          Progress.tag("✓", :green),
          Progress.tag("   #{result.stats.count} files transferred (", :blue),
          Progress.tag([size_label, FileUtils.format_size(result.stats.total_size)], :yellow),
          Progress.tag(") \n", :blue)
        ])

        State.add_step_stat(step.name, %{
          label: label,
          count: result.stats.count,
          total_size: result.stats.total_size,
          runtime_ms: runtime_ms
        })

      {:skipped, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✓", :green),
          " Skipped: #{reason}"
        ])

      {:error, reason} ->
        Progress.puts([
          "  ",
          Progress.tag("✗", :red),
          " Failed: #{reason}"
        ])
    end
  end

  defp display_summary do
    stats = State.get_step_stats() |> Enum.reverse()

    if Enum.empty?(stats) do
      Owl.Box.new([
        Progress.tag("✓ Backup Complete!", :green),
        "\n"
      ])
      |> Progress.puts()
    else
      total_count = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.count end)
      total_size = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.total_size end)
      total_time = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.runtime_ms end)

      step_lines =
        stats
        |> Enum.map(fn stat ->
          [
            Progress.tag("  ✓ ", :green),
            Progress.tag("#{stat.label}: ", :white),
            Progress.tag("#{stat.count} files, ", :blue),
            Progress.tag("#{FileUtils.format_size(stat.total_size)}, ", :yellow),
            Progress.tag("#{format_time(stat.runtime_ms)}", :light_black),
            "\n"
          ]
        end)

      Owl.Box.new([
        Progress.tag("✓ Backup Complete!", :green),
        "\n\n",
        Progress.tag("Summary:", :cyan),
        "\n",
        step_lines,
        "\n",
        Progress.tag("Total: ", :white),
        Progress.tag("#{total_count} files, ", :blue),
        Progress.tag("#{FileUtils.format_size(total_size)}, ", :yellow),
        Progress.tag("#{format_time(total_time)}", :light_black),
        "\n"
      ])
      |> Progress.puts()
    end
  end

  defp ensure_vault_target_exists(vault_target, opts) do
    if FileUtils.remote_target?(vault_target) do
      # Extract user@host and path from target
      [remote, path] = String.split(vault_target, ":", parts: 2)

      ssh_args =
        case Keyword.get(opts, :ssh_key) do
          nil -> []
          key -> ["-i", key]
        end

      case System.cmd("ssh", ssh_args ++ [remote, "mkdir", "-p", path], stderr_to_stdout: true) do
        {_output, 0} ->
          :ok

        {output, _code} ->
          Progress.error("Failed to create remote vault directory: #{vault_target}")
          Progress.error(output)
          System.halt(1)
      end
    else
      # Local target - just create it
      File.mkdir_p!(vault_target)
    end
  end

  defp format_time(ms) when ms < 1000, do: "#{ms}ms"
  defp format_time(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"

  defp format_time(ms) do
    minutes = div(ms, 60_000)
    seconds = Float.round(rem(ms, 60_000) / 1000, 1)
    "#{minutes}m #{seconds}s"
  end
end
