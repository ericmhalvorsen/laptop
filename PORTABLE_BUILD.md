# Building and Using Portable Vault Executable

This document explains how to create and use a portable version of the Vault CLI that can run on fresh systems without requiring Elixir/Erlang to be pre-installed.

## The Chicken and Egg Problem

When restoring a fresh macOS system, you face a challenge:
- You need the Vault CLI to automate system setup
- But building Vault requires Elixir, Mix, and dependencies
- Installing these tools is part of what Vault should automate

## Solution: Burrito Portable Executable

[Burrito](https://github.com/burrito-elixir/burrito) creates self-contained Elixir executables that bundle the BEAM runtime. This means the executable can run on any compatible system without requiring Erlang/Elixir to be installed.

## Building the Portable Executable

### Prerequisites (One-Time Setup)

You need a working development system with:
- Elixir 1.19+
- Mix
- Git

### Build Steps

1. **On a system with Elixir installed**, navigate to the laptop repo:
   ```bash
   cd ~/code/laptop
   ```

2. **Run the build script:**
   ```bash
   ./bin/build_portable
   ```

   This will:
   - Clean previous builds
   - Fetch dependencies
   - Compile the application
   - Create portable executables for all supported platforms

3. **Find the portable executables** in `burrito_out/`:
   ```
   burrito_out/
   ├── vault_darwin_aarch64  # macOS Apple Silicon
   ├── vault_darwin_x86_64   # macOS Intel
   └── vault_linux_x86_64    # Linux
   ```

### Building for Specific Platforms

To build only for a specific platform:
```bash
./bin/build_portable macos_arm      # macOS Apple Silicon only
./bin/build_portable macos_intel    # macOS Intel only
./bin/build_portable linux          # Linux only
```

## Using on a Fresh System

### Quick Start

1. **Copy files to fresh system:**
   Copy these files to your fresh macOS system (e.g., via USB drive, network, cloud):
   - `burrito_out/vault_darwin_aarch64` (or appropriate executable)
   - `bin/bootstrap`

2. **Run the bootstrap script:**
   ```bash
   chmod +x bootstrap vault_darwin_aarch64
   ./bootstrap
   ```

   This will:
   - Install Homebrew
   - Install git and rsync
   - Create ~/code directory
   - Show next steps

3. **Clone your laptop repo:**
   ```bash
   git clone git@github.com:yourusername/laptop.git ~/code/laptop
   cd ~/code/laptop
   ```

4. **Run Vault to restore your system:**
   ```bash
   ./vault_darwin_aarch64 restore -v /path/to/backup
   ```

   Or install applications from apps.yaml:
   ```bash
   ./vault_darwin_aarch64 apps install
   ```

### Manual Setup (Without Bootstrap)

If you prefer manual setup:

1. **Install Homebrew:**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install essential tools:**
   ```bash
   brew install git rsync
   ```

3. **Clone laptop repo:**
   ```bash
   mkdir -p ~/code
   git clone git@github.com:yourusername/laptop.git ~/code/laptop
   cd ~/code/laptop
   ```

4. **Copy the portable executable** to the laptop directory:
   ```bash
   cp /path/to/vault_darwin_aarch64 ~/code/laptop/vault
   chmod +x ~/code/laptop/vault
   ```

5. **Run Vault:**
   ```bash
   ./vault restore -v /path/to/backup
   # or
   ./vault apps install
   ```

## Available Commands

The portable executable supports all standard Vault commands:

```bash
# Show help
./vault --help

# Restore from backup
./vault restore -v /Volumes/Backup/VaultBackup

# Install applications from config/apps.yaml
./vault apps install

# Save current system
./vault save -v /Volumes/Backup/VaultBackup

# Dry run (see what would happen)
./vault apps install --dry-run
```

## Apps.yaml Pattern

The portable executable uses the declarative `config/apps.yaml` file to define what should be installed. This file supports:

- **Homebrew formulas and casks** - Install via brew
- **Local .pkg installers** - Install from local files
- **Local .dmg images** - Mount and install from DMG files
- **Direct downloads** - Download and install from URLs

Example `config/apps.yaml`:
```yaml
version: 1

defaults:
  installers_dir: "~/Installers"

brew:
  formulas:
    - neovim
    - git
  casks:
    - visual-studio-code
    - docker

local_pkg:
  - name: Custom App
    id: custom-app
    pkg: "{installers}/private/CustomApp.pkg"
    requires_sudo: true

local_dmg:
  - name: Firefox
    id: firefox
    dmg: "{installers}/Firefox.dmg"
    app_name: "Firefox.app"
```

## Troubleshooting

### Build Issues

**Error: Can't find Burrito**
```bash
# Clean and retry
rm -rf deps _build
mix deps.get
./bin/build_portable
```

**Error: Burrito version incompatible**
```bash
# Update mix.lock
mix deps.update burrito
./bin/build_portable
```

### Runtime Issues

**Error: Permission denied**
```bash
# Ensure executable permissions
chmod +x vault_darwin_aarch64
```

**Error: Cannot open because developer cannot be verified**
```bash
# On macOS, allow the app to run
xattr -d com.apple.quarantine vault_darwin_aarch64
# Or right-click and select "Open"
```

## Updating the Portable Executable

When you make changes to Vault:

1. Commit your changes on the development system
2. Run `./bin/build_portable` to create new portable executables
3. Copy the new executables to wherever you need them
4. Test on a fresh system if possible

## Storage Recommendations

Store the portable executable in multiple places:
- USB drive (for emergency restore)
- Cloud storage (Dropbox, iCloud, etc.)
- External backup drive
- Network share

This ensures you always have access to bootstrap a fresh system.

## Technical Details

### How Burrito Works

Burrito:
1. Compiles your Elixir application
2. Creates an Erlang release
3. Bundles the entire BEAM runtime
4. Wraps it in a single executable file
5. Adds a launcher that extracts and runs the BEAM

The result is a ~50-80MB executable (compared to ~1.6MB escript) that includes everything needed to run.

### Platform Support

- **macOS Apple Silicon (aarch64)** - M1, M2, M3 Macs
- **macOS Intel (x86_64)** - Intel-based Macs
- **Linux (x86_64)** - Most Linux distributions

Each platform needs its own executable built on a compatible system.

### Comparison: Escript vs Burrito

| Feature | Escript | Burrito |
|---------|---------|---------|
| Size | ~1.6MB | ~50-80MB |
| Requires Erlang/Elixir | Yes | No |
| Startup time | Fast | Slightly slower (extraction) |
| Portability | Low | High |
| Best for | Development | Distribution |

## Next Steps

1. Build the portable executable on your development system
2. Test it on a fresh VM or system
3. Store copies in multiple safe locations
4. Update your restore documentation with the new process
5. Consider automating periodic builds to keep executables up-to-date
