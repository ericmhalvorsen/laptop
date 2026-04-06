defmodule Vault.Commands.Restore do
  @moduledoc """
  Command to restore macOS configuration from the vault.

  This is the EXACT reverse of the backup/save command (vault part only, ignoring git).
  """

  alias Vault.Restore
  alias Vault.Config
  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils
  alias Vault.State

  def run(_args, opts) do
    config = Config.load(opts)
    relative_root = config.defaults.relative_root || "~/"

    State.init_step_stats()

    vault_target = FileUtils.expand_path(opts[:vault_target] || config.vault.dest)
    dest_path = FileUtils.expand_path(relative_root)

    Progress.puts([
      Progress.tag("\n📦 Vault Restore", :cyan),
      "\n\n",
      "Restoring from vault: ",
      Progress.tag(vault_target, :green),
      "\n",
      "Restoring to: ",
      Progress.tag(dest_path, :green),
      "\n"
    ])

    excludes = config.defaults.exclude_patterns

    config.vault.steps
    |> Enum.each(fn step ->
      step_config = step |> Map.new() |> Map.delete(:name)

      execute_step(
        step,
        Map.put(step_config, :source, Path.join(vault_target, step.name)),
        dest_path,
        Keyword.put(opts, :exclude, excludes)
      )
    end)

    display_summary()
  end

  defp execute_step(step, config, dest_root, opts) do
    source_path = FileUtils.expand_path(config.source)
    dest_path = FileUtils.expand_path(dest_root)
    label = Map.get(step, :label, step.name)

    cond do
      Map.get(step, :skip_restore, false) ->
        Progress.puts([
          "\n",
          Progress.tag("→ Skipping #{label}...", :yellow),
          " (skip_restore: true)"
        ])

      !FileUtils.remote_target?(source_path) and !File.exists?(source_path) ->
        Progress.puts([
          "\n",
          Progress.tag("→ Skipping #{label}...", :yellow),
          " (not found in vault)"
        ])

      true ->
        Progress.puts([
          "\n",
          Progress.tag("→ Restoring #{label}...", :cyan)
        ])

        start_time = System.monotonic_time(:millisecond)

        result =
          case step.name do
            "brew" ->
              Restore.homebrew(Path.dirname(source_path), opts)

            "apt" ->
              Restore.apt(Path.dirname(source_path), opts)

            _ ->
              Restore.restore(
                source_path,
                dest_path,
                config.contents || [],
                Keyword.put(opts, :label, label)
              )
          end

        runtime_ms = System.monotonic_time(:millisecond) - start_time

        if Process.whereis(Owl.LiveScreen), do: Owl.LiveScreen.await_render()

        case result do
          {:ok, result} ->
            Progress.puts([
              "  ",
              Progress.tag("✓", :green),
              Progress.tag("   #{result.stats.count} files transferred (", :blue),
              Progress.tag(["source ", FileUtils.format_size(result.stats.total_size)], :yellow),
              Progress.tag(") \n", :blue)
            ])

            State.add_step_stat(step.name, %{
              label: label,
              count: result.stats.count,
              total_size: result.stats.total_size,
              runtime_ms: runtime_ms
            })

          {:error, reason} ->
            Progress.puts([
              "  ",
              Progress.tag("✗", :red),
              " Failed: #{reason}"
            ])
        end
    end
  end

  defp display_summary do
    stats = State.get_step_stats() |> Enum.reverse()

    if Enum.empty?(stats) do
      Owl.Box.new([
        Progress.tag("✓ Restore Complete!", :green),
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
        Progress.tag("✓ Restore Complete!", :green),
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

  defp format_time(ms) when ms < 1000, do: "#{ms}ms"
  defp format_time(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"

  defp format_time(ms) do
    minutes = div(ms, 60_000)
    seconds = Float.round(rem(ms, 60_000) / 1000, 1)
    "#{minutes}m #{seconds}s"
  end
end
