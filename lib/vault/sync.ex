defmodule Vault.Sync do
  @moduledoc """
  Wrapper for rsync. Falls back to normal file copy if rsync not available
  """

  alias Vault.Config
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
    exclude =
      Keyword.get(opts, :exclude, [])
      |> Kernel.++(Config.default_excludes())
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

      available?() and progress_id != nil and exclude != [] ->
        # Streaming mode with progress tracking
        case rsync_copy(
               source,
               dest,
               exclude,
               delete,
               progress_id
             ) do
          :ok ->
            if return_total_size do
              case compute_total_size(source, exclude) do
                {:ok, size} -> {:ok, size}
                _ -> maybe_return_total_size(:ok, dest, exclude, true)
              end
            else
              :ok
            end

          other ->
            other
        end

      available?() ->
        copy_with_rsync_and_stats(source, dest, exclude, delete)

      true ->
        # Do later on
        {:ok, 0}
    end
  end

  defp copy_with_rsync_and_stats(source, dest, exclude, delete) do
    is_file = File.regular?(source)

    if is_file do
      File.mkdir_p!(Path.dirname(dest))
    else
      File.mkdir_p!(dest)
    end

    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude, fn e -> ["--exclude", e] end)
    delete_arg = if delete, do: ["--delete"], else: []
    source_arg = if is_file, do: source, else: ensure_trailing_slash(source)

    args =
      ["-a", "--stats"] ++ delete_arg ++ exclude_args ++ [source_arg, dest]

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {out, 0} ->
        parse_total_size(out)

      {out, code} ->
        print_error(out, code)
    end
  end

  defp compute_total_size(source, exclude) do
    is_file = File.regular?(source)
    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude, fn p -> ["--exclude", p] end)

    source_arg = if is_file, do: source, else: ensure_trailing_slash(source)
    args = ["-na", "--stats"] ++ exclude_args ++ [source_arg, "/dev/null"]

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {out, 0} -> parse_total_size(out)
      {_out, _code} -> {:ok, 0}
    end
  end

  defp parse_total_size(rsync_output) do
    line =
      rsync_output
      |> String.split("\n", trim: true)
      |> Enum.find(fn l ->
        String.contains?(String.downcase(l), "total file size:") or
          String.contains?(String.downcase(l), "total size of files:")
      end)

    case line do
      nil ->
        {:ok, 0}

      l ->
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

  def print_error(out, code) do
    Progress.puts([Progress.tag("✗ rsync failed (#{code})\n", :red), out])

    out
    |> String.split("\n", trim: true)
    |> Enum.filter(fn line -> String.starts_with?(line, "rsync:") end)
    |> Enum.each(fn line -> Progress.puts(["  ", line, "\n"]) end)

    {:ok, 0}
  end

  @doc """
  Compute the number of files that would be transferred by rsync.

  Useful for setting up progress bars before copying.
  """
  def compute_transfer_count(source, dest, exclude \\ []) do
    is_file = File.regular?(source)
    rsync = System.find_executable("rsync")
    exclude_args = Enum.flat_map(exclude, fn p -> ["--exclude", p] end)

    source_arg = ensure_trailing_slash(if is_file, do: Path.dirname(source), else: source)
    from_files = if is_file, do: ["--files-from=#{Path.basename(source)}"], else: []

    # -n dry-run, -a archive, --delete to mirror behavior, --out-format=%n prints paths
    args =
      ["-na", "--delete", "--out-format=%n"] ++
        from_files ++
        exclude_args ++
        [source_arg, dest]

    :logger.error(args)

    case System.cmd(rsync, args, stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.reject(&(&1 == "sending incremental file list"))
        |> Enum.reject(&String.ends_with?(&1, "/"))
        |> length()

      {output, _code} ->
        Progress.puts([Progress.tag("Error computing transfer count: #{output}", :red)])
        1
    end
  end

  def available? do
    not is_nil(System.find_executable("rsync"))
  end

  # Private functions

  defp rsync_copy(source, dest, exclude, delete, progress_id) do
    is_file = File.regular?(source)
    count = compute_transfer_count(source, dest, exclude)

    if count == 0 do
      if is_file do
        File.mkdir_p!(Path.dirname(dest))
      else
        File.mkdir_p!(dest)
      end

      Progress.puts(["  ", Path.basename(source), " ", Progress.tag("(Done)", :green)])
      :ok
    else
      Progress.start_progress(progress_id, "  #{Path.basename(source)}", count)

      rsync = System.find_executable("rsync")
      exclude_args = Enum.flat_map(exclude, fn pattern -> ["--exclude", pattern] end)
      delete_arg = if delete, do: ["--delete"], else: []

      source_arg = if is_file, do: source, else: ensure_trailing_slash(source)

      args =
        ["-a"] ++
          delete_arg ++
          ["--out-format=%n"] ++
          exclude_args ++
          [source_arg, dest]

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

  defp maybe_return_total_size(other, _dest, _exclude, _flag), do: other
end
