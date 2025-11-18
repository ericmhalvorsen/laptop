defmodule Vault.Sync do
  @moduledoc """
  Wrapper for rsync. Falls back to normal file copy if rsync not available
  """

  alias Vault.UI.Progress
  alias Vault.Utils.FileUtils

  @doc """
  Copies a directory tree from source to destination.

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
  """
  def copy_tree(source, dest, opts \\ []) do
    exclude =
      Keyword.get(opts, :exclude, [])
      |> Kernel.++(default_excludes())
      |> Enum.uniq()

    delete = Keyword.get(opts, :delete, false)
    progress_id = Keyword.get(opts, :progress_id)
    dry_run = Keyword.get(opts, :dry_run, false)
    return_total_size = Keyword.get(opts, :return_total_size, false)

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

        if exclude == [] do
          Progress.puts([" (with excludes)"])
        end

        if return_total_size, do: {:ok, 0}, else: :ok

      not File.exists?(source) ->
        if return_total_size, do: {:ok, 0}, else: :ok

      rsync_available?() and progress_id != nil and exclude != [] ->
        # Streaming mode with progress tracking
        case copy_with_rsync_streaming(
               source,
               dest,
               exclude,
               delete,
               progress_id
             ) do
          :ok ->
            if return_total_size do
              case compute_total_size_via_rsync_stats(source, exclude) do
                {:ok, size} -> {:ok, size}
                _ -> maybe_return_total_size(:ok, dest, exclude, true)
              end
            else
              :ok
            end

          other ->
            other
        end

      rsync_available?() ->
        copy_with_rsync_and_stats(source, dest, exclude, delete)

      true ->
        # Do later on 
        {:ok, 0}
    end
  end

  defp copy_with_rsync_and_stats(source, dest, exclude, delete) do
    File.mkdir_p!(dest)

    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude, fn e -> ["--exclude", e] end)
    delete_arg = if delete, do: ["--delete"], else: []

    args =
      ["-a", "--stats"] ++ delete_arg ++ exclude_args ++ [ensure_trailing_slash(source), dest]

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {out, 0} ->
        parse_total_size_from_rsync_stats(out)

      {out, code} ->
        error_lines =
          out
          |> String.split("\n", trim: true)
          |> Enum.filter(fn line -> String.starts_with?(line, "rsync:") end)

        if error_lines == [] do
          Progress.puts([Progress.tag("✗ rsync failed (#{code})\n", :red), out])
        else
          Progress.puts([Progress.tag("✗ rsync failed (#{code}). Problem lines:\n", :red)])
          Enum.each(error_lines, fn line -> Progress.puts(["  ", line, "\n"]) end)
        end

        {:ok, 0}
    end
  end

  defp compute_total_size_via_rsync_stats(source, exclude) do
    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude, fn p -> ["--exclude", p] end)
    args = ["-na", "--stats"] ++ exclude_args ++ [ensure_trailing_slash(source), "/dev/null"]

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {out, 0} -> parse_total_size_from_rsync_stats(out)
      {_out, _code} -> {:ok, 0}
    end
  end

  defp parse_total_size_from_rsync_stats(output) do
    # Try to match either "Total file size:" or "total size of files:" variants
    line =
      output
      |> String.split("\n", trim: true)
      |> Enum.find(fn l ->
        String.contains?(String.downcase(l), "total file size:") or
          String.contains?(String.downcase(l), "total size of files:")
      end)

    case line do
      nil ->
        {:ok, 0}

      l ->
        # extract number before " bytes"
        case Regex.run(~r/(\d+)\s+bytes/i, l) do
          [_, num] ->
            case Integer.parse(num) do
              {n, _} -> {:ok, n}
              _ -> {:ok, 0}
            end

          _ ->
            {:ok, 0}
        end
    end
  end

  @doc """
  Copies a single file from source to destination.

  Uses rsync if available for incremental copying, otherwise falls back to File.cp.

  ## Options

    * `:dry_run` - If true, only simulate the operation
    * `:preserve_permissions` - If true, preserve file permissions (default: true)

  ## Examples

      Sync.copy_file("/src/file.txt", "/dest/file.txt")
      Sync.copy_file("/src/file.txt", "/dest/file.txt", dry_run: true)
  """
  def copy_file(source, dest, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    preserve_permissions = Keyword.get(opts, :preserve_permissions, true)
    return_size = Keyword.get(opts, :return_size, false)

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

        if return_size, do: {:ok, 0}, else: :ok

      not File.exists?(source) ->
        {:error, :enoent}

      rsync_available?() ->
        # Use rsync for single file (skips if unchanged)
        # Create parent directory first
        File.mkdir_p(Path.dirname(dest))

        rsync = System.find_executable("rsync")

        if is_nil(rsync) do
          with :ok <- File.mkdir_p(Path.dirname(dest)),
               :ok <- File.cp(source, dest) do
            if preserve_permissions do
              case File.stat(source) do
                {:ok, stat} -> File.chmod(dest, stat.mode)
                _ -> :ok
              end
            else
              :ok
            end
          end
          |> case do
            :ok -> maybe_return_size(:ok, dest, return_size)
            other -> other
          end
        else
          args = if preserve_permissions, do: ["-a", source, dest], else: [source, dest]

          case System.cmd(rsync, args, stderr_to_stdout: true) do
            {_out, 0} ->
              maybe_return_size(:ok, dest, return_size)

            {out, code} ->
              Progress.puts([Progress.tag("✗ rsync failed (#{code}): ", :red), out])
              {:error, :rsync_failed}
          end
        end

      true ->
        # Fallback to File.cp
        with :ok <- File.mkdir_p(Path.dirname(dest)),
             :ok <- File.cp(source, dest) do
          if preserve_permissions do
            case File.stat(source) do
              {:ok, stat} -> File.chmod(dest, stat.mode)
              _ -> :ok
            end
          else
            :ok
          end
        end
        |> case do
          :ok -> maybe_return_size(:ok, dest, return_size)
          other -> other
        end
    end
  end

  @doc """
  Compute the number of files that would be transferred by rsync.

  Useful for setting up progress bars before copying.
  """
  def compute_transfer_count(source, dest, exclude \\ []) do
    if rsync_available?() do
      rsync = System.find_executable("rsync")
      exclude_args = Enum.flat_map(exclude, fn p -> ["--exclude", p] end)
      # -n dry-run, -a archive, --delete to mirror behavior, --out-format=%n prints paths
      args =
        ["-na", "--delete", "--out-format=%n"] ++
          exclude_args ++ [ensure_trailing_slash(source), dest]

      case System.cmd(rsync, args, stderr_to_stdout: true) do
        {output, 0} ->
          output
          |> String.split("\n", trim: true)
          |> Enum.reject(&(&1 == "sending incremental file list"))
          |> Enum.reject(&String.ends_with?(&1, "/"))
          |> length()

        {_out, _code} ->
          1
      end
    else
      # Fallback to manual counting
      count_files(source, exclude)
    end
  end

  @doc """
  Check if rsync is available on the system.
  """
  def available? do
    rsync_available?()
  end

  # Private functions

  defp rsync_available? do
    not is_nil(System.find_executable("rsync"))
  end

  defp default_excludes do
    [
      "**/*.sock",
      "**/*.lock",
      "**/Cache/**",
      "**/cache/**",
      "**/tmp/**",
      "**/Temp/**",
      "**/log/**",
      "**/logs/**",
      "**/*.tmp",
      "**/*.log"
    ]
  end

  defp copy_with_rsync(source, dest, exclude, delete) do
    File.mkdir_p!(dest)

    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude, fn e -> ["--exclude", e] end)
    delete_arg = if delete, do: ["--delete"], else: []

    args = ["-a"] ++ delete_arg ++ exclude_args ++ [ensure_trailing_slash(source), dest]

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {_out, 0} ->
        :ok

      {out, code} ->
        # Extract rsync error lines to highlight problematic files
        error_lines =
          out
          |> String.split("\n", trim: true)
          |> Enum.filter(fn line -> String.starts_with?(line, "rsync:") end)

        if error_lines == [] do
          Progress.puts([Progress.tag("✗ rsync failed (#{code})\n", :red), out])
        else
          Progress.puts([Progress.tag("✗ rsync failed (#{code}). Problem lines:\n", :red)])

          # error_lines
          # |> Enum.each
          # |> Progress.tag(:red)
          # |> Progress.puts

          Enum.each(error_lines, fn line ->
            Progress.puts(["  ", line, "\n"])
          end)
        end

        # Keep non-fatal behavior
        :ok
    end
  end

  defp copy_with_rsync_streaming(
         source,
         dest,
         exclude,
         delete,
         progress_id
       ) do
    # First check if there's anything to transfer
    count = compute_transfer_count(source, dest, exclude)

    if count == 0 do
      File.mkdir_p!(dest)
      Progress.puts(["  ", Path.basename(source), " ", Progress.tag("(Done)", :green)])
      :ok
    else
      Progress.start_progress(progress_id, "  #{Path.basename(source)}", count)

      rsync = System.find_executable("rsync")
      exclude_args = Enum.flat_map(exclude, fn pattern -> ["--exclude", pattern] end)
      delete_arg = if delete, do: ["--delete"], else: []

      args =
        ["-a"] ++
          delete_arg ++
          ["--out-format=%n"] ++
          exclude_args ++
          [ensure_trailing_slash(source), dest]

      port =
        Port.open({:spawn_executable, rsync}, [
          :binary,
          {:args, args},
          :exit_status,
          :stderr_to_stdout
        ])

      case stream_rsync_output(port, progress_id, "", 0, nil) do
        :ok ->
          :ok

        _ ->
          Progress.puts([Progress.tag("✗ rsync failed\n", :red)])

          :ok
      end
    end
  end

  defp stream_rsync_output(port, progress_id, buffer, inc_count, last_detail) do
    receive do
      {^port, {:data, data}} ->
        # Accumulate and process by lines
        chunk = buffer <> data
        {lines, rest} = split_lines(chunk)

        {new_count, new_last} =
          Enum.reduce(lines, {inc_count, last_detail}, fn line, {acc, last} ->
            cond do
              line == "" ->
                {acc, last}

              line == "sending incremental file list" ->
                {acc, last}

              String.ends_with?(line, "/") ->
                {acc, last}

              line == last ->
                {acc, last}

              true ->
                case sanitize_detail(line) do
                  nil -> :ok
                  safe -> Progress.set_detail(progress_id, safe)
                end

                Progress.increment(progress_id)
                {acc + 1, line}
            end
          end)

        stream_rsync_output(port, progress_id, rest, new_count, new_last)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, _status}} ->
        :error
    after
      60_000 ->
        :error
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

  defp copy_with_file_operations(source, dest, exclude, progress_id) do
    if exclude != [] and progress_id != nil do
      # Recursive copy with exclusions and progress
      File.mkdir_p!(dest)
      copy_with_exclusions(source, dest, exclude, progress_id)
    else
      # Simple copy
      File.rm_rf(dest)
      File.mkdir_p!(dest)

      case File.cp_r(source, dest, on_conflict: fn _src, _dest -> true end) do
        {:ok, _} ->
          :ok

        {:error, reason, _file} ->
          Progress.puts([Progress.tag("✗ copy failed: ", :red), to_string(reason)])
          :ok
      end
    end
  end

  defp copy_with_exclusions(source, dest, exclude_patterns, progress_id) do
    # Create destination directory
    File.mkdir_p!(dest)

    # Get all entries in source directory
    case File.ls(source) do
      {:ok, entries} ->
        # Process each entry
        Enum.each(entries, fn entry ->
          source_path = Path.join(source, entry)
          dest_path = Path.join(dest, entry)

          # Skip if excluded
          unless should_exclude?(entry, exclude_patterns) do
            if File.dir?(source_path) do
              # Recursively copy subdirectory
              copy_with_exclusions(source_path, dest_path, exclude_patterns, progress_id)
            else
              # Increment progress
              if progress_id do
                Progress.increment(progress_id)
                Progress.set_detail(progress_id, Path.relative_to(source_path, source))
              end

              # Copy file, skip if it fails (sockets, special files, etc.)
              try do
                File.cp!(source_path, dest_path)
              rescue
                File.CopyError -> :ok
                File.Error -> :ok
              end
            end
          end
        end)

        :ok

      {:error, reason} ->
        Progress.puts([Progress.tag("✗ list directory failed: ", :red), to_string(reason)])
        :ok
    end
  end

  defp should_exclude?(name, exclude_patterns) do
    Enum.any?(exclude_patterns, fn pattern ->
      name == pattern or String.contains?(name, pattern)
    end)
  end

  defp count_files(dir, exclude_patterns) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.reduce(entries, 0, fn entry, acc ->
          path = Path.join(dir, entry)

          if should_exclude?(entry, exclude_patterns) do
            acc
          else
            if File.dir?(path) do
              acc + count_files(path, exclude_patterns)
            else
              acc + 1
            end
          end
        end)

      {:error, _} ->
        0
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

  defp maybe_return_size(:ok, dest, true) do
    case File.stat(dest) do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_return_size(:ok, _dest, false), do: :ok
  defp maybe_return_size(other, _dest, _flag), do: other

  defp maybe_return_total_size(:ok, dest, exclude, true) do
    case FileUtils.list_files_recursive(dest, exclude: exclude) do
      {:ok, files} ->
        total_size =
          files
          |> Enum.map(fn file ->
            dst_file = Path.join(dest, file)

            case FileUtils.file_size(dst_file) do
              {:ok, size} -> size
              _ -> 0
            end
          end)
          |> Enum.sum()

        {:ok, total_size}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_return_total_size(:ok, _dest, _exclude, false), do: :ok
  defp maybe_return_total_size(other, _dest, _exclude, _flag), do: other
end
