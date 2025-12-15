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
    * `:dirs` - List of specific files/dirs to copy (uses --files-from)
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
    count = compute_transfer_count(source, dest, opts)
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
      Progress.start_progress(
        progress_id,
        "  #{Keyword.get(opts, :label, source)} -> #{dest}",
        count
      )

      port = exec_rsync(source, dest, opts)

      skipped_count = :atomics.new(1, [])
      error_messages = Agent.start_link(fn -> [] end)

      status =
        stream_rsync_output(port, "", error_messages, fn lines, err_agent ->
          Enum.reduce(lines, "", fn line, last ->
            cond do
              String.trim(line) == "" ->
                last

              line == "sending incremental file list" ->
                last

              String.contains?(line, "Operation not permitted") ->
                :atomics.add(skipped_count, 1, 1)
                last

              is_error_line?(line) ->
                {:ok, agent} = err_agent
                Agent.update(agent, fn msgs -> [line | msgs] end)
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

      {:ok, agent} = error_messages
      errors = Agent.get(agent, & &1) |> Enum.reverse()
      Agent.stop(agent)

      skipped = :atomics.get(skipped_count, 1)

      if skipped > 0, do: Progress.warn("  Skipped #{skipped} files due to permissions")

      if status == :error and length(errors) > 0, do: show_rsync_errors(errors, source, dest)

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
          filelist_path =
            System.tmp_dir!() |> Path.join("vault_filelist_#{:rand.uniform(999_999)}")

          clean_dirs =
            Enum.map(dirs, fn dir ->
              dir
              |> String.trim_trailing("/")
              |> String.replace_leading("./", "")
            end)

          if Keyword.get(opts, :verbose, false) do
            Progress.debug("Filelist contents: #{inspect(clean_dirs)}")
            Progress.debug("Source directory: #{source}")
          end

          File.write!(filelist_path, Enum.join(clean_dirs, "\n"))
          filelist_path
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

    ssh_arg =
      case Keyword.get(opts, :ssh_key) do
        nil -> []
        key -> ["-e", "ssh -i #{key}"]
      end

    args =
      dry_run_arg ++
        archive_arg ++
        recursive_arg ++
        delete_arg ++
        stats_arg ++
        omit_dir_times_arg ++
        ssh_arg ++
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
      |> tap(fn _ -> if file_list && File.exists?(file_list), do: File.rm(file_list) end)
    end
  end

  # Recursively process rsync output as it appears
  defp stream_rsync_output(port, buffer, error_agent, process) do
    receive do
      {^port, {:data, data}} ->
        chunk = buffer <> data
        {lines, rest} = split_lines(chunk)

        process.(lines, error_agent)
        stream_rsync_output(port, rest, error_agent, process)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, 23}} ->
        # Exit code 23 = Partial transfer due to error (e.g., permission denied on some files)
        # This is acceptable - we got what we could
        :ok

      {^port, {:exit_status, _status}} ->
        :error
    after
      300_000 ->
        # 5 minute timeout - only triggers if rsync produces no output for 5 minutes
        Progress.error("✗ rsync timed out (no output for 5 minutes)\n")
        :error
    end
  end

  defp is_error_line?(line) do
    String.contains?(line, "rsync:") or
      String.contains?(line, "error:") or
      String.contains?(line, "failed:") or
      String.contains?(line, "Permission denied") or
      String.contains?(line, "Connection") or
      String.contains?(line, "Host key") or
      String.contains?(line, "No route to host") or
      String.contains?(line, "unexpected end of file")
  end

  defp show_rsync_errors(errors, source, dest) do
    error_text = Enum.join(errors, "\n")

    cond do
      String.contains?(error_text, "Permission denied") or
        String.contains?(error_text, "publickey") or
          String.contains?(error_text, "Host key verification failed") ->
        target = if FileUtils.remote_target?(dest), do: dest, else: source
        Progress.error("Cannot access #{target}: Authentication failed")
        Progress.error("Check SSH key permissions or use --ssh-key option")

      String.contains?(error_text, "No route to host") or
        String.contains?(error_text, "Connection refused") or
          String.contains?(error_text, "Could not resolve hostname") ->
        target = if FileUtils.remote_target?(dest), do: dest, else: source
        Progress.error("Cannot connect to #{target}")

      String.contains?(error_text, "unexpected end of file") ->
        target = if FileUtils.remote_target?(dest), do: dest, else: source
        Progress.error("Connection to #{target} dropped unexpectedly")
        Progress.error("This may indicate network issues or the remote rsync process crashed")

      String.contains?(error_text, "No such file or directory") ->
        Progress.error("Path does not exist: #{source}")

      true ->
        Progress.error("rsync failed:")
        errors |> Enum.take(3) |> Enum.each(&Progress.error("  #{&1}"))
    end
  end

  # Compute the number of files that would be transferred by rsync.
  def compute_transfer_count(source, dest, opts) do
    case exec_rsync(source, dest,
           exclude: Keyword.get(opts, :exclude),
           dirs: Keyword.get(opts, :dirs),
           ssh_key: Keyword.get(opts, :ssh_key),
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

      {output, exit_code} ->
        # Other errors - provide specific error messages
        cond do
          String.contains?(output, "Permission denied") or
            String.contains?(output, "publickey") or
              String.contains?(output, "Host key verification failed") ->
            target = if FileUtils.remote_target?(dest), do: dest, else: source
            Progress.error("Cannot access target #{target}: Authentication failed")
            Progress.error("Check SSH key permissions or use --ssh-key option")

          String.contains?(output, "No route to host") or
            String.contains?(output, "Connection refused") or
              String.contains?(output, "Could not resolve hostname") ->
            target = if FileUtils.remote_target?(dest), do: dest, else: source
            Progress.error("Cannot connect to target #{target}")

          String.contains?(output, "No such file or directory") ->
            Progress.error("Source path does not exist: #{source}")

          String.contains?(output, "Permission denied") ->
            Progress.error("Permission denied accessing: #{source}")

          true ->
            # Show actual error output for unknown errors
            filtered_output =
              output
              |> String.split("\n", trim: true)
              |> Enum.reject(&(&1 == "sending incremental file list"))
              |> Enum.take(3)
              |> Enum.join("\n")

            unless filtered_output == "" do
              Progress.error("Error accessing target (exit code #{exit_code}):")
              Progress.error(filtered_output)
            end
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

  defp maybe_return_total_size(:ok, source, dest, dirs, _exclude) when is_list(dirs) do
    base_path = if FileUtils.remote_target?(dest), do: source, else: dest

    total_size =
      dirs
      |> Enum.map(fn file ->
        clean_file = String.trim_trailing(file, "/")
        path = Path.join(base_path, clean_file)

        case FileUtils.file_size(path) do
          {:ok, size} -> size
          _ -> 0
        end
      end)
      |> Enum.sum()

    {:ok, total_size}
  end

  defp maybe_return_total_size(:ok, source, dest, nil, _exclude) do
    path = if FileUtils.remote_target?(dest), do: source, else: dest

    case FileUtils.file_size(path) do
      {:ok, size} -> {:ok, size}
      _ -> {:ok, 0}
    end
  end

  defp maybe_return_total_size(other, _source, _dest, _dirs, _exclude), do: other
end
