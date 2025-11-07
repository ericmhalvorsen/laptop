# Vault - macOS Setup CLI

Modern Elixir-based CLI tool for backing up and restoring macOS configurations and data.

## Overview

Vault uses a **two-tier backup system**:

### Tier 1: Lightweight Configs (This Git Repo)
- ✅ Dotfiles (`.zshrc`, `.gitconfig`, etc.)
- ✅ Application configs (`.config` directories)
- ✅ Custom scripts (`~/.local/bin`)
- ✅ Homebrew package lists
- **Committed to git** - lightweight, version controlled
- Can restore from GitHub alone (data-less restore)

### Tier 2: Heavy Data (Vault Directory)
- 🌐 Browser data (Brave, Chrome)
- ⚙️ Application settings/data (post-install)
- 📝 Obsidian vaults
- 📁 Home directories (Documents, Downloads, Pictures, Desktop)
- 🔐 Sensitive files (`.netrc`, SSH keys)
- **NOT in git** - stored separately (external drive, NAS, etc.)

### Applications (Installed from Latest)
- 📦 Apps installed from latest sources (Homebrew, GitHub, websites)
- ✅ Ensures you always get the latest version
- ⚙️ Settings restored from vault after installation

## Quick Start

### Installation

```bash
# Clone this repository
git clone <your-repo-url> ~/code/laptop
cd ~/code/laptop

# Install Elixir/Erlang via mise (if not already installed)
mise use elixir@latest erlang@latest

# Install dependencies and build
mise exec -- mix deps.get
mise exec -- mix escript.build
```

### Basic Usage

```bash
# Save your current system
./bin/vault save

# This saves:
#   - Lightweight configs → this git repo (dotfiles/, config/, etc.)
#   - Heavy data → ~/VaultBackup/ (apps, browser, home dirs)

# Save with custom vault location
./bin/vault save --vault-path /Volumes/Backup/VaultBackup

# Restore from git only (data-less - configs only)
./bin/vault restore

# Restore everything (configs + vault data)
./bin/vault restore --vault-path ~/VaultBackup

# Check status
./bin/vault status
./bin/vault status --vault-path ~/VaultBackup
```

## What Gets Backed Up

### Tier 1: In This Repo (Committed to Git)

**Dotfiles** (`dotfiles/`):
- `.zshrc`, `.zshenv`, `.zprofile`
- `.gitconfig`
- `.vimrc`, `.irbrc`
- And more

**Configs** (`config/`):
- Claude Code settings
- Warp terminal config
- Mise configuration
- Git global config
- And more

**Scripts** (`local-bin/`):
- All your custom `~/.local/bin` scripts

**Homebrew** (`brew/`):
- Brewfile (complete package list)
- Formulas list
- Casks list

### Tier 2: In Vault Directory (NOT in Git)

**Browser Data** (`vault/browser/`):
- Brave browser data (history, bookmarks, extensions)
- Chrome browser data (history, bookmarks, extensions)

**Application Settings** (`vault/app-data/`):
- Warp settings (post-install)
- Yaak settings (post-install)
- Other app-specific configs

**Obsidian** (`vault/obsidian/`):
- Your Obsidian vaults

**Home Directories** (`vault/home/`):
- Documents
- Downloads
- Pictures
- Desktop

**Sensitive Files** (`vault/sensitive/`):
- `.netrc`
- SSH keys
- GPG keys

### Applications (Installed from Latest Sources)

Applications are **NOT backed up** as installers. Instead, they're installed from latest sources:

- **Homebrew Apps**: Installed via `brew install --cask`
- **Yaak**: Downloaded from latest GitHub release
- **RustDesk**: Downloaded from latest GitHub release
- **Docker**: Downloaded from Docker website
- **Warp**: Downloaded from Warp website

Settings are restored from `vault/app-data/` after installation.

## Restore Scenarios

### Scenario 1: New Mac, Quick Start (Data-Less)

```bash
# Clone repo and restore just the configs
git clone <your-repo-url> ~/code/laptop
cd ~/code/laptop
./bin/vault restore

# This restores:
#   ✅ Dotfiles
#   ✅ App configs
#   ✅ Scripts
#   ✅ Homebrew packages
#   ❌ No vault data (you do this separately)
```

### Scenario 2: Full Restore (Configs + Data)

```bash
# Clone repo
git clone <your-repo-url> ~/code/laptop
cd ~/code/laptop

# Connect external drive with vault data, then:
./bin/vault restore --vault-path /Volumes/Backup/VaultBackup

# This restores:
#   ✅ Dotfiles
#   ✅ App configs
#   ✅ Scripts
#   ✅ Homebrew packages
#   ✅ Install applications (latest versions)
#   ✅ Application settings
#   ✅ Browser data
#   ✅ Obsidian
#   ✅ Home directories
#   ✅ Sensitive files
```

### Scenario 3: Update Vault from Current System

```bash
# After making changes to your system, save again
./bin/vault save --vault-path /Volumes/Backup/VaultBackup

# Commit the repo changes
git add dotfiles/ config/ local-bin/ brew/
git commit -m "Update configs $(date +%Y-%m-%d)"
git push
```

## Development

### Project Structure

```
laptop/
├── lib/vault/              # Elixir source code
│   ├── cli.ex             # Main CLI entry
│   ├── commands/          # CLI commands
│   └── backup/            # Backup modules
├── dotfiles/              # Backed up dotfiles (committed)
├── config/                # App configs (committed)
├── local-bin/             # Scripts (committed)
├── brew/                  # Homebrew lists (committed)
├── test/                  # Tests
└── docs/                  # Documentation
```

### Building

```bash
# Build escript
mise exec -- mix escript.build

# Run tests
mise exec -- mix test

# Run CLI
./bin/vault help
```

### Tech Stack

- **Elixir 1.19**: Functional programming language
- **Owl**: Modern CLI UI framework (progress bars, colors, prompts)
- **ExUnit**: Testing framework
- **Escript**: Single-file executable

## Why Elixir?

- Beautiful CLI UIs with Owl framework
- Concurrent backups (fast!)
- Excellent error handling
- Pattern matching simplifies logic
- Single executable distribution

## Documentation

- **PROGRESS.md**: Development progress tracking
- **CLAUDE.md**: Project context for AI assistants
- **docs/browser-backup.md**: Browser data backup guide
- **docs/obsidian-backup.md**: Obsidian backup guide

## License

MIT License - See LICENSE file for details

## Contributing

This is a personal setup repository, but feel free to fork and adapt for your needs!

---

🤖 Built with [Claude Code](https://claude.com/claude-code)
