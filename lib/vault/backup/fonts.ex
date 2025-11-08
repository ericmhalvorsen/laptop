defmodule Vault.Backup.Fonts do
  @moduledoc """
  Backs up user-installed fonts to vault.

  Only backs up fonts from ~/Library/Fonts (user-installed).
  System fonts are excluded as they come with macOS.
  """

  @doc """
  Backs up user-installed fonts to the vault.

  ## Parameters

    * `home_dir` - Home directory path
    * `vault_path` - Vault directory path
    * `opts` - Options keyword list
      * `:dry_run` - Boolean, if true don't actually copy files

  ## Returns

    * `{:ok, result}` - Success with map containing:
      * `:fonts_copied` - Number of font files backed up
      * `:total_size` - Total size in bytes
    * `{:error, reason}` - Failure with reason

  ## Examples

      iex> Fonts.backup("/Users/eric", "/tmp/vault")
      {:ok, %{fonts_copied: 12, total_size: 2048576}}
  """
  def backup(home_dir, vault_path, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    fonts_source = Path.join([home_dir, "Library", "Fonts"])
    fonts_dest = Path.join([vault_path, "fonts"])

    # If user fonts directory doesn't exist, that's OK
    if not File.dir?(fonts_source) do
      {:ok, %{fonts_copied: 0, total_size: 0}}
    else
      with {:ok, files} <- File.ls(fonts_source),
           :ok <- maybe_create_dest(fonts_dest, dry_run) do
        if Enum.empty?(files) or dry_run do
          {:ok, %{fonts_copied: 0, total_size: 0}}
        else
          # Start progress bar
          Owl.ProgressBar.start(
            id: :fonts,
            label: "  Fonts",
            total: length(files),
            bar_width_ratio: 0.5,
            filled_symbol: "█",
            partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
          )

          results =
            files
            |> Enum.map(fn file ->
              source = Path.join(fonts_source, file)
              dest = Path.join(fonts_dest, file)

              result =
                if File.regular?(source) do
                  case File.cp(source, dest) do
                    :ok ->
                      case File.stat(dest) do
                        {:ok, stat} -> {:ok, stat.size}
                        error -> error
                      end

                    error ->
                      error
                  end
                else
                  {:skipped, :not_regular}
                end

              Owl.ProgressBar.inc(id: :fonts)
              result
            end)

          Owl.LiveScreen.await_render()

          fonts_copied = Enum.count(results, &match?({:ok, _}, &1))

          total_size =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, size} -> size end)
            |> Enum.sum()

          {:ok, %{fonts_copied: fonts_copied, total_size: total_size}}
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
end
