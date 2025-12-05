defmodule Vault.Sync do
  @moduledoc """
  Wrapper for rsync. Falls back to normal file copy if rsync not available
  """

  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils

  @doc """
  Copies a directory tree or individual file from source to destination.

  Uses rsync if available, otherwise falls back to File.cp_r.

  ## Options

    * `:exclude` - List of patterns to exclude (only with rsync)
    * `:delete` - Delete extraneous files from dest (default: false)
    * `:progress_id` - Atom to track progress, enables streaming mode
    * `:dry_run` - If true, only simulate the operation

  ## Examples

      Sync.copy_tree("/src", "/dest")
      Sync.copy_tree("/src", "/dest", exclude: [".DS_Store", "node_modules"])
      Sync.copy_tree("/src", "/dest", delete: true, progress_id: :my_progress)
      Sync.copy_tree("/src/file.txt", "/dest/file.txt")
  """
  def copy_tree(source, dest, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    cond do
      dry_run ->
        Progress.puts([
          "  ",
          Progress.tag("dry-run:", :light_black),
          " would copy ",
          source,
          " -> ",
          dest
        ])

        {:ok, 0, 0}

      not File.exists?(source) ->
        {:ok, 0, 0}

      available?() ->
        case rsync_copy(source, dest, opts) do
          {:ok, count} ->
            {:ok, size} =
              maybe_return_total_size(
                :ok,
                source,
                dest,
                Keyword.get(opts, :dirs),
                Keyword.get(opts, :exclude, [])
              )

            {:ok, size, count}

          _ ->
            {:error, 0, 0}
        end

      !available?() ->
        :logger.error("rsync not installed")
    end
  end

  def available? do
    not is_nil(System.find_executable("rsync"))
  end

  # Private functions

  defp rsync_copy(source, dest, opts) do
    is_file = File.regular?(source)
    progress_id = Keyword.get(opts, :progress_id)
    verbose = Keyword.get(opts, :verbose)

    if verbose, do: Progress.debug("Calculating file count")

    count =
      compute_transfer_count(source, dest, Keyword.get(opts, :dirs), Keyword.get(opts, :exclude))

    if verbose, do: Progress.debug("Calcuated #{count} files to transfer from #{source}")

    if count == 0 do
      if is_file do
        File.mkdir_p!(Path.dirname(dest))
      else
        File.mkdir_p!(dest)
      end

      Progress.puts([
        "  ",
        source,
        " -> ",
        Path.basename(dest),
        " ",
        Progress.tag("(Done)", :green)
      ])

      {:ok, count}
    else
      Progress.start_progress(progress_id, "  #{source} -> #{Path.basename(dest)}", count)

      port = exec_rsync(source, dest, opts)

      # Track permission errors
      skipped_count = :atomics.new(1, [])

      status =
        stream_rsync_output(port, "", fn lines ->
          Enum.reduce(lines, "", fn line, last ->
            cond do
              String.trim(line) == "" ->
                last

              line == "sending incremental file list" ->
                last

              String.contains?(line, "Operation not permitted") ->
                :atomics.add(skipped_count, 1, 1)
                last

              String.ends_with?(line, "/") ->
                if verbose, do: Progress.set_detail(progress_id, line)

                last

              line == last ->
                last

              true ->
                case sanitize_detail(line) do
                  nil -> :ok
                  safe -> Progress.set_detail(progress_id, safe)
                end

                Progress.increment(progress_id)
                line
            end
          end)
        end)

      skipped = :atomics.get(skipped_count, 1)

      if skipped > 0 do
        Progress.warn("  Skipped #{skipped} files due to permissions")
      end

      {status, count}
    end
  end

  defp exec_rsync(source, dest, opts) do
    dirs = Keyword.get(opts, :dirs)
    is_file = File.regular?(source)

    file_list =
      case dirs do
        nil ->
          nil

        dirs ->
          File.write("tmp/filelist", Enum.join(dirs, "\n"))
          "tmp/filelist"
      end

    rsync = System.find_executable("rsync")

    source_arg = if is_file, do: source, else: ensure_trailing_slash(source)
    exclude_patterns = Keyword.get(opts, :exclude, []) || []
    exclude_args = Enum.flat_map(exclude_patterns, fn p -> ["--exclude", p] end)
    from_files_arg = if file_list, do: ["--files-from=#{file_list}"], else: []
    # Don't use --delete with --files-from as the file list changes based on tracker state
    delete_arg = if Keyword.get(opts, :delete, true), do: ["--delete"], else: []
    archive_arg = if Keyword.get(opts, :archive, true), do: ["-a"], else: []
    recursive_arg = if Keyword.get(opts, :recursive, true), do: ["-r"], else: []
    dry_run_arg = if Keyword.get(opts, :dry_run), do: ["-n"], else: []
    stats_arg = if Keyword.get(opts, :stats), do: ["--stats"], else: []
    omit_dir_times_arg = ["--omit-dir-times"]

    args =
      dry_run_arg ++
        archive_arg ++
        recursive_arg ++
        delete_arg ++
        stats_arg ++
        omit_dir_times_arg ++
        from_files_arg ++
        exclude_args ++
        ["--out-format=%n", source_arg, dest]

    if Keyword.get(opts, :verbose) do
      Progress.debug("Running command: rsync #{Enum.join(args, " ")}")
    end

    if Keyword.get(opts, :stream, true) do
      Port.open({:spawn_executable, rsync}, [
        :binary,
        {:args, args},
        :exit_status,
        :stderr_to_stdout
      ])
    else
      System.cmd(rsync, args, stderr_to_stdout: true)
    end
  end

  # Recursively process rsync output as it appears
  defp stream_rsync_output(port, buffer, process) do
    receive do
      {^port, {:data, data}} ->
        chunk = buffer <> data
        {lines, rest} = split_lines(chunk)

        process.(lines)
        stream_rsync_output(port, rest, process)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, 23}} ->
        # Exit code 23 = Partial transfer due to error (e.g., permission denied on some files)
        # This is acceptable - we got what we could
        :ok

      {^port, {:exit_status, status}} ->
        Progress.error("✗ rsync failed with exit code #{status}\n")
        :error
    after
      300_000 ->
        # 5 minute timeout - only triggers if rsync produces no output for 5 minutes
        Progress.error("✗ rsync timed out (no output for 5 minutes)\n")
        :error
    end
  end

  # Compute the number of files that would be transferred by rsync.
  defp compute_transfer_count(source, dest, dirs, exclude) do
    case exec_rsync(source, dest,
           exclude: exclude,
           dirs: dirs,
           delete: false,
           dry_run: true,
           stream: false
         ) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.reject(&(&1 == "sending incremental file list"))
        |> Enum.reject(&String.ends_with?(&1, "/"))
        |> length()

      {output, 23} ->
        # Exit code 23 = Partial transfer due to permission errors
        # Just count the files, ignore the errors
        output
        |> String.split("\n", trim: true)
        |> Enum.reject(&(&1 == "sending incremental file list"))
        |> Enum.reject(&String.starts_with?(&1, "rsync"))
        |> Enum.reject(&String.contains?(&1, "warning:"))
        |> Enum.reject(&String.contains?(&1, "error:"))
        |> Enum.reject(&String.contains?(&1, "Operation not permitted"))
        |> Enum.reject(&String.ends_with?(&1, "/"))
        |> length()

      {output, _code} ->
        # Other errors - show them
        filtered_output =
          output
          |> String.split("\n", trim: true)
          |> Enum.reject(&(&1 == "sending incremental file list"))
          |> Enum.reject(&String.starts_with?(&1, "rsync"))
          |> Enum.reject(&String.contains?(&1, "warning:"))
          |> Enum.reject(&String.contains?(&1, "error:"))
          |> Enum.reject(&String.ends_with?(&1, "/"))
          |> Enum.join("\n")

        unless filtered_output == "" do
          Progress.error("Error computing transfer count")
        end

        0
    end
  end

  defp split_lines(data) do
    case String.split(data, "\n", parts: :infinity) do
      [] ->
        {[], ""}

      parts ->
        # If data ends with newline, last part is ""
        {Enum.slice(parts, 0, length(parts) - 1), List.last(parts)}
    end
  end

  defp ensure_trailing_slash(path) do
    if String.ends_with?(path, "/"), do: path, else: path <> "/"
  end

  defp sanitize_detail(line) when is_binary(line) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" -> nil
      not String.valid?(trimmed) -> nil
      String.starts_with?(trimmed, "sending incremental file list") -> nil
      String.starts_with?(trimmed, "deleting ") -> nil
      true -> trimmed
    end
  end

  defp sanitize_detail(_), do: nil

  defp maybe_return_total_size(:ok, _source, dest, dirs, _exclude) when is_list(dirs) do
    total_size =
      dirs
      |> Enum.map(fn file ->
        clean_file = String.trim_trailing(file, "/")
        dest_path = Path.join(dest, clean_file)

        case FileUtils.file_size(dest_path) do
          {:ok, size} -> size
          _ -> 0
        end
      end)
      |> Enum.sum()

    {:ok, total_size}
  end

  defp maybe_return_total_size(:ok, _source, dest, nil, _exclude) do
    case FileUtils.file_size(dest) do
      {:ok, size} -> {:ok, size}
      _ -> {:ok, 0}
    end
  end

  defp maybe_return_total_size(other, _source, _dest, _dirs, _exclude), do: other
end
