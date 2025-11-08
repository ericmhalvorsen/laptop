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
  Backs up specified home directories to the vault.

  ## Parameters

    * `source_dir` - Home directory (usually System.user_home!())
    * `vault_path` - Vault directory path
    * `dirs` - List of directory names to backup (e.g., ["Documents", "Downloads"])
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true don't actually copy files
      * `:exclude` - Additional patterns to exclude

  ## Returns

    * `{:ok, result}` - Success with map containing:
      * `:backed_up` - List of directories that were backed up
      * `:skipped` - List of directories that were skipped (didn't exist)
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> HomeDirs.backup("/Users/eric", "/tmp/vault", ["Documents", "Downloads"])
      {:ok, %{backed_up: ["Documents", "Downloads"], skipped: []}}

      iex> HomeDirs.backup("/Users/eric", "/tmp/vault", ["Documents"], dry_run: true)
      {:ok, %{backed_up: ["Documents"], skipped: []}}
  """
  def backup(source_dir, vault_path, dirs, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    exclude = Keyword.get(opts, :exclude, []) ++ @exclude_patterns

    with {:ok, _} <- validate_source(source_dir),
         {:ok, _} <- maybe_create_home_dir(vault_path, dry_run) do
      result = process_directories(source_dir, vault_path, dirs, exclude, dry_run)
      {:ok, result}
    end
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
            case copy_directory(source_path, dest_path, exclude) do
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

  # Copy directory with exclusions
  defp copy_directory(source, dest, exclude_patterns) do
    # Remove destination if it exists (for clean copy)
    File.rm_rf(dest)

    # Copy recursively, filtering out excluded files
    copy_with_exclusions(source, dest, exclude_patterns)
  end

  # Recursively copy directory with exclusions
  defp copy_with_exclusions(source, dest, exclude_patterns) do
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
              copy_with_exclusions(source_path, dest_path, exclude_patterns)
            else
              # Copy file
              File.cp!(source_path, dest_path)
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
