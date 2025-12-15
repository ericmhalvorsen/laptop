# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vault is an Elixir-based CLI tool for backing up and restoring macOS system configurations. It backs up dotfiles, Homebrew packages, application configs, and user data to either git or a vault directory.

## Development Commands

### Building
```bash
# Install dependencies
mix deps.get

# Build the escript (creates bin/.vault-escript)
mix escript.build

# Run via the self-bootstrapping wrapper
./bin/vault --help
```

### Testing
```bash
# Run all tests
mix test

# Run a single test file
mix test test/vault/backup_test.exs

# Run a specific test
mix test test/vault/backup_test.exs:42

# Test coverage
mix coveralls
mix coveralls.html
```

### Code Quality
```bash
# Format code
mix format

# Lint with Credo
mix credo
mix credo --strict
```

### Development Mode
```bash
# Rebuild and run in one step
./bin/vault --dev save
```

## Architecture

### Core Components

- **Vault.CLI** (`lib/vault/cli.ex`): Main entry point, parses arguments and dispatches to command modules
- **Vault.Commands.*** (`lib/vault/commands/`): Command implementations (Save, Restore, Install, Status)
- **Vault.Backup** (`lib/vault/backup.ex`): Handles backup operations for different steps (brew, apt, dotfiles, etc.)
- **Vault.Restore** (`lib/vault/restore.ex`): Handles restoration of backed up configurations
- **Vault.Sync** (`lib/vault/sync.ex`): Low-level rsync operations
- **Vault.Config** (`lib/vault/config.ex`): Loads and parses config/vault.yaml
- **Vault.State** (`lib/vault/state.ex`): GenServer for tracking command execution state
- **Vault.UI.Progress** (`lib/vault/ui/progress.ex`): Terminal UI using Owl library

### Configuration System

**config/vault.yaml** defines:
- `:steps`: Master list of backup steps (brew, apt, sensitive, dotfiles, configdirs, etc.)
- `:git`: Which steps to back up to git (subset of steps)
- `:vault`: Which steps to back up to vault directory (full set)
- `:defaults`: Exclusion patterns and default settings

**config/apps.yaml**: Application installation definitions

### Backup Steps Architecture

Each backup step is defined with:
- `:name`: Unique identifier
- `:label`: Human-readable description
- `:contents`: List of files/directories to back up

Steps can be backed up to:
1. **Git**: Subset of steps committed to repository (brew, apt, scripts, dotfiles)
2. **Vault**: Full backup to external directory (all steps including sensitive data)

### Build Output

The project builds to an escript at `bin/.vault-escript`. The `bin/vault` bash wrapper:
1. Auto-installs Homebrew, git, mise on first run
2. Builds the escript if missing
3. Supports `--dev` flag to rebuild before running
4. Delegates to the escript

## Key Patterns

- Commands follow the pattern `Vault.Commands.CommandName.run(args, opts)`
- State tracking via GenServer for progress reporting
- Rsync with stats parsing for file operations
- Graceful handling when package managers (brew/apt) are not installed
- Options support: `--vault-target`, `--ssh-key`, `--dry-run`, `--verbose`, `--git-only`, `--vault-only`
