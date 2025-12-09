defmodule Vault.Restore do
  use Memoize

  alias Vault.Config
  alias Vault.UI.Progress
  alias Vault.Sync
  alias Vault.Utils.FileUtils

  @doc """
  Restore files from vault to home directory.

  This is the exact reverse of the backup operation (vault part only, ignoring git).

  ## Parameters

   * `vault_path` - Vault directory path (source)
   * `dest_dir` - Home directory (destination, usually System.user_home!())
   * `dirs` - List of directory names to restore
   * `opts` - Options keyword list
     * `:dry_run` - Boolean, if true don't actually copy files
     * `:exclude` - Additional patterns to exclude

  ## Returns

   * `{:ok, result}` - Success with map containing:
     * `:restored` - List of directories that were restored
     * `:skipped` - List of directories that were skipped (didn't exist in vault)
   * `{:error, reason}` - Failure with reason

  """
  def restore(vault_path, dest_dir, dirs \\ nil, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    base_exclude = Keyword.get(opts, :exclude, [])
    verbose = Keyword.get(opts, :verbose)

    dirs = FileUtils.expand_contents(dirs || [], vault_path)
    progress_id = String.to_atom("restore_" <> (vault_path |> String.replace("/", "_")))

    # For restore, we use the base excludes from config
    exclude_patterns = base_exclude ++ Config.default_excludes()

    if verbose do
      Progress.debug("Dirs to restore: #{inspect(dirs)}")
      Progress.debug("Exclude patterns: #{inspect(exclude_patterns)}")
    end

    if !dry_run, do: File.mkdir_p!(dest_dir)

    case Sync.copy_tree(
           vault_path,
           dest_dir,
           Keyword.merge(opts,
             dirs: dirs,
             exclude: exclude_patterns,
             delete: false,
             progress_id: progress_id
           )
         ) do
      {:ok, total_size, count} ->
        {:ok,
         %{
           summary: [Enum.join(dirs, "\n")],
           stats: %{total_size: total_size, count: count},
           restored: dirs
         }}

      {:error, _, _} ->
        {:error, "rsync failed"}
    end
  end

  @doc """
  Restores Homebrew data from the specified vault directory.

  Reads the Brewfile and other package lists from the vault and uses them
  to restore the Homebrew environment.

  ## Parameters

    * `vault_dir` - Vault directory containing the brew/ subdirectory
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true only show what would be done

  ## Returns

    * `{:ok, result}` - Success with stats map
    * `{:error, reason}` - Failure with reason
  """
  def homebrew(vault_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    using_mock = Keyword.has_key?(opts, :cmd)
    vault_path = fn file -> Path.join([vault_dir, "brew", file]) end
    brewfile_path = vault_path.("Brewfile")

    with :ok <- if(using_mock, do: :ok, else: ensure_homebrew_installed()),
         true <- File.exists?(brewfile_path) do
      if dry_run do
        Progress.puts([
          "  ",
          Progress.tag("dry-run:", :light_black),
          " would restore Homebrew from Brewfile"
        ])

        {:ok, %{summary: ["Would restore Homebrew packages"], stats: %{count: 0, total_size: 0}}}
      else
        case System.cmd("brew", ["bundle", "install", "--file=#{brewfile_path}"],
               stderr_to_stdout: true
             ) do
          {output, 0} ->
            {:ok, size} = FileUtils.file_size(vault_path.("/"))

            {:ok,
             %{
               summary: ["Restored Homebrew packages from Brewfile"],
               stats: %{count: 1, total_size: size}
             }}

          {error, _code} ->
            {:error, "Failed to restore Homebrew: #{error}"}
        end
      end
    else
      false ->
        {:error, "Brewfile not found in vault"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_homebrew_installed do
    case brew_cmd() do
      nil -> {:error, "Homebrew is not installed"}
      _path -> :ok
    end
  end

  defmemo brew_cmd do
    System.find_executable("brew") ||
      if(File.exists?("/opt/homebrew/bin/brew"), do: "/opt/homebrew/bin/brew") ||
      if(File.exists?("/usr/local/bin/brew"), do: "/usr/local/bin/brew") ||
      nil
  end
end
