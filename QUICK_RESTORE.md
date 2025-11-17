# Quick Restore Guide

Restore a fresh macOS system with a single command.

## Prerequisites

- macOS with bash and curl (pre-installed)
- Internet connection
- Access to this repo and your backup

## Fresh System Restore

```bash
# 1. Install Homebrew (only if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install git
brew install git

# 3. Clone this repo
git clone git@github.com:yourusername/laptop.git ~/code/laptop
cd ~/code/laptop

# 4. Run vault (it auto-installs everything it needs!)
./vault restore -v /path/to/backup
```

That's it! The `vault` wrapper automatically:
1. Checks if Homebrew is installed (installs if needed)
2. Checks if mise is installed (installs if needed)
3. Builds the vault escript (if not already built)
4. Runs your restore command

## Just Install Apps

```bash
cd ~/code/laptop
./vault apps install
```

Installs everything from `config/apps.yaml`:
- Homebrew formulas and casks
- Local .pkg installers
- Local .dmg images
- Direct downloads

## Dry Run

Test what would happen without making changes:

```bash
./vault restore --dry-run -v /path/to/backup
./vault apps install --dry-run
```

## First Time on a System?

The first time you run `./vault` on a new system, you'll see:

```
╔═══════════════════════════════════════════════════════════╗
║     Vault Self-Bootstrap                                 ║
╚═══════════════════════════════════════════════════════════╝

First run detected. Installing dependencies...

==> Installing Homebrew
==> Installing mise
==> Building vault
  Installing Elixir and Erlang...
  Fetching dependencies...
  Compiling...

╔═══════════════════════════════════════════════════════════╗
║     Bootstrap Complete!                                  ║
╚═══════════════════════════════════════════════════════════╝
```

Then your command runs immediately!

## Subsequent Runs

After the first run, `./vault` executes instantly - no bootstrap needed.
