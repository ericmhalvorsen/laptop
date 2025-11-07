# Vault CLI - Project Context

## Project Overview

**Vault** is a modern Elixir-based CLI tool for backing up and restoring macOS configurations and data. It replaces legacy shell scripts with a robust, tested, and user-friendly command-line application.

### Key Objectives

1. **Modern CLI Experience**: Use Elixir with Owl framework for beautiful, interactive interfaces
2. **Separation of Concerns**:
   - Git repo contains lightweight CLI tool and documentation
   - Vault directory (not in git) contains all backup data
3. **Comprehensive Backup**: Dotfiles, configs, applications, browser data, Obsidian notes, and home directories
4. **Full Test Coverage**: All functionality must be tested with ExUnit
5. **User-Friendly**: Progress bars, colored output, interactive prompts, helpful error messages

## Architecture

### Repository Structure
```
laptop/                          # Git repository
├── lib/vault/
│   ├── cli.ex                   # Main CLI entry point
│   ├── commands/
│   │   ├── save.ex              # Backup command
│   │   ├── restore.ex           # Restore command
│   │   ├── status.ex            # Status command
│   │   └── ...
│   ├── backup/
│   │   ├── dotfiles.ex
│   │   ├── homebrew.ex
│   │   ├── apps.ex
│   │   └── home_dirs.ex
│   └── restore/
│       └── ...
├── test/
├── mix.exs
├── PROGRESS.md
└── docs/
```

### Vault Directory (NOT in git)
```
~/VaultBackup/                   # User-specified location
├── dotfiles/
├── configs/
├── local-bin/
├── apps/
├── homebrew/
├── browser/
├── obsidian/
├── home/
└── sensitive/
```

## Technology Stack

### Core Technologies

- **Elixir**: Functional programming language on Erlang VM
- **Owl**: Modern CLI toolkit for beautiful terminal UIs
- **ExUnit**: Built-in testing framework
- **OptionParser**: Standard library for CLI argument parsing

### Why Elixir?

- Excellent for CLI tools with concurrency (parallel backups)
- Pattern matching simplifies complex logic
- Immutability reduces bugs
- Great error handling with `{:ok, result}` / `{:error, reason}` pattern
- Escript makes distribution easy (single executable)

### Why Owl?

- Beautiful, modern terminal UI components
- Progress bars, spinners, live updates
- Interactive prompts and select menus
- Colored output with tags
- Built specifically for Elixir CLIs

## Owl Framework - Best Practices & Examples

### Installation

Add to `mix.exs`:
```elixir
def deps do
  [
    {:owl, "~> 0.13"},
    {:ucwidth, "~> 0.2"}  # Optional: for emoji/multibyte support
  ]
end
```

### Core Components

#### 1. Colored Text with Tags

```elixir
# Basic colored text
Owl.IO.puts([
  Owl.Data.tag("Success!", :green),
  " Backed up ",
  Owl.Data.tag("42 files", :cyan)
])

# Multiple colors in one line
[
  Owl.Data.tag("ERROR", :red),
  ": ",
  Owl.Data.tag("File not found", :light_black)
]
```

**Available colors**: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`, `:light_black`, `:light_red`, etc.

#### 2. Progress Bars

```elixir
# Start a progress bar
Owl.ProgressBar.start(
  id: :backup_files,
  label: "Backing up files",
  total: 100,
  timer: true,              # Show elapsed time
  bar_width_ratio: 0.3,     # 30% of terminal width
  filled_symbol: "█",
  partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
)

# Update progress
Owl.ProgressBar.inc(id: :backup_files)

# Or set specific value
Owl.ProgressBar.set(id: :backup_files, absolute: 50)
```

#### 3. Spinners

```elixir
# Start a spinner for indefinite operations
Owl.Spinner.start(
  id: :installing,
  label: "Installing Homebrew packages..."
)

# Stop spinner
Owl.Spinner.stop(id: :installing)
```

#### 4. Interactive Select Menus

```elixir
# Simple selection
choice = Owl.IO.select(["Option 1", "Option 2", "Option 3"])

# Complex selection with custom rendering
packages = [
  %{name: "dotfiles", description: "Shell configurations"},
  %{name: "homebrew", description: "Package manager data"},
  %{name: "apps", description: "Applications and installers"}
]

selected = Owl.IO.select(packages,
  render_as: fn %{name: name, description: desc} ->
    [
      Owl.Data.tag(name, :cyan),
      "\n  ",
      Owl.Data.tag(desc, :light_black)
    ]
  end
)

# Multi-select
selections = Owl.IO.multiselect(packages, min: 1)
```

#### 5. Text Input

```elixir
# Get user input
path = Owl.IO.input(label: "Enter vault path: ")

# With validation
number = Owl.IO.input(
  label: "Enter count: ",
  cast: :integer,
  min: 1,
  max: 100
)
```

#### 6. Live Updating Blocks

```elixir
# For multi-line output that updates
Owl.LiveScreen.add_block(:status, render: fn ->
  [
    Owl.Data.tag("Status", :yellow),
    "\n",
    "Files: #{files_count}",
    "\n",
    "Progress: #{percentage}%"
  ]
end)

# Update when data changes
Owl.LiveScreen.update()
```

#### 7. Tables

```elixir
# Display data in table format
Owl.Table.new([
  ["Name", "Status", "Size"],
  [".zshrc", "✓", "4.2 KB"],
  [".gitconfig", "✓", "104 B"]
])
|> Owl.IO.puts()
```

#### 8. Boxes

```elixir
# Wrap content in ASCII box
Owl.Box.new([
  Owl.Data.tag("Vault Backup Complete!", :green),
  "\n\n",
  "Files backed up: 156",
  "\n",
  "Total size: 2.3 GB"
])
|> Owl.IO.puts()
```

### Owl Best Practices

1. **Use tags consistently**: Define color scheme early (success=green, error=red, info=cyan)
2. **IDs for multiple components**: When using multiple progress bars/spinners, use unique IDs
3. **LiveScreen for complex UIs**: Use LiveScreen when you need multiple updating components
4. **Clean up resources**: Always stop spinners/progress bars when done
5. **Responsive design**: Use `:bar_width_ratio` for progress bars instead of fixed width

### Example: Complete CLI Flow

```elixir
defmodule Vault.Commands.Save do
  def run(opts) do
    # Get vault path with prompt
    vault_path = opts[:vault_path] || Owl.IO.input(label: "Vault path: ")

    # Show what will be backed up
    components = Owl.IO.multiselect([
      "Dotfiles",
      "Homebrew",
      "Applications",
      "Browser data",
      "Obsidian"
    ], min: 1)

    # Confirm
    Owl.IO.puts([Owl.Data.tag("\nStarting backup...", :cyan)])

    # Progress bar for file operations
    Owl.ProgressBar.start(
      id: :backup,
      label: "Backing up files",
      total: total_files
    )

    # Perform backup with updates
    Enum.each(files, fn file ->
      backup_file(file, vault_path)
      Owl.ProgressBar.inc(id: :backup)
    end)

    # Success message in box
    Owl.Box.new([
      Owl.Data.tag("✓ Backup Complete!", :green),
      "\n\n",
      "Location: #{vault_path}",
      "\n",
      "Files: #{total_files}",
      "\n",
      "Size: #{format_size(total_size)}"
    ])
    |> Owl.IO.puts()
  end
end
```

## Elixir CLI & Escript Best Practices

### Mix.exs Configuration

```elixir
defmodule Vault.MixProject do
  use Mix.Project

  def project do
    [
      app: :vault,
      version: "0.1.0",
      elixir: "~> 1.15",
      escript: escript(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp escript do
    [
      main_module: Vault.CLI,
      name: "vault"
    ]
  end

  defp deps do
    [
      {:owl, "~> 0.13"},
      {:ucwidth, "~> 0.2"}
    ]
  end
end
```

### Main CLI Module Pattern

```elixir
defmodule Vault.CLI do
  @moduledoc """
  Main entry point for Vault CLI.
  """

  def main(args) do
    args
    |> parse_args()
    |> process_command()
  end

  defp parse_args(args) do
    {opts, command_and_args, invalid} = OptionParser.parse(
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
  defp process_command({:error, msg}), do: IO.puts("Error: #{msg}")
  defp process_command(_), do: print_help()

  defp print_help do
    IO.puts("""
    Vault - macOS Configuration Backup & Restore

    Usage:
      vault save [options]        Backup current system to vault
      vault restore [options]     Restore from vault
      vault status [options]      Show vault status
      vault help                  Show this help

    Options:
      -v, --vault-path PATH       Vault directory path
      --verbose                   Verbose output
      --dry-run                   Dry run (no changes)
      -h, --help                  Show help
    """)
  end
end
```

### Error Handling Pattern

```elixir
# Use the {:ok, result} / {:error, reason} pattern
defmodule Vault.Backup.Dotfiles do
  def backup(source, dest) do
    with {:ok, files} <- list_dotfiles(source),
         {:ok, _} <- File.mkdir_p(dest),
         {:ok, copied} <- copy_files(files, source, dest) do
      {:ok, copied}
    else
      {:error, reason} -> {:error, "Failed to backup dotfiles: #{reason}"}
    end
  end

  defp list_dotfiles(source) do
    case File.ls(source) do
      {:ok, files} -> {:ok, Enum.filter(files, &dotfile?/1)}
      error -> error
    end
  end

  defp copy_files(files, source, dest) do
    results = Enum.map(files, fn file ->
      src = Path.join(source, file)
      dst = Path.join(dest, file)
      File.cp(src, dst)
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, length(files)}
    else
      {:error, "Some files failed to copy"}
    end
  end

  defp dotfile?("." <> _), do: true
  defp dotfile?(_), do: false
end
```

### Testing Pattern

```elixir
defmodule Vault.Backup.DotfilesTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  setup do
    # Create temp directories
    source = Path.join(System.tmp_dir!(), "vault_test_source_#{:rand.uniform(10000)}")
    dest = Path.join(System.tmp_dir!(), "vault_test_dest_#{:rand.uniform(10000)}")

    File.mkdir_p!(source)
    File.mkdir_p!(dest)

    # Cleanup after test
    on_exit(fn ->
      File.rm_rf!(source)
      File.rm_rf!(dest)
    end)

    %{source: source, dest: dest}
  end

  test "backs up dotfiles from source to dest", %{source: source, dest: dest} do
    # Create test dotfiles
    File.write!(Path.join(source, ".zshrc"), "test content")
    File.write!(Path.join(source, ".gitconfig"), "git config")

    # Run backup
    assert {:ok, 2} = Vault.Backup.Dotfiles.backup(source, dest)

    # Verify files copied
    assert File.exists?(Path.join(dest, ".zshrc"))
    assert File.exists?(Path.join(dest, ".gitconfig"))
    assert File.read!(Path.join(dest, ".zshrc")) == "test content"
  end

  test "handles missing source directory", %{dest: dest} do
    assert {:error, _} = Vault.Backup.Dotfiles.backup("/nonexistent", dest)
  end
end
```

## Project-Specific Guidelines

### Code Organization

1. **One concern per module**: `Vault.Backup.Dotfiles` only handles dotfiles
2. **Commands in commands/**: All CLI commands in `lib/vault/commands/`
3. **Logic in domain modules**: Keep commands thin, logic in domain modules
4. **Tests mirror structure**: `test/vault/backup/dotfiles_test.exs` mirrors `lib/vault/backup/dotfiles.ex`

### Naming Conventions

- **Modules**: `PascalCase` (e.g., `Vault.Commands.Save`)
- **Functions**: `snake_case` (e.g., `backup_dotfiles`)
- **Variables**: `snake_case` (e.g., `vault_path`)
- **Atoms**: `snake_case` (e.g., `:vault_path`)
- **Module attributes**: `@snake_case` (e.g., `@default_path`)

### Function Documentation

```elixir
@doc """
Backs up dotfiles from the home directory to the vault.

## Parameters

  * `vault_path` - Destination path for backup
  * `opts` - Options keyword list
    * `:exclude` - List of patterns to exclude
    * `:dry_run` - Boolean, if true don't write files

## Returns

  * `{:ok, count}` - Success with number of files backed up
  * `{:error, reason}` - Failure with reason

## Examples

    iex> Vault.Backup.Dotfiles.backup("/tmp/vault")
    {:ok, 12}

    iex> Vault.Backup.Dotfiles.backup("/tmp/vault", dry_run: true)
    {:ok, 12}
"""
def backup(vault_path, opts \\ []) do
  # Implementation
end
```

### Error Messages

Use Owl tags for consistent, helpful error messages:

```elixir
defp show_error(message) do
  Owl.IO.puts([
    Owl.Data.tag("✗ Error: ", :red),
    message
  ])
end

defp show_warning(message) do
  Owl.IO.puts([
    Owl.Data.tag("⚠ Warning: ", :yellow),
    message
  ])
end

defp show_success(message) do
  Owl.IO.puts([
    Owl.Data.tag("✓ ", :green),
    message
  ])
end

defp show_info(message) do
  Owl.IO.puts([
    Owl.Data.tag("ℹ ", :cyan),
    message
  ])
end
```

### Rsync Integration

For large directory backups (Documents, Downloads, etc.):

```elixir
defmodule Vault.Backup.HomeDirs do
  def backup_with_rsync(source, dest, opts \\ []) do
    exclude_patterns = opts[:exclude] || [".DS_Store", "node_modules", ".git"]

    exclude_args = Enum.flat_map(exclude_patterns, fn pattern ->
      ["--exclude", pattern]
    end)

    args = [
      "-av",              # archive mode, verbose
      "--progress",       # show progress
      "--delete",         # delete files not in source
      source <> "/",      # trailing slash important!
      dest
    ] ++ exclude_args

    # Could show progress with Owl
    # Parse rsync output and update progress bar

    case System.cmd("rsync", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, "rsync failed (#{code}): #{output}"}
    end
  end
end
```

## Critical Backup Components

Per user requirements, these are HIGH PRIORITY:

1. **Dotfiles**: `.zshrc`, `.gitconfig`, `.vimrc`, etc.
2. **Scripts**: `~/.local/bin/*`
3. **ZSH & oh-my-zsh**: Config and plugins
4. **Obsidian**: Vault backup (auto-detect location)
5. **Yaak**: API testing tool
6. **Homebrew**: Complete package list
7. **RustDesk**: Remote desktop
8. **Docker**: For Mac
9. **Warp**: Terminal app + settings + themes
10. **Claude Code**: `.claude/` config
11. **Browser data**: Brave and Chrome
12. **Home directories**: Documents, Downloads, Pictures, Desktop

## Warp Configuration Deep Dive

Warp stores configuration in multiple locations:

```
~/.warp/                         # Main config directory
├── launch_configurations/       # Launch configs
├── themes/                      # Custom themes
├── keybindings.yaml            # Custom keybindings
└── config.yaml                 # Main settings
```

Additional locations to check:
```
~/Library/Application Support/dev.warp.Warp-Stable/
~/Library/Preferences/dev.warp.Warp-Stable.plist
```

Backup strategy:
1. Copy entire `~/.warp/` directory
2. Check for config in `~/Library/Application Support/`
3. Export preferences with `defaults read dev.warp.Warp-Stable`

## Development Workflow

### Build and Test

```bash
# Get dependencies
mix deps.get

# Run tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test
mix test test/vault/backup/dotfiles_test.exs

# Build escript
mix escript.build

# Run escript
./vault save --vault-path ~/VaultBackup
```

### During Development

```bash
# Format code
mix format

# Check for issues
mix compile --warnings-as-errors

# Run in interactive mode
iex -S mix

# In IEx, test functions
iex> Vault.Backup.Dotfiles.backup("/tmp/test")
```

## Progress Tracking

See `PROGRESS.md` for detailed phase-by-phase progress tracking.

Current status and next steps are maintained there.

## Resources

- **Owl Documentation**: https://hexdocs.pm/owl
- **Owl GitHub**: https://github.com/fuelen/owl
- **Owl Examples**: https://github.com/fuelen/owl/tree/master/examples
- **Elixir OptionParser**: https://hexdocs.pm/elixir/OptionParser.html
- **ExUnit**: https://hexdocs.pm/ex_unit/ExUnit.html
- **Mix Escript**: https://hexdocs.pm/mix/Mix.Tasks.Escript.Build.html

## Notes for Claude

When working on this project:

1. **Always write tests first** for new functionality
2. **Use Owl components** for all user-facing output (no plain IO.puts)
3. **Follow the {:ok, result} / {:error, reason} pattern** for all operations
4. **Document all public functions** with @doc
5. **Keep PROGRESS.md updated** as tasks are completed
6. **Separate concerns**: Commands orchestrate, domain modules do work
7. **Handle errors gracefully** with helpful messages
8. **Test on temp directories** to avoid breaking real system
9. **Consider macOS specifics** (paths, apps, plist files)
10. **Security first**: Never commit vault data, be careful with sensitive files

## Update Log

- **2025-11-06**: Initial CLAUDE.md created with Owl research and best practices
