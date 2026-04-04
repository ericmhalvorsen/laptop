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
    cmd_fun = Keyword.get(opts, :cmd, &System.cmd/3)
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
            # Ensure sudo is authenticated once up-front so we can safely run multiple commands.
            with :ok <- ensure_sudo(cmd_fun),
                 :ok <- restore_apt_sources(vault_path, cmd_fun),
                 selections <- File.read!(selections_path),
                 {:ok, _output} <- dpkg_set_selections(selections, cmd_fun),
                 {:ok, _output} <- apt_update(cmd_fun),
                 {:ok, _output} <- apt_dselect_upgrade(cmd_fun) do
              {:ok, size} = FileUtils.file_size(vault_path.("/"))

              {:ok,
               %{
                 summary: ["Restored APT packages"],
                 stats: %{count: 1, total_size: size}
               }}
            else
              {:error, reason} when is_binary(reason) ->
                {:error, reason}

              {:error, reason} ->
                {:error, reason}
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

  defp install_snap_packages([]) do
    0
  end

  defp install_snap_packages(packages) do
    case System.cmd("snap", ["install" | packages], stderr_to_stdout: true) do
      {output, 0} ->
        # If exit code is 0, all packages were installed (or were already installed) successfully.
        Enum.each(packages, fn pkg ->
          if String.contains?(output, "#{pkg} already installed") do
            Progress.puts(["  ", Progress.tag("•", :light_black), " ", pkg, " already installed"])
          else
            Progress.puts(["  ", Progress.tag("✓", :green), " Installed ", pkg])
          end
        end)

        length(packages)

      {_output, _code} ->
        # If the batch install failed, we could fall back to installing one by one
        # to ensure we install as many as possible, but batch failure might mean a global issue.
        # Given we want to maximize restoring, let's just fall back to sequential install.
        Progress.puts([
          "  ",
          Progress.tag("!", :yellow),
          " Batch install failed, falling back to sequential install..."
        ])

        Enum.reduce(packages, 0, fn pkg, acc ->
          case System.cmd("snap", ["install", pkg], stderr_to_stdout: true) do
            {_output, 0} ->
              Progress.puts(["  ", Progress.tag("✓", :green), " Installed ", pkg])
              acc + 1

            {pkg_output, _code} ->
              if String.contains?(pkg_output, "already installed") do
                Progress.puts([
                  "  ",
                  Progress.tag("•", :light_black),
                  " ",
                  pkg,
                  " already installed"
                ])

                acc + 1
              else
                Progress.puts(["  ", Progress.tag("✗", :red), " Failed to install ", pkg])
                acc
              end
          end
        end)
    end
  end

  defp restore_apt_sources(vault_path, cmd_fun) do
    sources_file = vault_path.("sources.list")
    sources_dir = vault_path.("sources.list.d")

    backup_dir =
      if File.exists?(sources_file) or (File.exists?(sources_dir) and File.dir?(sources_dir)) do
        case backup_apt_sources(cmd_fun) do
          {:ok, dir} ->
            Progress.puts([
              "  ",
              Progress.tag("✓", :green),
              " Backed up current APT configuration to #{dir}"
            ])

            Progress.puts([
              "  ",
              Progress.tag("Note:", :yellow),
              " If APT restore fails, restore your original configuration with:\n",
              "  sudo cp -a #{dir}/* /etc/apt/"
            ])

            dir

          {:error, _reason} ->
            Progress.puts([
              "  ",
              Progress.tag("Note:", :yellow),
              " Could not back up current APT configuration; proceeding without backup"
            ])

            nil
        end
      else
        nil
      end

    sources_was_restored =
      if File.exists?(sources_file) do
        restore_apt_sources_file(sources_file, cmd_fun)
      else
        false
      end

    dir_was_restored =
      if File.exists?(sources_dir) and File.dir?(sources_dir) do
        restore_apt_sources_dir(sources_dir, cmd_fun)
      else
        false
      end

    _ = backup_dir

    if sources_was_restored or dir_was_restored do
      Progress.puts(["  ", Progress.tag("✓", :green), " Restored APT sources"])
    end

    :ok
  end

  defp ensure_sudo(cmd_fun) do
    case cmd_fun.("sudo", ["-n", "true"], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {_output, _code} ->
        case cmd_fun.("sudo", ["-v"], stderr_to_stdout: true) do
          {_output, 0} ->
            :ok

          {output, _code} ->
            {:error,
             "sudo authentication failed. If you're running without a TTY (e.g. from a non-interactive runner), run 'sudo -v' in a terminal first, then re-run. Details: #{output}"}
        end
    end
  end

  defp backup_apt_sources(cmd_fun) do
    timestamp =
      DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.replace(~r/[^0-9]/, "")

    backup_dir = "/etc/apt/backups/backup_#{timestamp}"

    # Create backup directory
    case cmd_fun.("sudo", ["mkdir", "-p", backup_dir], stderr_to_stdout: true) do
      {_, 0} ->
        # Backup sources.list if it exists
        if File.exists?("/etc/apt/sources.list") do
          case cmd_fun.("sudo", ["cp", "-a", "/etc/apt/sources.list", "#{backup_dir}/"],
                 stderr_to_stdout: true
               ) do
            {_, 0} -> :ok
            _ -> :error
          end
        end

        # Backup sources.list.d if it exists
        if File.exists?("/etc/apt/sources.list.d") do
          case cmd_fun.("sudo", ["cp", "-a", "/etc/apt/sources.list.d", "#{backup_dir}/"],
                 stderr_to_stdout: true
               ) do
            {_, 0} -> :ok
            _ -> :error
          end
        end

        {:ok, backup_dir}

      {_error, _} ->
        Progress.puts([
          "  ",
          Progress.tag("!", :yellow),
          " Failed to create backup directory: #{backup_dir}"
        ])

        {:error, :backup_failed}
    end
  end

  defp restore_apt_sources_file(sources_file, cmd_fun) do
    dest = "/etc/apt/sources.list"

    case cmd_fun.("sudo", ["cp", "-a", sources_file, dest], stderr_to_stdout: true) do
      {_output, 0} ->
        true

      {output, _code} ->
        Progress.puts([
          "  ",
          Progress.tag("Note:", :yellow),
          " APT sources found in vault but could not be restored automatically. To restore, run:\n",
          "  sudo cp #{sources_file} #{dest}\n",
          "  ",
          Progress.tag("Reason:", :yellow),
          " ",
          output
        ])

        false
    end
  end

  defp restore_apt_sources_dir(sources_dir, cmd_fun) do
    dest_dir = "/etc/apt/sources.list.d"

    case cmd_fun.("sudo", ["mkdir", "-p", dest_dir], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {_output, _code} ->
        :ok
    end

    # Copy contents (avoids shell globbing)
    case cmd_fun.("sudo", ["cp", "-a", sources_dir <> "/.", dest_dir <> "/"],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        true

      {output, _code} ->
        Progress.puts([
          "  ",
          Progress.tag("Note:", :yellow),
          " APT sources.list.d found in vault but could not be restored automatically. To restore, run:\n",
          "  sudo cp -a #{sources_dir}/. #{dest_dir}/\n",
          "  ",
          Progress.tag("Reason:", :yellow),
          " ",
          output
        ])

        false
    end
  end

  defp dpkg_set_selections(selections, cmd_fun) do
    if cmd_fun != (&System.cmd/3) do
      case cmd_fun.("dpkg", ["--set-selections"], stderr_to_stdout: true) do
        {_output, 0} -> {:ok, ""}
        {output, _code} -> {:error, "Failed to restore APT selections: #{output}"}
      end
    else
      dpkg = System.find_executable("dpkg") || "dpkg"

      port =
        Port.open({:spawn_executable, dpkg}, [
          :binary,
          :exit_status,
          {:args, ["--set-selections"]},
          :stderr_to_stdout
        ])

      send(port, {self(), {:command, selections}})
      send(port, {self(), :close})
      gather_port_output(port, "Failed to restore APT selections")
    end
  end

  defp apt_update(cmd_fun) do
    case cmd_fun.("sudo", ["apt-get", "update"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _code} -> {:error, "Failed to run apt-get update: #{output}"}
    end
  end

  defp apt_dselect_upgrade(cmd_fun) do
    case cmd_fun.("sudo", ["apt-get", "-y", "dselect-upgrade"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _code} -> {:error, "Failed to install APT packages (dselect-upgrade): #{output}"}
    end
  end

  defp gather_port_output(port, error_prefix) do
    gather_port_output(port, error_prefix, "")
  end

  defp gather_port_output(port, error_prefix, acc) do
    receive do
      {^port, {:data, data}} ->
        gather_port_output(port, error_prefix, acc <> data)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, code}} ->
        {:error, "#{error_prefix}: #{acc} (exit #{code})"}
    after
      60_000 ->
        Port.close(port)
        {:error, "#{error_prefix}: timed out"}
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
