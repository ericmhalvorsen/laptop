defmodule Vault.Backup.AppSupport do
  @moduledoc """
  Backs up Application Support data to vault.
  """

  alias Vault.UI.Progress

  @doc """
  Backs up Application Support directory to the vault.

  ## Parameters

    * `home_dir` - Home directory path
    * `vault_path` - Vault directory path
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true don't actually copy files
      * `:exclude` - Additional patterns to exclude

  ## Returns

    * `{:ok, result}` - Success with map containing:
      * `:backed_up` - List of app directories that were backed up
      * `:total_size` - Total size in bytes
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> AppSupport.backup("/Users/eric", "/tmp/vault")
      {:ok, %{backed_up: ["Claude", "Obsidian"], total_size: 104857600}}
  """
  def backup(home_dir, vault_path, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    extra_exclude = Keyword.get(opts, :exclude, [])

    app_support_source = Path.join([home_dir, "Library", "Application Support"])
    app_support_dest = Path.join([vault_path, "app-support"])

    exclude_patterns = [
      ".DS_Store",
      "CrashReporter",
      "com.apple.",
      "Google/Chrome/Safe Browsing",
      "Google/Chrome/GrShaderCache",
      "Caches",
      "GPUCache",
      "ShaderCache"
    ] ++ extra_exclude

    if not File.dir?(app_support_source) do
      {:ok, %{backed_up: [], total_size: 0}}
    else
      with {:ok, entries} <- File.ls(app_support_source),
           :ok <- maybe_create_dest(app_support_dest, dry_run) do
        app_dirs =
          entries
          |> Enum.filter(fn entry ->
            path = Path.join(app_support_source, entry)
            File.dir?(path) and not should_exclude?(entry, exclude_patterns)
          end)
          |> Enum.sort()

        if Enum.empty?(app_dirs) or dry_run do
          {:ok, %{backed_up: [], total_size: 0}}
        else
          Progress.start_progress(:app_support, "  Application Support", length(app_dirs))

          results =
            app_dirs
            |> Enum.map(fn app_dir ->
              source = Path.join(app_support_source, app_dir)
              dest = Path.join(app_support_dest, app_dir)

              result =
                case Vault.Sync.copy_tree(source, dest, return_total_size: true) do
                  {:ok, size} -> {:ok, {app_dir, size}}
                  _ -> {:skipped, app_dir}
                end

              Progress.increment(:app_support)
              result
            end)

          backed_up =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, {app_dir, _size}} -> app_dir end)

          total_size =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, {_app_dir, size}} -> size end)
            |> Enum.sum()

          {:ok, %{backed_up: backed_up, total_size: total_size}}
        end
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp maybe_create_dest(_dest, true), do: :ok

  defp maybe_create_dest(dest, false) do
    File.mkdir_p(dest)
  end

  defp should_exclude?(name, exclude_patterns) do
    Enum.any?(exclude_patterns, fn pattern ->
      cond do
        String.contains?(pattern, "*") ->
          # Simple glob matching
          regex_pattern =
            pattern
            |> String.replace(".", "\\.")
            |> String.replace("*", ".*")
            |> then(&("^" <> &1))

          case Regex.compile(regex_pattern) do
            {:ok, regex} -> Regex.match?(regex, name)
            _ -> false
          end

        true ->
          String.contains?(name, pattern)
      end
    end)
  end

  # no private sizing helpers needed; Vault.Sync returns sizes on request
end
