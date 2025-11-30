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
  alias Vault.State

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
    base_exclude = Keyword.get(opts, :exclude, [])
    tracker = State.get(:backup_tracker) || MapSet.new()

    dirs = dirs || []

    {updated_tracker, results} =
      Enum.reduce(dirs, {tracker, []}, fn dir, {tracker_acc, acc} ->
        source_path = Path.join(source_dir, dir)
        dest_path = Path.join(vault_path, dir)

        if File.dir?(source_path) do
          progress_id = String.to_atom("backup_" <> (dir |> String.replace("/", "_")))

          exclude_patterns =
            base_exclude ++
              tracker_excludes_for_dir(dir, tracker_acc)

          unless dry_run do
            File.mkdir_p!(dest_path)
            Progress.puts(["  ", Path.basename(source_path), " ", Progress.tag("(Done)", :green)])
            :ok

            Sync.copy_tree(source_path, dest_path,
              exclude: exclude_patterns,
              delete: true,
              progress_id: progress_id
            )
          end

          {MapSet.put(tracker_acc, dir), [{:backed_up, dir} | acc]}
        else
          {tracker_acc, [{:skipped, dir} | acc]}
        end
      end)

    backed_up = collect_results(results, :backed_up)
    skipped = collect_results(results, :skipped)

    {:ok, total_size} = FileUtils.file_size(vault_path)

    State.update(fn state -> Map.put(state, :backup_tracker, updated_tracker) end)

    {:ok,
     %{
       summary: [Enum.join(backed_up, "\n")],
       stats: %{total_size: total_size},
       backed_up: backed_up,
       skipped: skipped
     }}
  end

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

  defp collect_results(results, type) do
    results
    |> Enum.filter(fn {result_type, _dir} -> result_type == type end)
    |> Enum.map(fn {_type, dir} -> dir end)
  end

  defp tracker_excludes_for_dir(dir, tracker) do
    prefix = dir <> "/"

    tracker
    |> Enum.filter(fn path -> String.starts_with?(path, prefix) end)
    |> Enum.map(fn path -> String.trim_leading(path, prefix) end)
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
