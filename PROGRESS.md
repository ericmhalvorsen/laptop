# Vault - Progress Tracking

**Last Updated**: 2025-11-08

## Current Status

**Phase**: 7 Implemented - Restore MVP ✅

**Stats**:
- 70 tests passing (0 failures)
- 61.4% overall coverage
- 3 backup modules complete: Dotfiles, Config, Homebrew

## Completed Phases

### ✅ Phase 1: Planning & Setup
- Project documentation and architecture design
- Owl framework research and best practices
- CLAUDE.md context file for AI assistance

### ✅ Phase 2: CLI Framework
- Elixir/Erlang setup with mise
- Basic CLI structure with Owl UI
- Escript build configuration
- Beautiful colored terminal output

### ✅ Phase 3: Testing Infrastructure
- ExUnit testing framework
- Test coverage reporting (excoveralls)
- Temp directory test patterns
- 89.4% coverage on FileUtils

### ✅ Phase 4: Core Backup (Tier 1 - Git Repo)
**Dotfiles Module** (17 tests, 76.7% coverage):
- Backs up standard dotfiles from home directory
- Handles ~/.local/bin scripts separately
- Preserves file permissions
- Integrated into `vault save`

**Config Module** (16 tests, 91.2% coverage):
- Backs up ~/.config directories
- Supports git, mise, and other app configs
- Preserves nested directory structures
- Extensible design for new apps

**Homebrew Module** (14 tests, 78.9% coverage):
- Generates complete Brewfile via `brew bundle dump`
- Exports formulas.txt, casks.txt, taps.txt
- Shows counts in UI (72 formulas, 0 casks, 3 taps)
- All files committed to git

### Phase 5: Home Directory Backup (Tier 2 - Vault)
**Goal**: Backup major home directories to vault (NOT git)

- Backs up public home directories to `~/VaultBackup/home/`
- Uses rsync when available (with excludes); falls back to recursive copy
- Progress indicators for large transfers
- Excludes common junk: `.DS_Store`, `node_modules`, `.git`, `.cache`, etc.

### Phase 7: Restore Command
- Implements 4-step restore flow:
  1) Restore home directories from `vault/home`
  2) Restore fonts (`vault/fonts`), dotfiles (`vault/dotfiles`), and `local-bin`
  3) Restore Application Support from `vault/app-support`
  4) Run install pipeline (`vault install`)
- Supports `--vault-path` and `--dry-run`
- Non-destructive copy (no deletes) to avoid data loss

## Next Phases

### Phase 6: Browser & App Data Backup (Tier 2)
- [ ] Browser data (Brave, Chrome) → vault
- [ ] Obsidian vaults → vault
- [ ] Application configs/data → vault (post-install)


### Phase 8: Polish & UX
- [ ] Status command (show what's backed up)
- [ ] Diff command (compare system to backups)
- [ ] Better error handling and recovery
- [ ] Dry-run mode for all commands

### Phase 9: Documentation & Release
- [ ] Update README with complete usage
- [ ] Create quickstart guide
- [ ] Test on clean Mac
- [ ] Optional: Burrito portable executable

## Architecture

### Two-Tier Backup System

**Tier 1: Git Repository** (Lightweight - Committed to Git)
```
laptop/
├── dotfiles/        # Dotfiles from ~
├── config/          # App configs from ~/.config
├── local-bin/       # Scripts from ~/.local/bin
├── brew/            # Homebrew package lists
│   ├── Brewfile
│   ├── formulas.txt
│   ├── casks.txt
│   └── taps.txt
└── lib/vault/       # CLI source code
```

**Tier 2: Vault Directory** (Heavy Data - NOT in Git)
```
~/VaultBackup/
├── home/            # Home directories (rsync'd)
│   ├── Documents/
│   ├── Downloads/
│   ├── Pictures/
│   └── Desktop/
├── browser/         # Browser data
│   ├── brave/
│   └── chrome/
├── obsidian/        # Obsidian vaults
└── app-data/        # App-specific settings
```

## Test Coverage by Module

```
100.0% - lib/vault.ex
100.0% - lib/vault/application.ex
 91.2% - lib/vault/backup/config.ex
 76.7% - lib/vault/backup/dotfiles.ex
 78.9% - lib/vault/backup/homebrew.ex
 89.4% - lib/vault/utils/file_utils.ex
  0.0% - Commands (thin orchestration layer)
────────────────────────────────────────
 61.4% - TOTAL
```

## Commands

```bash
# Backup (Tier 1 to git repo, Tier 2 to vault)
./vault save                                    # Tier 1 only
./vault save --vault-path ~/VaultBackup        # Tier 1 + Tier 2

# Restore
./vault restore                                 # Tier 1 only (quick setup)
./vault restore --vault-path ~/VaultBackup     # Tier 1 + Tier 2 (full restore)

# Status (future)
./vault status
./vault status --vault-path ~/VaultBackup
```

## LAST UPDATE

Tested install - it fails on Falcon package.

▶ Installing local .pkg installers

  Installing Falcon from /Users/eric/Installers/Falcon.pkg
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
** (FunctionClauseError) no function clause matching in Owl.Data.do_chunk_by/5

    The following arguments were given to Owl.Data.do_chunk_by/5:

        # 1
        %IO.Stream{device: :standard_io, raw: false, line_or_bytes: :line}

        # 2
        nil

        # 3
        #Function<10.122660863/2 in Owl.Data.split/2>

        # 4
        []

        # 5
        []

    (owl 0.13.0) lib/owl/data.ex:632: Owl.Data.do_chunk_by/5
    (owl 0.13.0) lib/owl/data.ex:633: Owl.Data.do_chunk_by/5
    (owl 0.13.0) lib/owl/data.ex:620: Owl.Data.chunk_by/4
    (owl 0.13.0) lib/owl/data.ex:627: Owl.Data.chunk_by/4
    (owl 0.13.0) lib/owl/data.ex:295: Owl.Data.to_chardata/1
    (owl 0.13.0) lib/owl/io.ex:553: Owl.IO.puts/2
    (elixir 1.19.2) lib/enum.ex:961: Enum."-each/2-lists^foreach/1-0-"/2
    (vault 0.1.0) lib/vault/commands/install.ex:20: Vault.Commands.Install.run/2


We should see if there's a way to fix but if not a nice solution might just be to pop open the directory with installers that couldn't auto install.
This separates the auto-install from the vault - we want the git repo scenario to work in isolation even if the Installers don't exist. The apps.yaml
file having knowledge of the custom installers feels wrong.

