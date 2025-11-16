defmodule Vault.Backup.Sensitive do
  @moduledoc """
  Backs up sensitive files (SSH keys, GPG keys, AWS credentials, passwords).

  All files are backed up to vault/sensitive/ directory.
  """

  alias Vault.UI.Progress

  @doc """
  Backs up all sensitive data to the vault.

  ## Parameters

    * `home_dir` - Home directory path
    * `vault_path` - Vault directory path

  ## Returns

    * `{:ok, result}` - Success with map containing:
      * `:backed_up` - List of items that were backed up
      * `:total_size` - Total size in bytes
    * `{:error, reason}` - Failure with reason
  """
  def backup(home_dir, vault_path) do
    sensitive_dest = Path.join([vault_path, "sensitive"])
    File.mkdir_p!(sensitive_dest)

    items = [
      {".ssh", "SSH keys"},
      {".gnupg", "GPG keys"},
      {".aws", "AWS credentials"},
      {".config/private", "Passwords"}
    ]

    Progress.start_progress(:sensitive, "  Sensitive Files", length(items))

    results =
      items
      |> Enum.map(fn {rel_path, label} ->
        source = Path.join(home_dir, rel_path)
        dest = Path.join(sensitive_dest, Path.basename(rel_path))

        result =
          cond do
            not File.exists?(source) ->
              {:skipped, label}

            File.dir?(source) ->
              case copy_directory(source, dest) do
                :ok ->
                  size = calculate_directory_size(dest)
                  {:ok, {label, size}}

                _ ->
                  {:skipped, label}
              end

            File.regular?(source) ->
              case Vault.Sync.copy_file(source, dest) do
                :ok ->
                  {:ok, stat} = File.stat(dest)
                  {:ok, {label, stat.size}}

                {:error, _reason} ->
                  {:skipped, label}
              end

            true ->
              {:skipped, label}
          end

        Progress.increment(:sensitive)
        result
      end)

    backed_up =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, {label, _size}} -> label end)

    total_size =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, {_label, size}} -> size end)
      |> Enum.sum()

    {:ok, %{backed_up: backed_up, total_size: total_size}}
  end

  defp copy_directory(source, dest) do
    File.rm_rf(dest)
    Vault.Sync.copy_tree(source, dest)
  end

  defp calculate_directory_size(path) do
    case File.ls(path) do
      {:ok, entries} ->
        Enum.reduce(entries, 0, fn entry, acc ->
          entry_path = Path.join(path, entry)

          if File.dir?(entry_path) do
            acc + calculate_directory_size(entry_path)
          else
            case File.stat(entry_path) do
              {:ok, stat} -> acc + stat.size
              _ -> acc
            end
          end
        end)

      _ ->
        0
    end
  end
end
