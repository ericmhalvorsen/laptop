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
          regex_pattern = pattern
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
    with true <- File.dir?(source_dir) || {:error, "source directory does not exist: #{source_dir}"},
         :ok <- File.mkdir_p(dest_dir) do
      dotfiles = list_dotfiles(source_dir)

      # Start progress bar
      Owl.ProgressBar.start(
        id: :dotfiles,
        label: "  Dotfiles",
        total: length(dotfiles),
        bar_width_ratio: 0.5,
        filled_symbol: "█",
        partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
      )

      results =
        Enum.map(dotfiles, fn dotfile ->
          source = Path.join(source_dir, dotfile)
          dest = Path.join(dest_dir, dotfile)

          result =
            cond do
              File.dir?(source) -> copy_directory(source, dest)
              File.regular?(source) -> copy_with_size(source, dest)
              true -> {:error, :not_regular}
            end

          Owl.ProgressBar.inc(id: :dotfiles)
          result
        end)

      # Stop the LiveScreen to clear progress bar
      try do
        Owl.LiveScreen.stop()
      catch
        :exit, _ -> :ok
      end

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
          # Start progress bar
          Owl.ProgressBar.start(
            id: :local_bin,
            label: "  Scripts",
            total: length(files),
            bar_width_ratio: 0.5,
            filled_symbol: "█",
            partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
          )

          results =
            files
            |> Enum.map(fn file ->
              source = Path.join(local_bin_src, file)
              dest = Path.join(dest_dir, file)

              # Only backup regular files (not directories or symlinks)
              result =
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

              Owl.ProgressBar.inc(id: :local_bin)
              result
            end)

          # Stop the LiveScreen to clear progress bar
          try do
            Owl.LiveScreen.stop()
          catch
            :exit, _ -> :ok
          end

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

  defp copy_directory(source, dest) do
    with :ok <- File.mkdir_p(dest),
         {:ok, files} <- FileUtils.list_files_recursive(source) do
      results =
        Enum.map(files, fn file ->
          src_file = Path.join(source, file)
          dst_file = Path.join(dest, file)

          with :ok <- File.mkdir_p(Path.dirname(dst_file)),
               :ok <- File.cp(src_file, dst_file),
               {:ok, size} <- FileUtils.file_size(dst_file) do
            {:ok, size}
          end
        end)

      total_size =
        results
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, size} -> size end)
        |> Enum.sum()

      {:ok, total_size}
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
