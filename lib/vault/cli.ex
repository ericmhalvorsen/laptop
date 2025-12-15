defmodule Vault.CLI do
  @moduledoc """
  Main entry point for the Vault CLI application.
  """

  alias Vault.UI.Progress

  def main(args) do
    args
    |> parse_args()
    |> process_command()
  end

  defp parse_args(args) do
    {opts, command_and_args, invalid} =
      OptionParser.parse(
        args,
        strict: [
          config_path: :string,
          vault_target: :string,
          ssh_key: :string,
          verbose: :boolean,
          dry_run: :boolean,
          help: :boolean,
          only: :string,
          git_only: :boolean,
          vault_only: :boolean,
          dev: :boolean
        ],
        aliases: [
          c: :config_path,
          d: :dev,
          t: :vault_target,
          i: :ssh_key,
          h: :help
        ]
      )

    opts =
      cond do
        Keyword.get(opts, :git_only) == true ->
          Progress.puts([Progress.tag("Only performing backup to git", :yellow)])
          opts

        Keyword.get(opts, :vault_only) == true ->
          Progress.puts([Progress.tag("Only performing backup to vault", :yellow)])
          opts

        Keyword.get(opts, :only) == "git" ->
          Progress.puts([Progress.tag("Only performing backup to git", :yellow)])
          Keyword.merge(opts, git_only: true)

        Keyword.get(opts, :only) == "vault" ->
          Progress.puts([Progress.tag("Only performing backup to vault", :yellow)])
          Keyword.merge(opts, vault_only: true)

        true ->
          opts
      end

    case {command_and_args, invalid, opts[:help]} do
      {_, _, true} -> :help
      {[], _, _} -> :help
      {[command | rest], [], _} -> {String.to_atom(command), rest, opts}
      {_, invalid, _} -> {:error, "Invalid options: #{inspect(invalid)}"}
    end
  end

  defp process_command(:help), do: print_help()
  defp process_command({:save, args, opts}), do: Vault.Commands.Save.run(args, opts)
  defp process_command({:restore, args, opts}), do: Vault.Commands.Restore.run(args, opts)
  defp process_command({:install, args, opts}), do: Vault.Commands.Install.run(args, opts)
  defp process_command({:status, args, opts}), do: Vault.Commands.Status.run(args, opts)

  defp process_command({:error, msg}) do
    Progress.puts([
      Progress.tag("✗ Error: ", :red),
      msg
    ])

    System.halt(1)
  end

  defp process_command(_), do: print_help()

  defp print_help do
    Progress.puts([
      Progress.tag("\nVault", :cyan),
      Progress.tag(" - macOS Configuration Backup & Restore\n", :light_black),
      "\n",
      Progress.tag("Usage:\n", :yellow),
      "  vault ",
      Progress.tag("save", :green),
      " [options]        Backup current system to vault\n",
      "  vault ",
      Progress.tag("restore", :green),
      " [options]     Restore from vault\n",
      "  vault ",
      Progress.tag("install", :green),
      " [options]     Bootstrap system from git (packages + dotfiles)\n",
      "  vault ",
      Progress.tag("status", :green),
      " [options]      Show vault status\n",
      "  vault ",
      Progress.tag("help", :green),
      "                  Show this help\n\n",
      Progress.tag("Options:\n", :yellow),
      "  -c, --config-path PATH      Config file path, default config/vault.yaml\n",
      "  -t, --vault-target TARGET   Vault target (local path or user@host:/path)\n",
      "  -i, --ssh-key PATH          SSH key for remote vault target\n",
      "  --verbose                   Verbose output\n",
      "  --dry-run                   Dry run (no changes)\n",
      "  --git-only                 Run only git-backed steps (skip vault steps)\n",
      "  --vault-only               Run only vault steps (skip git-backed steps)\n",
      "  -h, --help                  Show help\n"
    ])
  end
end
