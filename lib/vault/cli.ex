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
          vault_path: :string,
          verbose: :boolean,
          dry_run: :boolean,
          help: :boolean
        ],
        aliases: [
          v: :vault_path,
          h: :help
        ]
      )

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
      " [options]     Install apps defined in config/apps.yaml\n",
      "  vault ",
      Progress.tag("status", :green),
      " [options]      Show vault status\n",
      "  vault ",
      Progress.tag("help", :green),
      "                  Show this help\n\n",
      Progress.tag("Options:\n", :yellow),
      "  -v, --vault-path PATH       Vault directory path\n",
      "  --verbose                   Verbose output\n",
      "  --dry-run                   Dry run (no changes)\n",
      "  -h, --help                  Show help\n"
    ])
  end
end
