defmodule Vault.Backup.Dotfiles do
  @moduledoc """
  Handles backing up dotfiles and local scripts.

  This module backs up:
  - Common dotfiles (.zshrc, .bashrc, .gitconfig, etc.)
  - Scripts from ~/.local/bin

  Files are backed up to the git repository (not the vault).
  """

  alias Vault.Utils.FileUtils

  @doc """
  Returns the list of default dotfiles to back up.

  ## Examples

      iex> Vault.Backup.Dotfiles.default_dotfiles()
      [".zshrc", ".bashrc", ".gitconfig", ...]
  """
  def default_dotfiles do
    [
      ".zshrc",
      ".zshenv",
      ".zprofile",
      ".bashrc",
      ".bash_profile",
      ".gitconfig",
      ".vimrc",
      ".irbrc",
      ".tmux.conf"
    ]
  end

  @doc """
  Lists dotfiles that exist in the given directory.

  Only returns files from the default_dotfiles/0 list that actually exist.

  ## Examples

      iex> Vault.Backup.Dotfiles.list_dotfiles("/home/user")
      [".zshrc", ".gitconfig"]
  """
  def list_dotfiles(source_dir) do
    default_dotfiles()
    |> Enum.filter(fn dotfile ->
      Path.join(source_dir, dotfile) |> File.exists?()
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
    with true <- File.dir?(source_dir) || {:error, "source directory does not exist: #{source_dir}"},
         :ok <- File.mkdir_p(dest_dir) do
      dotfiles = list_dotfiles(source_dir)

      results =
        Enum.map(dotfiles, fn dotfile ->
          source = Path.join(source_dir, dotfile)
          dest = Path.join(dest_dir, dotfile)
          copy_with_size(source, dest)
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
          results =
            files
            |> Enum.map(fn file ->
              source = Path.join(local_bin_src, file)
              dest = Path.join(dest_dir, file)

              # Only backup regular files (not directories or symlinks)
              cond do
                not File.exists?(source) ->
                  {:skipped, :not_found}

                File.dir?(source) ->
                  {:skipped, :is_directory}

                File.regular?(source) ->
                  case copy_with_permissions(source, dest) do
                    {:ok, size} -> {:ok, {file, size}}
                    error -> error
                  end

                true ->
                  {:skipped, :not_regular_file}
              end
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

  # Private functions

  defp copy_with_size(source, dest) do
    with {:ok, _} <- FileUtils.copy_file(source, dest),
         {:ok, size} <- FileUtils.file_size(dest) do
      {:ok, size}
    end
  end

  defp copy_with_permissions(source, dest) do
    with {:ok, stat} <- File.stat(source),
         :ok <- File.cp(source, dest),
         :ok <- File.chmod(dest, stat.mode),
         {:ok, size} <- FileUtils.file_size(dest) do
      {:ok, size}
    end
  end

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
