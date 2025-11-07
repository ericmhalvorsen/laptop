defmodule Vault.Backup.Config do
  @moduledoc """
  Handles backing up application configuration files.

  Backs up configurations from ~/.config/ directory including:
  - Git configuration
  - Mise configuration
  - Other important app configs

  These are stored in the git repository (not the vault).
  """

  alias Vault.Utils.FileUtils

  @doc """
  Returns the list of default config apps to back up.

  ## Examples

      iex> Vault.Backup.Config.default_configs()
      ["git", "mise", ...]
  """
  def default_configs do
    [
      "git",
      "mise"
    ]
  end

  @doc """
  Lists config apps that have files in .config directory in source.

  ## Examples

      iex> Vault.Backup.Config.list_configs("/home/user")
      ["git", "mise"]
  """
  def list_configs(source_dir) do
    config_dir = Path.join(source_dir, ".config")

    if File.dir?(config_dir) do
      default_configs()
      |> Enum.filter(fn app ->
        app_path = Path.join(config_dir, app)
        File.dir?(app_path) && has_files?(app_path)
      end)
    else
      []
    end
  end

  @doc """
  Backs up all configured apps from source .config to destination.

  ## Parameters

    * `source_dir` - Source directory (usually home directory)
    * `dest_dir` - Destination directory (usually repo's config/ dir)

  ## Returns

    * `{:ok, result}` - Success with backup statistics
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> Vault.Backup.Config.backup("~", "./config")
      {:ok, %{configs_backed_up: 2, total_size: 4096, backed_up_configs: [...]}}
  """
  def backup(source_dir, dest_dir) do
    with true <- File.dir?(source_dir) || {:error, "source directory does not exist: #{source_dir}"},
         :ok <- File.mkdir_p(dest_dir) do
      configs = list_configs(source_dir)

      results =
        Enum.map(configs, fn app ->
          backup_config(app, source_dir, dest_dir)
        end)

      configs_backed_up = Enum.count(results, &match?({:ok, _}, &1))

      total_size =
        results
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.flat_map(fn {:ok, result} -> [result.total_size] end)
        |> Enum.sum()

      backed_up_configs =
        results
        |> Enum.zip(configs)
        |> Enum.filter(fn {result, _app} -> match?({:ok, _}, result) end)
        |> Enum.map(fn {_result, app} -> app end)

      result = %{
        configs_backed_up: configs_backed_up,
        total_size: total_size,
        backed_up_configs: backed_up_configs
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "source directory does not exist: #{source_dir}"}
    end
  end

  @doc """
  Backs up a single config app from source to destination.

  ## Parameters

    * `app` - App name (e.g., "git", "mise")
    * `source_dir` - Source directory (usually home directory)
    * `dest_dir` - Destination directory

  ## Returns

    * `{:ok, result}` - Success with backup statistics
    * `{:error, reason}` - Failure with reason
  """
  def backup_config(app, source_dir, dest_dir) do
    source_config = Path.join([source_dir, ".config", app])
    dest_config = Path.join(dest_dir, app)

    if not File.dir?(source_config) do
      # Config doesn't exist in source, that's OK
      {:ok, %{files_copied: 0, total_size: 0}}
    else
      # Recursively copy the config directory
      with :ok <- File.mkdir_p(dest_config),
           {:ok, files} <- FileUtils.list_files_recursive(source_config) do
        if Enum.empty?(files) do
          {:ok, %{files_copied: 0, total_size: 0}}
        else
          results =
            Enum.map(files, fn file ->
              source_file = Path.join(source_config, file)
              dest_file = Path.join(dest_config, file)
              copy_file_with_size(source_file, dest_file)
            end)

          files_copied = Enum.count(results, &match?({:ok, _}, &1))

          total_size =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, size} -> size end)
            |> Enum.sum()

          {:ok, %{files_copied: files_copied, total_size: total_size}}
        end
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private functions

  defp has_files?(dir) do
    case FileUtils.list_files_recursive(dir) do
      {:ok, files} -> not Enum.empty?(files)
      {:error, _} -> false
    end
  end

  defp copy_file_with_size(source, dest) do
    with :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.cp(source, dest),
         {:ok, size} <- FileUtils.file_size(dest) do
      {:ok, size}
    end
  end
end
