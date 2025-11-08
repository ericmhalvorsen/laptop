defmodule Vault.Backup.Homebrew do
  @moduledoc """
  Handles backup of Homebrew packages, casks, and taps.

  This module backs up all Homebrew-related data:
  - Brewfile (complete backup including taps, formulas, casks, and VSCode extensions)
  - formulas.txt (list of installed formula packages)
  - casks.txt (list of installed cask applications)
  - taps.txt (list of tapped repositories)
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

  ## Examples

      iex> Vault.Backup.Homebrew.backup("/tmp/vault")
      {:ok, %{brewfile: true, formulas: 42, casks: 15, taps: 4}}

      iex> Vault.Backup.Homebrew.backup("/tmp/vault", dry_run: true)
      {:ok, %{brewfile: false, formulas: 42, casks: 15, taps: 4}}
  """
  def backup(dest_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    with {:ok, _} <- check_homebrew_installed(),
         {:ok, formulas} <- list_formulas(),
         {:ok, casks} <- list_casks(),
         {:ok, taps} <- list_taps(),
         {:ok, _} <- maybe_create_directory(dest_dir, dry_run),
         {:ok, brewfile_created} <- maybe_create_brewfile(dest_dir, dry_run),
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

  # Check if Homebrew is installed
  defp check_homebrew_installed do
    case System.cmd("which", ["brew"], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 ->
        {:ok, :installed}

      _ ->
        {:error, "Homebrew is not installed"}
    end
  end

  # List installed formula packages
  defp list_formulas do
    case System.cmd("brew", ["list", "--formula"], stderr_to_stdout: true) do
      {output, 0} ->
        formulas =
          output
          |> String.split("\n", trim: true)

        {:ok, formulas}

      {error, _code} ->
        {:error, "Failed to list formulas: #{error}"}
    end
  end

  # List installed cask applications
  defp list_casks do
    case System.cmd("brew", ["list", "--cask"], stderr_to_stdout: true) do
      {output, 0} ->
        casks =
          output
          |> String.split("\n", trim: true)

        {:ok, casks}

      {error, _code} ->
        {:error, "Failed to list casks: #{error}"}
    end
  end

  # List tapped repositories
  defp list_taps do
    case System.cmd("brew", ["tap"], stderr_to_stdout: true) do
      {output, 0} ->
        taps =
          output
          |> String.split("\n", trim: true)

        {:ok, taps}

      {error, _code} ->
        {:error, "Failed to list taps: #{error}"}
    end
  end

  # Create brew directory if not dry run
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

  # Create Brewfile using brew bundle dump
  defp maybe_create_brewfile(dest_dir, dry_run) do
    if dry_run do
      {:ok, false}
    else
      brew_dir = Path.join(dest_dir, "brew")
      brewfile_path = Path.join(brew_dir, "Brewfile")

      # Remove existing Brewfile if present (brew bundle dump --force would work too)
      File.rm(brewfile_path)

      case System.cmd("brew", ["bundle", "dump", "--file=#{brewfile_path}"],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          {:ok, true}

        {error, _code} ->
          {:error, "Failed to create Brewfile: #{error}"}
      end
    end
  end

  # Write formulas list to file
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

  # Write casks list to file
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

  # Write taps list to file
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
