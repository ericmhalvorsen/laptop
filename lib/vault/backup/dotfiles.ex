defmodule Vault.Backup.Dotfiles do
  @moduledoc """
  Handles backing up dotfiles and local scripts.

  This module backs up:
  - Common dotfiles (.zshrc, .bashrc, .gitconfig, etc.)
  - Scripts from ~/.local/bin

  Files are backed up to the git repository (not the vault).
  """

  alias Vault.UI.Progress

  @doc """
  Lists all dotfiles and dot directories in the given directory.
  Excludes items matching patterns in .vaultignore.
  """
  def list_dotfiles(source_dir) do
    ignore_patterns = load_ignore_patterns()

    case File.ls(source_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&dotfile?/1)
        |> Enum.reject(&should_ignore?(&1, ignore_patterns))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  defp dotfile?("." <> _rest), do: true
  defp dotfile?(_), do: false

  defp load_ignore_patterns do
    ignore_file = Path.join([File.cwd!(), ".vaultignore"])

    if File.exists?(ignore_file) do
      File.read!(ignore_file)
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))
    else
      []
    end
  end

  defp should_ignore?(item, patterns) do
    Enum.any?(patterns, fn pattern ->
      cond do
        String.contains?(pattern, "*") ->
          regex_pattern =
            pattern
            |> String.replace(".", "\\.")
            |> String.replace("*", ".*")
            |> then(&("^" <> &1 <> "$"))

          case Regex.compile(regex_pattern) do
            {:ok, regex} -> Regex.match?(regex, item)
            _ -> false
          end

        true ->
          item == pattern
      end
    end)
  end

  @doc """
  Backs up dotfiles from source directory to destination directory.

  ## Parameters

    * `source_dir` - Source directory (usually home directory)
    * `dest_dir` - Destination directory (usually repo's dotfiles/ dir)

  ## Returns

    * `{:ok, result}` - Success with backup statistics
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> Vault.Backup.Dotfiles.backup("~", "./dotfiles")
      {:ok, %{files_copied: 5, files_skipped: 3, total_size: 12345, backed_up_files: [...]}}
  """
  def backup(source_dir, dest_dir) do
    with true <-
           File.dir?(source_dir) || {:error, "source directory does not exist: #{source_dir}"},
         :ok <- File.mkdir_p(dest_dir) do
      dotfiles = list_dotfiles(source_dir)

      if Enum.empty?(dotfiles) do
        {:ok,
         %{
           files_copied: 0,
           files_skipped: 0,
           total_size: 0,
           backed_up_files: []
         }}
      else
        Progress.start_progress(:dotfiles, "  Dotfiles", length(dotfiles))

        results =
          Enum.map(dotfiles, fn dotfile ->
            source = Path.join(source_dir, dotfile)
            dest = Path.join(dest_dir, dotfile)
            Progress.set_detail(:dotfiles, dotfile)

            result =
              cond do
                File.dir?(source) ->
                  Vault.Sync.copy_tree(source, dest, return_total_size: true)

                File.regular?(source) ->
                  Vault.Sync.copy_file(source, dest, return_size: true)

                true ->
                  {:error, :not_regular}
              end

            Progress.increment(:dotfiles)
            result
          end)

        files_copied = Enum.count(results, &match?({:ok, _}, &1))
        files_skipped = Enum.count(results, &match?({:error, _}, &1))

        total_size =
          results
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, size} -> size end)
          |> Enum.sum()

        backed_up_files =
          results
          |> Enum.zip(dotfiles)
          |> Enum.filter(fn {result, _file} -> match?({:ok, _size}, result) end)
          |> Enum.map(fn {_result, file} -> file end)

        result = %{
          files_copied: files_copied,
          files_skipped: files_skipped,
          total_size: total_size,
          backed_up_files: backed_up_files
        }

        {:ok, result}
      end
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "source directory does not exist: #{source_dir}"}
    end
  end

  @doc """
  Backs up scripts from ~/.local/bin to destination directory.

  ## Parameters

    * `source_dir` - Home directory (will look for .local/bin inside)
    * `dest_dir` - Destination directory for scripts

  ## Returns

    * `{:ok, result}` - Success with backup statistics
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> Vault.Backup.Dotfiles.backup_local_bin("~", "./local-bin")
      {:ok, %{files_copied: 3, files_skipped: 0, total_size: 8192, backed_up_files: [...]}}
  """
  def backup_local_bin(home_dir, dest_dir) do
    local_bin_src = Path.join([home_dir, ".local", "bin"])

    # If .local/bin doesn't exist, that's OK - return success with 0 files
    if not File.dir?(local_bin_src) do
      return_empty_result()
    else
      with :ok <- File.mkdir_p(dest_dir),
           {:ok, files} <- File.ls(local_bin_src) do
        if Enum.empty?(files) do
          return_empty_result()
        else
          Progress.start_progress(:local_bin, "  Scripts", length(files))

          results =
            files
            |> Enum.map(fn file ->
              source = Path.join(local_bin_src, file)
              dest = Path.join(dest_dir, file)
              Progress.set_detail(:local_bin, file)

              # Only backup regular files (not directories or symlinks)
              result =
                cond do
                  not File.exists?(source) ->
                    {:skipped, :not_found}

                  File.dir?(source) ->
                    {:skipped, :is_directory}

                  File.regular?(source) ->
                    case Vault.Sync.copy_file(source, dest,
                           preserve_permissions: true,
                           return_size: true
                         ) do
                      {:ok, size} -> {:ok, {file, size}}
                      error -> error
                    end

                  true ->
                    {:skipped, :not_regular_file}
                end

              Progress.increment(:local_bin)
              result
            end)

          files_copied = Enum.count(results, &match?({:ok, _}, &1))
          files_skipped = Enum.count(results, fn r -> not match?({:ok, _}, r) end)

          total_size =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, {_file, size}} -> size end)
            |> Enum.sum()

          backed_up_files =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, {file, _size}} -> file end)

          result = %{
            files_copied: files_copied,
            files_skipped: files_skipped,
            total_size: total_size,
            backed_up_files: backed_up_files
          }

          {:ok, result}
        end
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Backs up mise.toml from home directory to destination directory.

  ## Parameters

    * `home_dir` - Home directory
    * `dest_dir` - Destination directory for mise.toml

  ## Returns

    * `{:ok, result}` - Success with backup statistics
    * `{:error, reason}` - Failure with reason
  """
  def backup_mise_toml(home_dir, dest_dir) do
    mise_source = Path.join(home_dir, "mise.toml")

    if not File.exists?(mise_source) do
      {:ok, %{files_copied: 0, total_size: 0}}
    else
      File.mkdir_p!(dest_dir)
      mise_dest = Path.join(dest_dir, "mise.toml")

      case Vault.Sync.copy_file(mise_source, mise_dest) do
        :ok ->
          case File.stat(mise_dest) do
            {:ok, stat} ->
              {:ok, %{files_copied: 1, total_size: stat.size}}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Private functions

  defp return_empty_result do
    {:ok,
     %{
       files_copied: 0,
       files_skipped: 0,
       total_size: 0,
       backed_up_files: []
     }}
  end
end
