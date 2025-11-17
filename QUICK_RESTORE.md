# Quick Restore Guide

## One-Time Preparation (Do This Now!)

Build the portable executable on a system with Elixir:

```bash
cd ~/code/laptop
./bin/build_portable
```

Store these files in a safe, accessible location (USB drive, cloud, etc.):
- `burrito_out/vault_darwin_aarch64` (or your platform)
- `bin/bootstrap`

## On a Fresh System

### Method 1: Bootstrap Script (Recommended)

```bash
# 1. Copy files to fresh system
#    - bootstrap script
#    - vault portable executable

# 2. Make executable and run
chmod +x bootstrap vault_darwin_aarch64
./bootstrap

# 3. Clone repo
git clone git@github.com:yourusername/laptop.git ~/code/laptop
cd ~/code/laptop

# 4. Restore
./vault_darwin_aarch64 restore -v /path/to/backup
```

### Method 2: Manual Steps

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install essentials
brew install git rsync

# 3. Clone repo
mkdir -p ~/code
git clone git@github.com:yourusername/laptop.git ~/code/laptop
cd ~/code/laptop

# 4. Copy portable executable to repo
cp /path/to/vault_darwin_aarch64 ./vault
chmod +x ./vault

# 5. Restore
./vault restore -v /path/to/backup
```

## Just Install Apps (No Full Restore)

```bash
cd ~/code/laptop
./vault apps install
```

This installs everything defined in `config/apps.yaml`:
- Homebrew formulas and casks
- Local installers from `~/Installers`
- Applications from DMG files

## Common Issues

**"Cannot open vault because developer cannot be verified"**
```bash
xattr -d com.apple.quarantine vault_darwin_aarch64
```

**Permission denied**
```bash
chmod +x vault_darwin_aarch64
```

**Wrong architecture**
- Use `vault_darwin_aarch64` for Apple Silicon (M1/M2/M3)
- Use `vault_darwin_x86_64` for Intel Macs

## Files Needed on Fresh System

Minimum:
- `vault_darwin_aarch64` (or your platform)

Recommended:
- `bootstrap` script
- Access to your backup (external drive, network, etc.)
- SSH keys (for git clone)
