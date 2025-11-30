defmodule Vault.Backup.Homebrew do
  @moduledoc """
  Handles backup of Homebrew packages, casks, and taps.
  """

  use Memoize
  alias Vault.Utils.FileUtils

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
  def homebrew(dest_dir, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    using_mock = Keyword.has_key?(opts, :cmd)
    brew_dir = Path.join(dest_dir, "brew")
    brewfile_path = Path.join(brew_dir, "Brewfile")

    with :ok <- if(using_mock, do: :ok, else: ensure_homebrew_installed()),
         {:ok, formulas} <- brew(["list", "--formula"]),
         {:ok, casks} <- brew(["list", "--cask"]),
         {:ok, taps} <- brew(["tap"]),
         :ok <- FileUtils.ensure_dir(dest_dir, dry_run),
         {:ok, _} <- brew(["bundle", "dump", "--file=#{brewfile_path}"]),
         {:ok, _} <-
           FileUtils.output_file(dest_path("formulas.txt"), formulas, dry_run),
         {:ok, _} <-
           FileUtils.output_file(dest_path("casks.txt"), casks, dry_run),
         {:ok, _} <-
           FileUtils.output_file(dest_path("taps.txt"), taps, dry_run) do
      {:ok,
       %{
         brewfile: brewfile_path,
         formulas: length(formulas),
         casks: length(casks),
         taps: length(taps)
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_homebrew_installed do
    case brew_cmd() do
      nil -> {:error, "Homebrew is not installed"}
      _path -> :ok
    end
  end

  defp brew(args) do
    case System.cmd(brew_cmd(), args, stderr_to_stdout: true) do
      {output, 0} ->
        formulas =
          output
          |> String.split("\n", trim: true)

        {:ok, formulas}

      {error, _code} ->
        {:error, "Failed to run brew #{args[0]}: #{error}}"}
    end
  end

  defp dest_path(file) do
    Path.join([file, "brew", "formulas.txt"])
  end

  defmemo brew_cmd do
    System.find_executable("brew") ||
      if(File.exists?("/opt/homebrew/bin/brew"), do: "/opt/homebrew/bin/brew") ||
      if(File.exists?("/usr/local/bin/brew"), do: "/usr/local/bin/brew") ||
      nil
  end
end
