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

    # Check if Homebrew is installed
    case if(using_mock, do: :ok, else: ensure_homebrew_installed()) do
      {:error, _reason} ->
        # Homebrew not installed, skip gracefully
        {:ok,
         %{
           summary: ["Homebrew not installed, skipping"],
           stats: %{count: 0, total_size: 0}
         }}

      :ok ->
        if !File.exists?(brewfile_path) do
          {:ok,
           %{
             summary: ["Brewfile not found in vault, skipping"],
             stats: %{count: 0, total_size: 0}
           }}
        else
          if dry_run do
            Progress.puts([
              "  ",
              Progress.tag("dry-run:", :light_black),
              " would restore Homebrew from Brewfile"
            ])

            {:ok,
             %{
               summary: ["Would restore Homebrew packages"],
               stats: %{count: 0, total_size: 0}
             }}
          else
            case System.cmd("brew", ["bundle", "install", "--file=#{brewfile_path}"],
                   stderr_to_stdout: true
                 ) do
              {_output, 0} ->
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
        end
    end
  end

  @doc """
  Restores APT packages from the specified vault directory.

  Reads the package lists and configurations from the vault and uses them
  to restore the APT environment.

  ## Parameters

    * `vault_dir` - Vault directory containing the apt/ subdirectory
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true only show what would be done

  ## Returns

    * `{:ok, result}` - Success with stats map
    * `{:error, reason}` - Failure with reason
  """
  def apt(vault_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    using_mock = Keyword.has_key?(opts, :cmd)
    vault_path = fn file -> Path.join([vault_dir, "apt", file]) end
    selections_path = vault_path.("selections.txt")

    # Check if APT is installed
    case if(using_mock, do: :ok, else: ensure_apt_installed()) do
      {:error, _reason} ->
        # APT not installed, skip gracefully
        {:ok,
         %{
           summary: ["APT not installed, skipping"],
           stats: %{count: 0, total_size: 0}
         }}

      :ok ->
        if !File.exists?(selections_path) do
          {:ok,
           %{
             summary: ["APT selections not found in vault, skipping"],
             stats: %{count: 0, total_size: 0}
           }}
        else
          if dry_run do
            Progress.puts([
              "  ",
              Progress.tag("dry-run:", :light_black),
              " would restore APT packages from selections"
            ])

            {:ok,
             %{
               summary: ["Would restore APT packages"],
               stats: %{count: 0, total_size: 0}
             }}
          else
            # Restore sources if available
            restore_apt_sources(vault_path)

            # Restore package selections
            case System.cmd("dpkg", ["--set-selections"],
                   stderr_to_stdout: true,
                   input: File.read!(selections_path)
                 ) do
              {_output, 0} ->
                {:ok, size} = FileUtils.file_size(vault_path.("/"))

                {:ok,
                 %{
                   summary: [
                     "Restored APT package selections (run 'apt-get dselect-upgrade' to install)"
                   ],
                   stats: %{count: 1, total_size: size}
                 }}

              {error, _code} ->
                {:error, "Failed to restore APT selections: #{error}"}
            end
          end
        end
    end
  end

  @doc """
  Restores Snap packages from the specified vault directory.

  Reads the package lists from the vault and uses them to restore snaps.

  ## Parameters

    * `vault_dir` - Vault directory containing the snap/ subdirectory
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true only show what would be done

  ## Returns

    * `{:ok, result}` - Success with stats map
    * `{:error, reason}` - Failure with reason
  """
  def snap(vault_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    using_mock = Keyword.has_key?(opts, :cmd)
    vault_path = fn file -> Path.join([vault_dir, "snap", file]) end
    packages_path = vault_path.("packages.txt")

    # Check if Snap is installed
    case if(using_mock, do: :ok, else: ensure_snap_installed()) do
      {:error, _reason} ->
        # Snap not installed, skip gracefully
        {:ok,
         %{
           summary: ["Snap not installed, skipping"],
           stats: %{count: 0, total_size: 0}
         }}

      :ok ->
        if !File.exists?(packages_path) do
          {:ok,
           %{
             summary: ["Snap packages not found in vault, skipping"],
             stats: %{count: 0, total_size: 0}
           }}
        else
          if dry_run do
            Progress.puts([
              "  ",
              Progress.tag("dry-run:", :light_black),
              " would restore Snap packages"
            ])

            {:ok,
             %{
               summary: ["Would restore Snap packages"],
               stats: %{count: 0, total_size: 0}
             }}
          else
            # Read packages and install them
            packages =
              File.read!(packages_path)
              |> String.split("\n", trim: true)
              |> Enum.reject(&String.starts_with?(&1, "Name"))
              |> Enum.map(fn line ->
                line
                |> String.split(~r/\s+/, parts: 2)
                |> List.first()
              end)
              |> Enum.reject(&is_nil/1)
              |> Enum.reject(&(&1 == ""))

            success_count = install_snap_packages(packages)
            {:ok, size} = FileUtils.file_size(vault_path.("/"))

            {:ok,
             %{
               summary: [
                 "Restored #{success_count}/#{length(packages)} Snap packages (check output for failures)"
               ],
               stats: %{count: success_count, total_size: size}
             }}
          end
        end
    end
  end

  defp install_snap_packages(packages) do
    Enum.reduce(packages, 0, fn pkg, acc ->
      case System.cmd("snap", ["install", pkg], stderr_to_stdout: true) do
        {_output, 0} ->
          Progress.puts(["  ", Progress.tag("✓", :green), " Installed ", pkg])
          acc + 1

        {output, _code} ->
          if String.contains?(output, "already installed") do
            Progress.puts(["  ", Progress.tag("•", :light_black), " ", pkg, " already installed"])
            acc + 1
          else
            Progress.puts(["  ", Progress.tag("✗", :red), " Failed to install ", pkg])
            acc
          end
      end
    end)
  end

  defp restore_apt_sources(vault_path) do
    sources_file = vault_path.("sources.list")
    sources_dir = vault_path.("sources.list.d")

    # Restore sources.list if it exists (would need sudo, so we just inform the user)
    if File.exists?(sources_file) do
      Progress.puts([
        "  ",
        Progress.tag("Note:", :yellow),
        " APT sources found in vault. To restore, run:\n",
        "  sudo cp #{sources_file} /etc/apt/sources.list"
      ])
    end

    # Restore sources.list.d if it exists
    if File.exists?(sources_dir) and File.dir?(sources_dir) do
      Progress.puts([
        "  ",
        Progress.tag("Note:", :yellow),
        " APT sources.list.d found in vault. To restore, run:\n",
        "  sudo cp -r #{sources_dir}/* /etc/apt/sources.list.d/"
      ])
    end
  end

  defp ensure_homebrew_installed do
    case brew_cmd() do
      nil -> {:error, "Homebrew is not installed"}
      _path -> :ok
    end
  end

  defp ensure_apt_installed do
    case apt_cmd_path() do
      nil -> {:error, "APT is not installed"}
      _path -> :ok
    end
  end

  defmemo brew_cmd do
    System.find_executable("brew") ||
      if(File.exists?("/opt/homebrew/bin/brew"), do: "/opt/homebrew/bin/brew") ||
      if(File.exists?("/usr/local/bin/brew"), do: "/usr/local/bin/brew") ||
      nil
  end

  defmemo apt_cmd_path do
    System.find_executable("apt") ||
      if(File.exists?("/usr/bin/apt"), do: "/usr/bin/apt") ||
      nil
  end

  defp ensure_snap_installed do
    case snap_cmd_path() do
      nil -> {:error, "Snap is not installed"}
      _path -> :ok
    end
  end

  defmemo snap_cmd_path do
    System.find_executable("snap") ||
      if(File.exists?("/usr/bin/snap"), do: "/usr/bin/snap") ||
      nil
  end
end
