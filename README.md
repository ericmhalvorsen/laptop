# macOS Dotfiles

Personal macOS configuration and backup system.

## Vault Tool

Elixir-based CLI for backing up/restoring system configurations.

### Setup

```bash
# Install Elixir/Erlang via mise
mise use elixir@latest erlang@latest

# Build vault tool
mise exec -- mix deps.get
mise exec -- mix escript.build
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
