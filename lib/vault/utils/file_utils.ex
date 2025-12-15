defmodule Vault.Utils.FileUtils do
  @moduledoc """
  Utility functions for file operations in Vault.
  """

  @doc """
  Checks if a path is a remote rsync target (e.g., user@host:/path).
  """
  def remote_target?(nil), do: false

  def remote_target?(path) when is_binary(path) do
    String.contains?(path, ":") and not String.starts_with?(path, "/")
  end

  @spec list_files_recursive(
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | char(),
              binary() | []
            )
        ) :: {:error, atom() | {:no_translation, binary()}} | {:ok, list()}
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

  @spec output_file(any(), any(), any()) ::
          {:error, <<_::64, _::_*8>>} | {:ok, :skipped | non_neg_integer()}
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

  @spec ensure_dir(any()) ::
          {:error, atom()}
          | {:ok,
             binary()
             | maybe_improper_list(
                 binary() | maybe_improper_list(any(), binary() | []) | char(),
                 binary() | []
               )}
  def ensure_dir(path), do: ensure_dir(path, false)

  @spec ensure_dir(any(), any()) ::
          {:error, atom()}
          | {:ok,
             binary()
             | maybe_improper_list(
                 binary() | maybe_improper_list(any(), binary() | []) | char(),
                 binary() | []
               )}
  def ensure_dir(_path, true), do: {:ok, "dry_run"}

  def ensure_dir(path, _) do
    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec expand_contents(binary(), nil | binary() | maybe_improper_list()) :: list()
  def expand_contents(contents, root) when is_binary(root) do
    expanded_root = expand_path(root)

    contents
    |> normalize_contents()
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
          entry
          |> expand_path(expanded_root)
          |> Path.wildcard()
          |> Enum.map(&Path.relative_to(&1, expanded_root))
      end
    end)
    |> Enum.uniq()
    |> Enum.map(&append_slash_if_dir(&1, expanded_root))
  end

  @spec expand_path(nil | binary(), nil | binary()) :: nil | binary()
  def expand_path(nil, nil), do: nil

  def expand_path(path, nil) do
    expand_path(path, File.cwd!())
  end

  def expand_path(path, root) when is_binary(path) do
    cond do
      remote_target?(path) ->
        path

      String.starts_with?(path, "~") ->
        Path.join(System.user_home!(), String.trim_leading(path, "~/"))

      String.starts_with?(path, "/") ->
        path

      true ->
        Path.expand("#{root}/#{path}")
    end
  end

  def expand_path(path), do: expand_path(path, File.cwd!())

  defp normalize_contents(nil), do: []
  defp normalize_contents(single) when is_binary(single), do: [single]
  defp normalize_contents(list) when is_list(list), do: list

  @spec file_size(
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | char(),
              binary() | []
            )
        ) :: {:error, atom()} | {:ok, :undefined | non_neg_integer()}
  def file_size(path) do
    case File.stat(path) do
      {:ok, %{type: :directory}} ->
        # For directories, use du which is much faster than recursive traversal
        case System.cmd("du", ["-sk", path], stderr_to_stdout: true) do
          {output, 0} ->
            size_kb =
              output
              |> String.split("\t")
              |> List.first()
              |> String.to_integer()

            {:ok, size_kb * 1024}

          _ ->
            {:ok, 0}
        end

      {:ok, %{size: size}} ->
        {:ok, size}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec format_size(non_neg_integer()) :: String.t()
  def format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  def format_size(bytes) when bytes < 1_073_741_824, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  def format_size(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  # Private

  @spec should_exclude?(binary(), list()) :: boolean()
  defp should_exclude?(entry, patterns) do
    Enum.any?(patterns, fn pattern ->
      String.contains?(entry, pattern) or entry == pattern
    end)
  end

  defp append_slash_if_dir(relative_path, root) do
    full_path = Path.join(root, relative_path)

    case File.dir?(full_path) do
      true -> relative_path <> "/"
      false -> relative_path
    end
  end
end
