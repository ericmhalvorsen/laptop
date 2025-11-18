defmodule Vault.Backup.Homebrew do
  @moduledoc """
  Handles backup of Homebrew packages, casks, and taps.
  """

  @doc """
  Backs up Homebrew data to the specified destination directory.

  Creates a `brew/` subdirectory in the destination and saves:
  - Brewfile (via `brew bundle dump`)
  - formulas.txt (via `brew list --formula`)
  - casks.txt (via `brew list --cask`)
  - taps.txt (via `brew tap`)

  ## Parameters

    * `dest_dir` - Destination directory for the backup
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true only count packages without writing files

  ## Returns

    * `{:ok, result}` - Success with counts map containing:
      * `:brewfile` - Boolean indicating Brewfile was created
      * `:formulas` - Count of formula packages
      * `:casks` - Count of cask applications
      * `:taps` - Count of tapped repositories
    * `{:error, reason}` - Failure with reason
  """
  def backup(dest_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    cmd_fun = Keyword.get(opts, :cmd, &System.cmd/3)
    using_mock = Keyword.has_key?(opts, :cmd)
    brew = brew_cmd() || "brew"

    with :ok <- if(using_mock, do: :ok, else: ensure_homebrew_installed()),
         {:ok, formulas} <- list_formulas(cmd_fun, brew),
         {:ok, casks} <- list_casks(cmd_fun, brew),
         {:ok, taps} <- list_taps(cmd_fun, brew),
         {:ok, _} <- maybe_create_directory(dest_dir, dry_run),
         {:ok, brewfile_created} <- maybe_create_brewfile(dest_dir, dry_run, cmd_fun, brew),
         {:ok, _} <- maybe_write_formulas(dest_dir, formulas, dry_run),
         {:ok, _} <- maybe_write_casks(dest_dir, casks, dry_run),
         {:ok, _} <- maybe_write_taps(dest_dir, taps, dry_run) do
      {:ok,
       %{
         brewfile: brewfile_created,
         formulas: length(formulas),
         casks: length(casks),
         taps: length(taps)
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_homebrew_installed do
    case brew_cmd() do
      nil -> {:error, "Homebrew is not installed"}
      _path -> {:ok, :installed}
    end
  end

  defp ensure_homebrew_installed do
    case check_homebrew_installed() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp brew_cmd do
    System.find_executable("brew") ||
      if(File.exists?("/opt/homebrew/bin/brew"), do: "/opt/homebrew/bin/brew") ||
      if(File.exists?("/usr/local/bin/brew"), do: "/usr/local/bin/brew") ||
      nil
  end

  defp list_formulas(cmd_fun, brew) do
    case cmd_fun.(brew, ["list", "--formula"], stderr_to_stdout: true) do
      {output, 0} ->
        formulas =
          output
          |> String.split("\n", trim: true)

        {:ok, formulas}

      {error, _code} ->
        {:error, "Failed to list formulas: #{error}"}
    end
  end

  defp list_casks(cmd_fun, brew) do
    case cmd_fun.(brew, ["list", "--cask"], stderr_to_stdout: true) do
      {output, 0} ->
        casks =
          output
          |> String.split("\n", trim: true)

        {:ok, casks}

      {error, _code} ->
        {:error, "Failed to list casks: #{error}"}
    end
  end

  defp list_taps(cmd_fun, brew) do
    case cmd_fun.(brew, ["tap"], stderr_to_stdout: true) do
      {output, 0} ->
        taps =
          output
          |> String.split("\n", trim: true)

        {:ok, taps}

      {error, _code} ->
        {:error, "Failed to list taps: #{error}"}
    end
  end

  defp maybe_create_directory(dest_dir, dry_run) do
    if dry_run do
      {:ok, :skipped}
    else
      brew_dir = Path.join(dest_dir, "brew")

      case File.mkdir_p(brew_dir) do
        :ok -> {:ok, brew_dir}
        {:error, reason} -> {:error, "Failed to create brew directory: #{reason}"}
      end
    end
  end

  defp maybe_create_brewfile(dest_dir, dry_run, cmd_fun, brew) do
    if dry_run do
      {:ok, false}
    else
      brew_dir = Path.join(dest_dir, "brew")
      brewfile_path = Path.join(brew_dir, "Brewfile")

      # Remove existing Brewfile if present (brew bundle dump --force would work too)
      File.rm(brewfile_path)

      case cmd_fun.(brew, ["bundle", "dump", "--file=#{brewfile_path}"], stderr_to_stdout: true) do
        {_output, 0} ->
          {:ok, true}

        {error, _code} ->
          {:error, "Failed to create Brewfile: #{error}"}
      end
    end
  end

  defp maybe_write_formulas(dest_dir, formulas, dry_run) do
    if dry_run do
      {:ok, :skipped}
    else
      file_path = Path.join([dest_dir, "brew", "formulas.txt"])
      content = Enum.join(formulas, "\n") <> "\n"

      case File.write(file_path, content) do
        :ok -> {:ok, length(formulas)}
        {:error, reason} -> {:error, "Failed to write formulas.txt: #{reason}"}
      end
    end
  end

  defp maybe_write_casks(dest_dir, casks, dry_run) do
    if dry_run do
      {:ok, :skipped}
    else
      file_path = Path.join([dest_dir, "brew", "casks.txt"])
      content = Enum.join(casks, "\n") <> "\n"

      case File.write(file_path, content) do
        :ok -> {:ok, length(casks)}
        {:error, reason} -> {:error, "Failed to write casks.txt: #{reason}"}
      end
    end
  end

  defp maybe_write_taps(dest_dir, taps, dry_run) do
    if dry_run do
      {:ok, :skipped}
    else
      file_path = Path.join([dest_dir, "brew", "taps.txt"])
      content = Enum.join(taps, "\n") <> "\n"

      case File.write(file_path, content) do
        :ok -> {:ok, length(taps)}
        {:error, reason} -> {:error, "Failed to write taps.txt: #{reason}"}
      end
    end
  end
end
