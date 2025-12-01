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

        {:ok, 0}

      not File.exists?(source) ->
        {:ok, 0}

      available?() ->
        case rsync_copy(source, dest, opts) do
          :ok ->
            # TODO: This isn't working but the other one isn't either
            maybe_return_total_size(:ok, dest, exclude, true)

          other ->
            other
        end

      !available?() ->
        :logger.error("rsync not installed")
    end
  end

  # TODO: Change to use exec_rsync
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
  def compute_transfer_count(source, dest, dirs \\ [], exclude \\ []) do
    case exec_rsync(source, dest,
           exclude: exclude,
           dirs: dirs,
           delete: true,
           dry_run: true,
           stream: false
         ) do
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

  defp rsync_copy(source, dest, opts) do
    is_file = File.regular?(source)
    progress_id = Keyword.get(opts, :progress_id)

    count =
      compute_transfer_count(source, dest, Keyword.get(opts, :dirs), Keyword.get(opts, :exclude))

    :logger.info("COUNT: #{count}")

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

      port = exec_rsync(source, dest, opts)

      stream_rsync_output(port, "", fn lines ->
        Enum.reduce(lines, "", fn line, last ->
          cond do
            line == "" ->
              last

            line == "sending incremental file list" ->
              last

            String.ends_with?(line, "/") ->
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
    end
  end

  def exec_rsync(source, dest, opts \\ []) do
    dirs = Keyword.get(opts, :dirs)
    is_file = File.regular?(source)

    :logger.info(dirs)

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
    exclude_args = Enum.flat_map(Keyword.get(opts, :exclude, []), fn p -> ["--exclude", p] end)
    # source_arg = ensure_trailing_slash(if is_file, do: Path.dirname(source), else: source)
    from_files_arg = if file_list, do: ["--files-from=#{file_list}"], else: []
    delete_arg = if Keyword.get(opts, :delete, true), do: ["--delete"], else: []
    archive_arg = if Keyword.get(opts, :archive, true), do: ["-a"], else: []
    dry_run_arg = if Keyword.get(opts, :dry_run), do: ["-n"], else: []
    stats_arg = if Keyword.get(opts, :stats), do: ["--stats"], else: []

    args =
      dry_run_arg ++
        archive_arg ++
        delete_arg ++
        stats_arg ++
        from_files_arg ++
        exclude_args ++
        ["--out-format=%n", source_arg, dest]

    Progress.puts(["Running command: rsync #{Enum.join(args, " ")}"])

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
        # Accumulate and process by lines
        chunk = buffer <> data
        {lines, rest} = split_lines(chunk)

        process.(lines)
        stream_rsync_output(port, rest, process)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, _status}} ->
        Progress.puts([Progress.tag("✗ rsync failed\n", :red)])
        :error
    after
      60_000 ->
        Progress.puts([Progress.tag("✗ rsync timed out\n", :red)])
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
