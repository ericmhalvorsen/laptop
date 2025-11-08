defmodule Vault.Backup.HomeDirs do
  @moduledoc """
  Backs up home directories (Documents, Downloads, Pictures, Desktop) to vault.

  Uses File.cp_r for recursive copying with exclusion patterns.
  Files are saved to vault/home/ (NOT committed to git).
  """

  # Common files/directories to exclude from backup
  @exclude_patterns [
    ".DS_Store",
    "node_modules",
    ".git",
    "Thumbs.db",
    ".cache"
  ]

  @doc """
  Backs up home directories to the vault.

  If no directory list is provided, automatically discovers all public
  (non-hidden) directories in the home directory.

  ## Parameters

    * `source_dir` - Home directory (usually System.user_home!())
    * `vault_path` - Vault directory path
    * `dirs` - Optional list of directory names (defaults to all public dirs)
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true don't actually copy files
      * `:exclude` - Additional patterns to exclude

  ## Returns

    * `{:ok, result}` - Success with map containing:
      * `:backed_up` - List of directories that were backed up
      * `:skipped` - List of directories that were skipped (didn't exist)
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> HomeDirs.backup("/Users/eric", "/tmp/vault")
      {:ok, %{backed_up: ["Documents", "Downloads", "Desktop", ...], skipped: []}}

      iex> HomeDirs.backup("/Users/eric", "/tmp/vault", ["Documents"])
      {:ok, %{backed_up: ["Documents"], skipped: []}}
  """
  def backup(source_dir, vault_path, dirs \\ nil, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    exclude = Keyword.get(opts, :exclude, []) ++ @exclude_patterns

    with {:ok, _} <- validate_source(source_dir),
         {:ok, dirs_to_backup} <- get_directories_to_backup(source_dir, vault_path, dirs),
         {:ok, _} <- maybe_create_home_dir(vault_path, dry_run) do
      result = process_directories(source_dir, vault_path, dirs_to_backup, exclude, dry_run)
      {:ok, result}
    end
  end

  # Get list of directories to backup
  # If dirs is provided, use that. Otherwise, discover all public directories.
  defp get_directories_to_backup(source_dir, vault_path, nil) do
    # Get vault directory name to exclude it
    vault_dir_name = Path.basename(vault_path)

    case File.ls(source_dir) do
      {:ok, entries} ->
        # Filter to only directories that don't start with "."
        # Exclude Library (we handle Application Support separately)
        # Exclude vault directory (don't backup the backup!)
        public_dirs =
          entries
          |> Enum.filter(fn entry ->
            path = Path.join(source_dir, entry)
            File.dir?(path) and
              not String.starts_with?(entry, ".") and
              entry != "Library" and
              entry != vault_dir_name
          end)
          |> Enum.sort()

        {:ok, public_dirs}

      {:error, reason} ->
        {:error, "failed to list home directory: #{reason}"}
    end
  end

  defp get_directories_to_backup(_source_dir, _vault_path, dirs) when is_list(dirs) do
    {:ok, dirs}
  end

  # Validate source directory exists
  defp validate_source(source_dir) do
    if File.dir?(source_dir) do
      {:ok, :valid}
    else
      {:error, "source directory does not exist: #{source_dir}"}
    end
  end

  # Create vault/home directory if not dry run
  defp maybe_create_home_dir(vault_path, dry_run) do
    if dry_run do
      {:ok, :skipped}
    else
      home_dir = Path.join(vault_path, "home")

      case File.mkdir_p(home_dir) do
        :ok -> {:ok, home_dir}
        {:error, reason} -> {:error, "failed to create home directory: #{reason}"}
      end
    end
  end

  # Process each directory in the list
  defp process_directories(source_dir, vault_path, dirs, exclude, dry_run) do
    results =
      Enum.map(dirs, fn dir ->
        source_path = Path.join(source_dir, dir)
        dest_path = Path.join([vault_path, "home", dir])

        if File.dir?(source_path) do
          if dry_run do
            {:backed_up, dir}
          else
            progress_id = String.to_atom("home_dir_#{dir}")
            case copy_directory_with_progress(source_path, dest_path, exclude, progress_id) do
              :ok -> {:backed_up, dir}
              {:error, _reason} -> {:skipped, dir}
            end
          end
        else
          {:skipped, dir}
        end
      end)

    %{
      backed_up: collect_results(results, :backed_up),
      skipped: collect_results(results, :skipped)
    }
  end

  # Copy directory with progress tracking
  defp copy_directory_with_progress(source, dest, exclude_patterns, progress_id) do
    use_rsync = rsync_available?()
    if use_rsync do
      # Preflight dry-run to determine exact transfer count
      count = compute_transfers_count(source, dest, exclude_patterns)

      if count == 0 do
        Owl.IO.puts(["  ", Path.basename(source), " ", Owl.Data.tag("(Done)", :green)])
        :ok
      else
        Owl.ProgressBar.start(
          id: progress_id,
          label: "  #{Path.basename(source)}",
          total: count,
          bar_width_ratio: 0.5,
          filled_symbol: "█",
          partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
        )

        result = copy_with_rsync(source, dest, exclude_patterns, progress_id)
        Owl.LiveScreen.await_render()
        result
      end
    else
      total_files = max(count_files(source, exclude_patterns), 1)

      Owl.ProgressBar.start(
        id: progress_id,
        label: "  #{Path.basename(source)}",
        total: total_files,
        bar_width_ratio: 0.5,
        filled_symbol: "█",
        partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
      )

      # Remove destination if it exists (for clean copy)
      File.rm_rf(dest)
      # Copy recursively with progress updates
      result = copy_with_exclusions(source, dest, exclude_patterns, progress_id)

      Owl.LiveScreen.await_render()
      result
    end
  end

  defp compute_transfers_count(source, dest, exclude_patterns) do
    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude_patterns, fn p -> ["--exclude", p] end)
    # -n dry-run, -a archive, --delete to mirror behavior, --out-format=%n prints paths
    args = ["-na", "--delete", "--out-format=%n"] ++ exclude_args ++ [source <> "/", dest]

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.reject(&(&1 == "sending incremental file list"))
        |> Enum.reject(&String.ends_with?(&1, "/"))
        |> length()
      {_out, _code} -> 1
    end
  end

  # Check if rsync is available on the system
  defp rsync_available? do
    case System.cmd("which", ["rsync"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  # Copy directory using rsync for better performance
  defp copy_with_rsync(source, dest, exclude_patterns, progress_id) do
    # Build exclude arguments for rsync
    exclude_args =
      Enum.flat_map(exclude_patterns, fn pattern ->
        ["--exclude", pattern]
      end)

    # We stream rsync output and increment on each file path printed.
    # --out-format=%n prints the file name for each transferred item.
    rsync = System.find_executable("rsync")
    args =
      [
        "-a",
        "--delete",
        "--out-format=%n"
      ] ++ exclude_args ++ [source <> "/", dest]

    port = Port.open({:spawn_executable, rsync}, [
      :binary,
      {:args, args},
      :exit_status,
      :stderr_to_stdout
    ])

    result = stream_rsync_and_increment(port, progress_id)
    case result do
      :ok -> :ok
      _ -> {:error, :rsync_failed}
    end
  end

  defp stream_rsync_and_increment(port, progress_id, buffer \\ "", inc_count \\ 0) do
    receive do
      {^port, {:data, data}} ->
        # Accumulate and process by lines
        chunk = buffer <> data
        {lines, rest} = split_lines(chunk)
        new_count =
          Enum.reduce(lines, inc_count, fn line, acc ->
            case line do
              "" -> :ok
              "sending incremental file list" -> :ok
              _ ->
                # rsync prints directories with trailing '/'; only increment for files
                if not String.ends_with?(line, "/") do
                  Owl.ProgressBar.inc(id: progress_id)
                  # throttle rendering to keep UI responsive
                  if rem(acc + 1, 200) == 0 do
                    Owl.LiveScreen.await_render()
                  end
                  acc + 1
                else
                  acc
                end
            end
          end)
        stream_rsync_and_increment(port, progress_id, rest, new_count)

      {^port, {:exit_status, 0}} ->
        # final flush
        Owl.LiveScreen.await_render()
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
      [] -> {[], ""}
      parts ->
        # If data ends with newline, last part is ""
        # Otherwise, keep last part as buffer remainder
        {Enum.slice(parts, 0, length(parts) - 1), List.last(parts)}
    end
  end

  # Count total files in directory (for progress bar)
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

  # Recursively copy directory with exclusions
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
                Owl.ProgressBar.inc(id: progress_id)
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
        {:error, reason}
    end
  end

  # Check if file/directory should be excluded
  defp should_exclude?(name, exclude_patterns) do
    Enum.any?(exclude_patterns, fn pattern ->
      name == pattern or String.contains?(name, pattern)
    end)
  end

  # Collect results of specific type
  defp collect_results(results, type) do
    results
    |> Enum.filter(fn {result_type, _dir} -> result_type == type end)
    |> Enum.map(fn {_type, dir} -> dir end)
  end
end
