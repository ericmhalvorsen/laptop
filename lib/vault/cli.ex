defmodule Vault.CLI do
  @moduledoc """
  Main entry point for the Vault CLI application.

  Vault is a tool for backing up and restoring macOS configurations and data.
  """

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
  defp process_command({:status, args, opts}), do: Vault.Commands.Status.run(args, opts)

  defp process_command({:error, msg}) do
    Owl.IO.puts([
      Owl.Data.tag("✗ Error: ", :red),
      msg
    ])

    System.halt(1)
  end

  defp process_command(_), do: print_help()

  defp print_help do
    Owl.IO.puts([
      Owl.Data.tag("\nVault", :cyan),
      Owl.Data.tag(" - macOS Configuration Backup & Restore\n", :light_black),
      "\n",
      Owl.Data.tag("Usage:\n", :yellow),
      "  vault ",
      Owl.Data.tag("save", :green),
      " [options]        Backup current system to vault\n",
      "  vault ",
      Owl.Data.tag("restore", :green),
      " [options]     Restore from vault\n",
      "  vault ",
      Owl.Data.tag("status", :green),
      " [options]      Show vault status\n",
      "  vault ",
      Owl.Data.tag("help", :green),
      "                  Show this help\n",
      "\n",
      Owl.Data.tag("Options:\n", :yellow),
      "  -v, --vault-path PATH       Vault directory path\n",
      "  --verbose                   Verbose output\n",
      "  --dry-run                   Dry run (no changes)\n",
      "  -h, --help                  Show help\n"
    ])
  end
end
