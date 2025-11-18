# macOS Dotfiles

Personal macOS configuration and backup system.

## Vault Tool

Elixir-based CLI for backing up/restoring system configurations.

### Quick Start: Fresh System Restore

**On a fresh macOS system with just bash and curl:**

```bash
git clone <your-repo> ~/code/laptop
cd ~/code/laptop
./vault restore -v /path/to/backup
```

That's it! The `vault` wrapper automatically:
- Installs Homebrew (if needed)
- Installs git and mise (if needed)
- Builds the vault escript (if needed)
- Runs your command

**Single entry point, zero manual steps.**

### Development Setup

```bash
# Install Elixir/Erlang via mise
mise install

# Build vault tool (creates .vault-escript)
mix deps.get
mix escript.build

# Configure git hooks (required - enables pre-commit formatting/linting)
./hooks/install.sh

# The vault wrapper handles everything automatically
./vault --help
```

### Commands

```bash
# Backup system configs to repo + vault data
./bin/vault save
./bin/vault save --vault-path /Volumes/Backup/VaultBackup

# Restore configs only (from this repo)
./bin/vault restore

# Restore everything (configs + vault data)
./bin/vault restore --vault-path ~/VaultBackup

# Install applications from config/apps.yaml
./bin/vault install

# Check backup status
./bin/vault status
./bin/vault status --vault-path ~/VaultBackup
```

## Dotfiles Location

All dotfiles are stored in the `dotfiles/` directory and copied to `$HOME`:

- `.zshrc`, `.zshenv`, `.zprofile`
- `.gitconfig`
- `.bashrc`, `.bash_profile`
- `.irbrc`, `.aprc`
- Additional configs in `config/` (mise, git, uv, yarn)

## Neovim Config

Neovim configuration is maintained in a separate repository:

[github.com/ericmhalvorsen/nvim](https://github.com/ericmhalvorsen/nvim)
