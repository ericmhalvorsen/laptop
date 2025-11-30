defmodule Vault.Backup do
  @moduledoc """
  Backs up home directories (Documents, Downloads, Pictures, Desktop) to vault.

  Uses File.cp_r for recursive copying with exclusion patterns.
  Files are saved to vault/home/ (NOT committed to git).
  """

  use Memoize

  alias Vault.UI.Progress
  alias Vault.Sync
  alias Vault.Utils.FileUtils

  @doc """
  Backs up Homebrew data to the specified destination directory.

  Creates a `brew/` subdirectory in the destination and saves:
  - Brewfile (via `brew bundle dump`)
  - formulas.txt (via `brew list --formula`)
  - casks.txt (via `brew list --cask`)
  - taps.txt (via `brew tap`)

  ## Parameters

    * `dest_dir` - Destination directory for the backup
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true only count packages without writing files

  ## Returns

    * `{:ok, result}` - Success with counts map containing:
      * `:brewfile` - Boolean indicating Brewfile was created
      * `:formulas` - Count of formula packages
      * `:casks` - Count of cask applications
      * `:taps` - Count of tapped repositories
    * `{:error, reason}` - Failure with reason
  """
  def homebrew(dest_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    using_mock = Keyword.has_key?(opts, :cmd)
    dest_path = fn file -> Path.join([dest_dir, "brew", file]) end
    brewfile_path = dest_path.("Brewfile")

    if dry_run do
      :logger.error("DRY_RUN")
    end

    with :ok <- if(using_mock, do: :ok, else: ensure_homebrew_installed()),
         {:ok, formulas} <- brew(["list", "--formula"], dry_run),
         {:ok, casks} <- brew(["list", "--cask"], dry_run),
         {:ok, taps} <- brew(["tap"], dry_run),
         {:ok, _} <- FileUtils.ensure_dir(dest_path.("/"), dry_run),
         {:ok, _} <- File.rm_rf(brewfile_path),
         {:ok, _} <- brew(["bundle", "dump", "--file=#{brewfile_path}"], dry_run),
         {:ok, _} <-
           FileUtils.output_file(dest_path.("formulas.txt"), formulas, dry_run),
         {:ok, _} <-
           FileUtils.output_file(dest_path.("casks.txt"), casks, dry_run),
         {:ok, _} <-
           FileUtils.output_file(dest_path.("taps.txt"), taps, dry_run) do
      {:ok, size} = FileUtils.file_size(dest_path.("/"))

      stats = %{
        brewfile: brewfile_path,
        formulas: length(formulas),
        casks: length(casks),
        taps: length(taps),
        total_size: size
      }

      {:ok,
       %{
         summary: [
           "    Saved homebrew: \n",
           "      #{stats[:formulas]} formulas\n",
           "      #{stats[:casks]} casks\n",
           "      #{stats[:taps]} taps\n"
         ],
         stats: stats
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_homebrew_installed do
    case brew_cmd() do
      nil -> {:error, "Homebrew is not installed"}
      _path -> :ok
    end
  end

  defp brew(_args, true), do: {:ok, ["dry_run"]}

  defp brew(args, _) do
    case System.cmd(brew_cmd(), args, stderr_to_stdout: true) do
      {output, 0} ->
        formulas =
          output
          |> String.split("\n", trim: true)

        {:ok, formulas}

      {error, _code} ->
        {:error, "Failed to run brew #{args}: #{error}}"}
    end
  end

  defmemo brew_cmd do
    System.find_executable("brew") ||
      if(File.exists?("/opt/homebrew/bin/brew"), do: "/opt/homebrew/bin/brew") ||
      if(File.exists?("/usr/local/bin/brew"), do: "/usr/local/bin/brew") ||
      nil
  end

  @doc """
  Backs up to the destination dir

  ## Parameters

   * `source_dir` - Home directory (usually System.user_home!())
   * `vault_path` - Vault directory path
   * `dirs` - List of directory names
   * `opts` - Options keyword list
     * `:dry_run` - Boolean, if true don't actually copy files
     * `:exclude` - Additional patterns to exclude

  ## Returns

   * `{:ok, result}` - Success with map containing:
     * `:backed_up` - List of directories that were backed up
     * `:skipped` - List of directories that were skipped (didn't exist)
   * `{:error, reason}` - Failure with reason

  """
  def backup(source_dir, vault_path, dirs \\ nil, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    exclude = Keyword.get(opts, :exclude, []) ++ @exclude_patterns

    with :ok <- Progress.puts(dirs) do
      {:ok, %{summary: Enum.join(dirs, "\n"), stats: %{total_size: 123_456}}}
    end

    # with {:ok, _} <- validate_source(source_dir),
    #      {:ok, dirs_to_backup} <- get_directories_to_backup(source_dir, vault_path, dirs),
    #      {:ok, _} <- maybe_create_home_dir(vault_path, dry_run) do
    #   result = process_directories(source_dir, vault_path, dirs_to_backup, exclude, dry_run)
    #   {:ok, result}
    # end
  end

  defp validate_source(source_dir) do
    if File.dir?(source_dir) do
      {:ok, :valid}
    else
      {:error, "source directory does not exist: #{source_dir}"}
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
            copy_directory_with_progress(source_path, dest_path, exclude, progress_id)
            {:backed_up, dir}
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

  defp copy_directory_with_progress(source, dest, exclude_patterns, progress_id) do
    threshold = 1

    if Sync.available?() do
      count = Sync.compute_transfer_count(source, dest, exclude_patterns)

      cond do
        count == 0 ->
          File.mkdir_p!(dest)
          Progress.puts(["  ", Path.basename(source), " ", Progress.tag("(Done)", :green)])
          :ok

        count <= threshold ->
          # Non-streaming copy for small/no-op dirs
          case Sync.copy_tree(source, dest, exclude: exclude_patterns, delete: true) do
            :ok ->
              Progress.puts(["  ", Path.basename(source), " ", Progress.tag("(Done)", :green)])

            _ ->
              Progress.puts([
                "  ",
                Path.basename(source),
                " ",
                Progress.tag("(Copy issues)", :yellow)
              ])
          end

        true ->
          # Streaming bar with per-file detail (sanitized in Sync)
          Progress.start_progress(progress_id, "  #{Path.basename(source)}", count)

          case Sync.copy_tree(source, dest,
                 exclude: exclude_patterns,
                 delete: true,
                 progress_id: progress_id
               ) do
            :ok -> :ok
            _ -> :ok
          end
      end
    else
      # Fallback copy without streaming
      File.rm_rf(dest)

      case Sync.copy_tree(source, dest, exclude: exclude_patterns) do
        :ok ->
          Progress.puts(["  ", Path.basename(source), " ", Progress.tag("(Done)", :green)])

        _ ->
          Progress.puts([
            "  ",
            Path.basename(source),
            " ",
            Progress.tag("(Copy issues)", :yellow)
          ])
      end
    end
  end

  defp collect_results(results, type) do
    results
    |> Enum.filter(fn {result_type, _dir} -> result_type == type end)
    |> Enum.map(fn {_type, dir} -> dir end)
  end
end
