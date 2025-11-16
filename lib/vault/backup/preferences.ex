defmodule Vault.Backup.Preferences do
  @moduledoc """
  Backs up macOS Library/Preferences to vault.
  """

  alias Vault.UI.Progress

  @doc """
  Backs up Library/Preferences directory to the vault.

  ## Parameters

    * `home_dir` - Home directory path
    * `vault_path` - Vault directory path

  ## Returns

    * `{:ok, result}` - Success with map containing:
      * `:files_copied` - Number of preference files backed up
      * `:total_size` - Total size in bytes
    * `{:error, reason}` - Failure with reason
  """
  def backup(home_dir, vault_path) do
    prefs_source = Path.join([home_dir, "Library", "Preferences"])
    prefs_dest = Path.join([vault_path, "preferences"])

    exclude_patterns = [
      "com.apple.",
      ".GlobalPreferences",
      "MobileMeAccounts.plist",
      "networkservices.plist",
      "ByHost/"
    ]

    if not File.dir?(prefs_source) do
      {:ok, %{files_copied: 0, total_size: 0}}
    else
      File.mkdir_p!(prefs_dest)

      case File.ls(prefs_source) do
        {:ok, entries} ->
          plist_files =
            entries
            |> Enum.filter(fn entry ->
              path = Path.join(prefs_source, entry)
              File.regular?(path) and String.ends_with?(entry, ".plist") and
                not should_exclude?(entry, exclude_patterns)
            end)
            |> Enum.sort()

          if Enum.empty?(plist_files) do
            {:ok, %{files_copied: 0, total_size: 0}}
          else
            Progress.start_progress(:preferences, "  Preferences", length(plist_files))

            results =
              plist_files
              |> Enum.map(fn plist ->
                source = Path.join(prefs_source, plist)
                dest = Path.join(prefs_dest, plist)

                result =
                  case Vault.Sync.copy_file(source, dest) do
                    :ok ->
                      case File.stat(dest) do
                        {:ok, stat} -> {:ok, stat.size}
                        {:error, _} -> {:error, :stat_failed}
                      end

                    {:error, _reason} ->
                      {:error, :copy_failed}
                  end

                Progress.increment(:preferences)
                result
              end)

            files_copied = Enum.count(results, &match?({:ok, _}, &1))

            total_size =
              results
              |> Enum.filter(&match?({:ok, _}, &1))
              |> Enum.map(fn {:ok, size} -> size end)
              |> Enum.sum()

            {:ok, %{files_copied: files_copied, total_size: total_size}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp should_exclude?(name, exclude_patterns) do
    Enum.any?(exclude_patterns, fn pattern ->
      String.contains?(name, pattern)
    end)
  end
end
