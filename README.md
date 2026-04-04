# macOS Dotfiles

Personal macOS configuration and backup system.

## Vault Tool

Elixir-based CLI for backing up/restoring system configurations.

### Quick Start: Fresh System Restore

To restore on a fresh macOS system:

```bash
git clone <your-repo> ~/code/laptop
cd ~/code/laptop
./vault restore -t /path/to/backup
```

The `vault` wrapper will automatically:
- Install Homebrew (if needed)
- Install git and mise (if needed)
- Build the vault escript (if needed)
- Run the requested command

### Development Setup

```bash
# Install Elixir/Erlang via mise
mise install

# Build vault tool (creates .vault-escript)
mix deps.get
mix escript.build

# The vault wrapper handles everything automatically
./vault --help
```

### Commands

```bash
# Backup system configs to repo + vault data
./bin/vault save
./bin/vault save --vault-target /Volumes/Backup/VaultBackup
./bin/vault save --vault-target user@host:/backups/vault

# Restore configs only (from this repo)
./bin/vault restore

# Restore everything (configs + vault data)
./bin/vault restore --vault-target ~/VaultBackup
./bin/vault restore --vault-target user@host:/backups/vault

# Install applications from config/apps.yaml
./bin/vault install

# Check backup status
./bin/vault status
./bin/vault status --vault-target ~/VaultBackup

# With SSH key for remote targets
./bin/vault save --vault-target user@host:/backups/vault --ssh-key ~/.ssh/id_rsa
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
