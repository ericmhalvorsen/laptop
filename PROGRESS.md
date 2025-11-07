# Vault - Mac Setup CLI Tool

## Project Vision

Transform the current shell script-based Mac setup tool into a modern CLI application called "Vault" that:
- Provides a clean command interface for backup/restore operations
- Separates lightweight config (repo) from heavy data (vault directory)
- Handles both dotfiles/configs AND full home directory backups
- Uses modern CLI framework with proper testing

## Architecture

### Current State
- Shell scripts: `backup.sh` and `setup.sh`
- Everything committed to git repo
- Manual handling of sensitive files

### Target State
- **Vault CLI**: Modern Elixir-based CLI tool (using Owl framework)
- **Git Repo**: Contains CLI tool + lightweight configs (committed to git)
  - Dotfiles (.zshrc, .gitconfig, etc.)
  - App configs (.config directories)
  - Local scripts (.local/bin)
  - Homebrew package lists
- **Vault Directory**: Separate storage for heavy data (NOT in git)
  - Browser data (settings, history, bookmarks)
  - Application data (app-specific settings)
  - Obsidian notes
  - Home directory data (Documents, Downloads, Pictures, Desktop, etc.)
  - Sensitive files (.netrc, SSH keys, GPG keys)
- **Applications**: Install from latest sources (Homebrew, GitHub releases, etc.)
  - No app installer backups - always get latest version
  - Restore application settings/configs from vault

## Progress Tracking

### Phase 1: Planning & Setup ✅
- [x] Create initial shell scripts
- [x] Document browser backup process
- [x] Document Obsidian backup process
- [x] Create PROGRESS.md
- [x] Create CLAUDE.md with project context
- [x] Research Owl framework and document best practices

### Phase 2: CLI Framework Setup ✅
- [x] Research and evaluate Owl framework
- [x] Set up Elixir/Erlang development environment (using mise)
- [x] Initialize new Elixir project structure
- [x] Configure Mix project with dependencies (Owl, ucwidth)
- [x] Set up basic CLI skeleton with Owl
- [x] Create initial command structure (`vault save`, `vault restore`, `vault status`)
- [x] Build and test escript
- [x] Create wrapper script for easy execution

### Phase 2.5: Portable Executable Research ✅
- [x] Research Burrito for self-contained executables
- [x] Research Bakeware for single-file deployments
- [x] Evaluate trade-offs (file size, compatibility, ease of use)
- [x] Document portable build process in CLAUDE.md
- [ ] (Optional) Test building portable executable with Burrito
- [ ] (Optional) Add Burrito as alternative build target

**Decision**: Keep escript for development (fast, small). Add Burrito as optional distribution target later.

**Key Findings**:
- Burrito creates truly portable binaries (no Erlang required)
- File size: ~20-40MB (vs 1.5MB escript) due to bundled Erlang runtime
- Requires code signing for macOS or users get Gatekeeper warnings
- Great for distribution, but escript better for development
- Hybrid approach: escript for dev, Burrito for releases

### Phase 3: Testing Infrastructure
- [ ] Set up ExUnit testing framework
- [ ] Create test helpers and fixtures
- [ ] Write tests for file operations
- [ ] Write tests for backup logic
- [ ] Write tests for restore logic
- [ ] Set up CI/CD for automated testing
- [ ] Add test coverage reporting

### Phase 4: Core Backup Command (`vault save`)
- [ ] Implement dotfiles backup
  - [ ] Detect and copy standard dotfiles
  - [ ] Handle .local/bin scripts
  - [ ] Preserve file permissions
- [ ] Implement .config directory backup
  - [ ] Starship, mise, git configs
  - [ ] Claude Code configuration (settings, not logs)
  - [ ] Warp settings and themes
- [ ] Implement Homebrew backup
  - [ ] Export formulas list
  - [ ] Export casks list
  - [ ] Generate Brewfile
- [ ] Add tests for each backup component

### Phase 5: Extended Backup Features
- [ ] Implement home directory backup with rsync
  - [ ] Documents directory
  - [ ] Downloads directory
  - [ ] Pictures directory
  - [ ] Desktop directory
  - [ ] Add excludes for common junk (.DS_Store, etc.)
  - [ ] Progress indicator during rsync
- [ ] Implement browser backup
  - [ ] Brave browser data
  - [ ] Chrome browser data
  - [ ] Handle running browser gracefully
- [ ] Implement Obsidian backup
  - [ ] Detect vault location(s)
  - [ ] Copy vault with proper structure
  - [ ] Exclude workspace cache
- [ ] Implement application wrapper backup
  - [ ] Yaak
  - [ ] RustDesk
  - [ ] Docker Desktop
  - [ ] Warp
- [ ] Backup git-ignored sensitive files
  - [ ] .netrc
  - [ ] anthropic_key.sh
  - [ ] SSH keys (optional, with warning)
  - [ ] GPG keys (optional, with warning)
- [ ] Add tests for all extended features

### Phase 6: Warp Configuration Deep Dive
- [ ] Research Warp config file locations
  - [ ] Settings location
  - [ ] Theme files location
  - [ ] Custom blocks location
  - [ ] Launch configurations
- [ ] Implement comprehensive Warp backup
- [ ] Test Warp restore on clean install
- [ ] Document manual steps if any required

### Phase 7: Restore Command (`vault restore`)
- [ ] Implement dotfiles restore
  - [ ] Copy files from vault to home
  - [ ] Preserve permissions
  - [ ] Backup existing files before overwrite
- [ ] Implement .config restore
- [ ] Implement Homebrew restore
  - [ ] Install Homebrew if missing
  - [ ] Install from Brewfile
  - [ ] Handle failed installations gracefully
- [ ] Implement oh-my-zsh setup
- [ ] Implement application installations
  - [ ] Copy app wrappers from vault
  - [ ] Handle DMG mounting/copying
  - [ ] Verify installations
- [ ] Add tests for restore operations

### Phase 8: Extended Restore Features
- [ ] Implement home directory restore
  - [ ] rsync from vault back to home
  - [ ] Progress indicators
  - [ ] Dry-run option
- [ ] Implement browser data restore
  - [ ] Check if browser is running
  - [ ] Restore Brave data
  - [ ] Restore Chrome data
- [ ] Implement Obsidian restore
  - [ ] Copy vault to destination
  - [ ] Prompt for vault location
- [ ] Implement application config restore
  - [ ] Warp settings
  - [ ] Claude Code settings
  - [ ] Other app configs
- [ ] Add tests for extended restore

### Phase 9: Additional CLI Commands
- [ ] Implement `vault status`
  - [ ] Show what's backed up
  - [ ] Show backup age
  - [ ] Show vault size
  - [ ] Show what's missing from backup
- [ ] Implement `vault diff`
  - [ ] Compare current system to vault
  - [ ] Show changed dotfiles
  - [ ] Show new/removed files
- [ ] Implement `vault list`
  - [ ] List all backed up components
  - [ ] Show backup dates
- [ ] Implement `vault verify`
  - [ ] Check vault integrity
  - [ ] Verify all expected files exist
- [ ] Add tests for utility commands

### Phase 10: User Experience
- [ ] Add colorful output (via Owl)
- [ ] Add progress bars for long operations
- [ ] Add interactive prompts for dangerous operations
- [ ] Add verbose/quiet modes
- [ ] Add dry-run mode for testing
- [ ] Improve error messages and recovery
- [ ] Add confirmation prompts
- [ ] Add logging to file

### Phase 11: Migration & Documentation
- [ ] Create migration guide from shell scripts to CLI
- [ ] Update README.md for CLI usage
- [ ] Create man pages or help documentation
- [ ] Add inline help for all commands
- [ ] Create quickstart guide
- [ ] Update browser backup docs for CLI
- [ ] Update Obsidian backup docs for CLI
- [ ] Add troubleshooting guide

### Phase 12: Packaging & Distribution
- [ ] Create escript build
- [ ] Add installation script
- [ ] Create release workflow
- [ ] Add version command
- [ ] Create update mechanism
- [ ] Test on clean Mac
- [ ] Create homebrew formula (optional)

### Phase 13: Cleanup
- [ ] Archive old shell scripts
- [ ] Remove redundant documentation
- [ ] Final testing on multiple Macs
- [ ] Create demo video/GIF
- [ ] Celebrate! 🎉

## Technical Decisions

### Why Owl Framework?
- Modern Elixir CLI framework
- Built-in components: progress bars, spinners, prompts
- Excellent for interactive CLIs
- Good documentation and examples

### Why Separate Vault Directory?
- Keeps git repo lightweight
- Allows vault to be backed up to external drive
- Can exclude vault from git entirely
- Makes it easier to handle large files (apps, browser data)

### Repository vs Vault

**Git Repository** (`~/code/laptop/`):
- Vault CLI tool (Elixir code)
- Documentation
- Tests
- Installation scripts
- No heavy files
- Safe to commit and push

**Vault Directory** (e.g., `~/VaultBackup/` or external drive):
- All dotfiles
- All configs
- Application installers
- Browser data
- Obsidian vaults
- Home directory data
- Sensitive files
- Can be synced to external backup drive
- NOT committed to git

## Commands Design

```bash
# Save current system
vault save [--vault-path PATH] [--full] [--exclude PATTERN]
  # Saves lightweight configs to git repo (dotfiles, configs, brew)
  # Saves heavy data to vault directory (apps, browser, home dirs)

# Restore from backups
vault restore [--vault-path PATH] [--dry-run] [--component COMPONENT]
  # Without --vault-path: Restore only git repo configs (data-less)
  # With --vault-path: Restore both repo configs + vault data

# Show vault status
vault status [--vault-path PATH]
  # Shows what's in repo vs what's in vault

# Compare current system to backups
vault diff [--vault-path PATH]

# List backup contents
vault list [--vault-path PATH]

# Verify backup integrity
vault verify [--vault-path PATH]

# Initialize new vault
vault init [--vault-path PATH]
```

## Configuration

Vault will support a config file at `~/.vault/config.toml`:

```toml
[vault]
default_path = "/Users/eric/VaultBackup"

[backup]
exclude_patterns = [".DS_Store", "node_modules"]
include_home_dirs = ["Documents", "Downloads", "Pictures", "Desktop"]

[backup.dotfiles]
files = [".zshrc", ".gitconfig", ".vimrc"]

[backup.apps]
backup_installers = true

[restore]
confirm_overwrites = true
backup_existing = true
```

## File Structure

```
laptop/                          # Git repository (committed to GitHub)
├── lib/
│   └── vault/
│       ├── cli.ex              # Main CLI entry
│       ├── commands/
│       │   ├── save.ex         # Save command
│       │   ├── restore.ex      # Restore command
│       │   ├── status.ex       # Status command
│       │   └── ...
│       ├── backup/
│       │   ├── dotfiles.ex     # Backs up to repo
│       │   ├── homebrew.ex     # Backs up to repo
│       │   ├── apps.ex         # Backs up to vault
│       │   ├── browser.ex      # Backs up to vault
│       │   └── home_dirs.ex    # Backs up to vault
│       └── restore/
│           └── ...
├── dotfiles/                    # COMMITTED - Backed up dotfiles
│   ├── .zshrc
│   ├── .gitconfig
│   └── ...
├── config/                      # COMMITTED - App configs
│   ├── claude/
│   ├── warp/
│   ├── mise/
│   └── ...
├── local-bin/                   # COMMITTED - Custom scripts
│   ├── claude-wrapper
│   └── ...
├── brew/                        # COMMITTED - Homebrew lists
│   ├── Brewfile
│   ├── formulas.txt
│   └── casks.txt
├── test/
│   └── vault/
│       ├── commands/
│       └── backup/
├── mix.exs
├── README.md
├── PROGRESS.md                  # This file
├── docs/
│   ├── browser-backup.md
│   └── obsidian-backup.md
└── legacy/                      # Old shell scripts
    ├── backup.sh
    └── setup.sh

~/VaultBackup/                   # Vault directory (NOT in git)
├── browser/                     # Browser data
│   ├── brave/
│   └── chrome/
├── app-data/                    # Application settings/data
│   ├── warp/                    # Warp settings (post-install)
│   ├── yaak/                    # Yaak settings (post-install)
│   └── ...
├── obsidian/                    # Obsidian vaults
│   └── YourVault/
├── home/                        # Home directory data
│   ├── Documents/
│   ├── Downloads/
│   ├── Pictures/
│   ├── Desktop/
│   └── ...
└── sensitive/                   # Sensitive files
    ├── .netrc
    ├── ssh-keys/
    ├── gpg-keys/
    └── ...

Note: Applications installed from latest sources, NOT backed up
```

## Notes & Decisions

### Open Questions
- [ ] Should vault directory be encrypted?
- [ ] Should we support multiple vault "profiles"?
- [ ] Should we integrate with Time Machine?
- [ ] Should we support cloud backup (S3, Dropbox)?

### Risks & Mitigations
- **Large files**: Use streaming/rsync for efficiency
- **Long operations**: Add progress indicators
- **Failed restores**: Always backup before overwriting
- **Missing dependencies**: Check and install Erlang/Elixir
- **Permissions**: Handle sudo gracefully

## Getting Started with Development

1. Install Elixir:
   ```bash
   brew install elixir
   ```

2. Initialize Mix project:
   ```bash
   mix new vault --sup
   ```

3. Add Owl dependency to `mix.exs`:
   ```elixir
   {:owl, "~> 0.11"}
   ```

4. Run tests:
   ```bash
   mix test
   ```

5. Build escript:
   ```bash
   mix escript.build
   ```

## Timeline Estimate

- Phase 2-3 (Setup): 1-2 days
- Phase 4-5 (Backup): 3-4 days
- Phase 6 (Warp): 1 day
- Phase 7-8 (Restore): 3-4 days
- Phase 9 (Commands): 2 days
- Phase 10-11 (UX/Docs): 2-3 days
- Phase 12-13 (Package/Test): 2-3 days

**Total: ~2-3 weeks of focused development**

## Current Status

**Last Updated**: 2025-11-06

**Current Phase**: Phase 3 Ready to Start

**Completed**:
- ✅ Phase 1: Planning, documentation, and Owl research
- ✅ Phase 2: CLI Framework Setup - Working escript with beautiful Owl UI!
- ✅ Phase 2.5: Portable Executable Research - Documented Burrito for future releases

**Next Steps**:
- Set up ExUnit testing framework
- Create test helpers and fixtures
- Begin implementing actual backup functionality (dotfiles, homebrew, etc.)
