defmodule Vault.Utils.FileUtils do
  @moduledoc """
  Utility functions for file operations in Vault.
  """

  @doc """
  Copies a file from source to destination, creating parent directories as needed.

  ## Examples

      iex> Vault.Utils.FileUtils.copy_file("/tmp/source.txt", "/tmp/dest.txt")
      {:ok, "/tmp/dest.txt"}
  """
  def copy_file(source, dest) do
    with true <- File.exists?(source) || {:error, :source_not_found},
         :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.cp(source, dest) do
      {:ok, dest}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :source_not_found}
    end
  end

  @doc """
  Copies multiple files from source directory to destination directory.

  ## Parameters

    * `source_dir` - Source directory path
    * `dest_dir` - Destination directory path
    * `files` - List of relative file paths to copy

  ## Returns

    * `{:ok, count}` - Success with number of files copied
    * `{:error, reason}` - Failure with reason
  """
  def copy_files(source_dir, dest_dir, files) when is_list(files) do
    results =
      Enum.map(files, fn file ->
        source = Path.join(source_dir, file)
        dest = Path.join(dest_dir, file)
        copy_file(source, dest)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, length(results)}
    else
      {:error, {:failed_copies, errors}}
    end
  end

  @doc """
  Lists all dotfiles in a directory (files starting with .).

  ## Examples

      iex> Vault.Utils.FileUtils.list_dotfiles("/home/user")
      {:ok, [".zshrc", ".gitconfig", ".vimrc"]}
  """
  def list_dotfiles(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        dotfiles =
          files
          |> Enum.filter(&dotfile?/1)
          |> Enum.sort()

        {:ok, dotfiles}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a filename is a dotfile (starts with .).
  """
  def dotfile?("." <> _rest), do: true
  def dotfile?(_), do: false

  @doc """
  Recursively lists all files in a directory.

  ## Options

    * `:exclude` - List of patterns to exclude (supports wildcards)
  """
  def list_files_recursive(dir, opts \\ []) do
    exclude_patterns = Keyword.get(opts, :exclude, [])

    case File.ls(dir) do
      {:ok, entries} ->
        files =
          entries
          |> Enum.flat_map(fn entry ->
            full_path = Path.join(dir, entry)

            if should_exclude?(entry, exclude_patterns) do
              []
            else
              if File.dir?(full_path) do
                case list_files_recursive(full_path, opts) do
                  {:ok, nested_files} ->
                    Enum.map(nested_files, &Path.join(entry, &1))

                  {:error, _} ->
                    []
                end
              else
                [entry]
              end
            end
          end)

        {:ok, files}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Ensures a directory exists, creating it if necessary.
  """
  def ensure_dir(path) do
    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets file size in bytes.
  """
  def file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Formats file size in human-readable format.

  ## Examples

      iex> Vault.Utils.FileUtils.format_size(1024)
      "1.0 KB"

      iex> Vault.Utils.FileUtils.format_size(1_048_576)
      "1.0 MB"
  """
  def format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  def format_size(bytes) when bytes < 1_073_741_824, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  def format_size(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  # Private functions

  defp should_exclude?(entry, patterns) do
    Enum.any?(patterns, fn pattern ->
      String.contains?(entry, pattern) or entry == pattern
    end)
  end
end
