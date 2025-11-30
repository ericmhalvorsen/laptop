defmodule Vault.Utils.FileUtils do
  @moduledoc """
  Utility functions for file operations in Vault.
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
                  {:ok, nested_files} -> Enum.map(nested_files, &Path.join(entry, &1))
                  {:error, _} -> []
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

  def output_file(dest, lines, dry_run) do
    if dry_run do
      {:ok, :skipped}
    else
      content = Enum.join(lines, "\n") <> "\n"

      case File.write(dest, content) do
        :ok -> {:ok, length(lines)}
        {:error, reason} -> {:error, "Failed to write #{dest}: #{reason}"}
      end
    end
  end

  def ensure_dir(_path, true), do: {:ok, "dry_run"}

  def ensure_dir(path, _) do
    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  def expand_contents(root, contents) when is_binary(root) and is_list(contents) do
    expanded_root = Path.expand(root)

    contents
    |> Enum.flat_map(fn entry ->
      case String.contains?(entry, "*") do
        true ->
          pattern =
            if Path.type(entry) == :absolute do
              entry
            else
              Path.join(expanded_root, entry)
            end

          pattern
          |> Path.wildcard()
          |> Enum.map(&Path.relative_to(&1, expanded_root))

        false ->
          [normalize_relative(entry)]
      end
    end)
    |> Enum.uniq()
  end

  defp normalize_relative(path) do
    cond do
      Path.type(path) == :absolute ->
        path

      String.starts_with?(path, "./") ->
        String.trim_leading(path, "./")

      true ->
        path
    end
  end

  def file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, reason}
    end
  end

  def format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  def format_size(bytes) when bytes < 1_073_741_824, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  def format_size(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  # Private

  defp should_exclude?(entry, patterns) do
    Enum.any?(patterns, fn pattern ->
      String.contains?(entry, pattern) or entry == pattern
    end)
  end
end
