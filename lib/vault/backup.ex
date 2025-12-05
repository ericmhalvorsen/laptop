defmodule Vault.Backup do
  use Memoize

  alias Vault.Config
  alias Vault.UI.Progress
  alias Vault.Sync
  alias Vault.Utils.FileUtils
  alias Vault.State

  @doc """
  Back it up joe

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
  def backup(source_dir, dest, dirs \\ nil, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    base_exclude = Keyword.get(opts, :exclude, [])
    verbose = Keyword.get(opts, :verbose)
    tracker = State.get(:backup_tracker) || MapSet.new()

    dirs = FileUtils.expand_contents(dirs || [], source_dir)
    progress_id = String.to_atom("backup_" <> (dest |> String.replace("/", "_")))

    # Build excludes from all tracked directories
    tracker_excludes =
      dirs
      |> Enum.flat_map(fn dir -> tracker_excludes_for_dir(dir, tracker) end)
      |> Kernel.++(Config.default_excludes())
      |> Enum.uniq()

    if verbose do
      Progress.debug("Dirs to backup: #{inspect(dirs)}")
      Progress.debug("Tracker: #{inspect(MapSet.to_list(tracker))}")
      Progress.debug("Tracker excludes: #{inspect(tracker_excludes -- Config.default_excludes())}")
    end

    exclude_patterns = base_exclude ++ tracker_excludes

    if !dry_run, do: File.mkdir_p!(Path.dirname(dest))

    case Sync.copy_tree(source_dir, dest,
           dirs: dirs,
           exclude: exclude_patterns,
           progress_id: progress_id,
           verbose: verbose,
           dry_run: dry_run
         ) do
      {:ok, total_size, count} ->
        updated_tracker =
          Enum.reduce(dirs, tracker, fn dir, acc -> MapSet.put(acc, dir) end)

        State.update(fn state -> Map.put(state, :backup_tracker, updated_tracker) end)

        if verbose,
          do:
            Progress.debug("Tracker: #{updated_tracker |> MapSet.to_list() |> Enum.count()} entries")

        {:ok,
         %{
           summary: [Enum.join(dirs, "\n")],
           stats: %{total_size: total_size, count: count},
           backed_up: dirs
         }}

      {:error, _, _} ->
        {:error, "rsync failed"}
    end
  end

  @spec homebrew(any()) ::
          {:error, atom() | <<_::64, _::_*8>>} | {:ok, %{stats: map(), summary: [...]}}
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
        count: length(taps) + length(casks) + length(formulas),
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

  defp tracker_excludes_for_dir(dir, tracker) do
    # Normalize: remove trailing slash from dir for comparison
    normalized_dir = String.trim_trailing(dir, "/")

    # Special case: if dir is empty or just a dot, match all top-level tracker entries
    if normalized_dir == "" or normalized_dir == "." do
      tracker
      |> Enum.map(&String.trim_trailing(&1, "/"))
    else
      prefix = normalized_dir <> "/"

      tracker
      |> Enum.filter(fn path ->
        normalized_path = String.trim_trailing(path, "/")
        # Check if the tracked path is a child of the current dir
        normalized_path != normalized_dir and String.starts_with?(normalized_path, prefix)
      end)
      |> Enum.map(fn path ->
        String.trim_leading(String.trim_trailing(path, "/"), prefix)
      end)
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
end
