# Obsidian Notes Backup and Restore

Guide for backing up and restoring your Obsidian notes vault.

## Finding Your Obsidian Vault

Obsidian vaults can be located anywhere on your system. Common locations:

- `~/Documents/Obsidian/`
- `~/Obsidian/`
- Custom location you specified when creating the vault

To find your vault location:
1. Open Obsidian
2. Click the vault switcher (bottom left)
3. Click the settings icon next to your vault name
4. The path will be shown in the vault settings

## Backup Methods

### Method 1: Obsidian Sync (Recommended for Convenience)

**Pros**: Automatic, encrypted, version history, works across devices
**Cons**: Paid service ($10/month or $96/year)

1. Subscribe to Obsidian Sync at https://obsidian.md/sync
2. In Obsidian Settings → Sync
3. Sign in with your Obsidian account
4. Create or connect to a remote vault
5. Choose what to sync (settings, plugins, themes, etc.)
6. Enable sync

On new device:
1. Install Obsidian
2. Sign in to Obsidian Sync
3. Connect to your synced vault
4. Wait for sync to complete

### Method 2: Git Version Control (Recommended for Developers)

**Pros**: Free, version history, great for tech users
**Cons**: Requires Git knowledge, manual process

#### Initial Setup

1. Navigate to your vault directory:
   ```bash
   cd ~/Documents/Obsidian/YourVaultName
   ```

2. Initialize git repository:
   ```bash
   git init
   ```

3. Create `.gitignore`:
   ```bash
   cat > .gitignore << 'EOF'
   .obsidian/workspace
   .obsidian/workspace.json
   .trash/
   .DS_Store
   EOF
   ```

4. Create initial commit:
   ```bash
   git add .
   git commit -m "Initial Obsidian vault backup"
   ```

5. Create GitHub repository and push:
   ```bash
   git remote add origin git@github.com:yourusername/obsidian-vault.git
   git branch -M main
   git push -u origin main
   ```

#### Regular Backups

Create a script to automate backups:

```bash
#!/bin/bash
# Save as ~/Documents/Obsidian/YourVaultName/backup.sh

cd "$(dirname "$0")"

git add .
git commit -m "Backup: $(date '+%Y-%m-%d %H:%M:%S')"
git push

echo "Obsidian vault backed up successfully"
```

Make it executable:
```bash
chmod +x backup.sh
```

Run it periodically or set up a cron job:
```bash
# Add to crontab (crontab -e)
0 */4 * * * cd ~/Documents/Obsidian/YourVaultName && ./backup.sh
```

#### Restore on New Mac

```bash
cd ~/Documents/Obsidian
git clone git@github.com:yourusername/obsidian-vault.git YourVaultName
```

Then open the folder as a vault in Obsidian.

### Method 3: Cloud Storage (iCloud, Dropbox, etc.)

**Pros**: Automatic, simple, built into macOS (iCloud)
**Cons**: Sync conflicts possible, not version controlled

#### Using iCloud

1. Move vault to iCloud Drive:
   ```bash
   mv ~/Documents/Obsidian/YourVaultName ~/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian/
   ```

2. In Obsidian, open vault from new location

3. On new Mac, wait for iCloud sync, then open vault

#### Using Dropbox

1. Move vault to Dropbox:
   ```bash
   mv ~/Documents/Obsidian/YourVaultName ~/Dropbox/Obsidian/
   ```

2. On new Mac, install Dropbox and wait for sync

3. Open vault from Dropbox folder

### Method 4: Manual Backup (Simplest)

**Pros**: Simple, no external dependencies
**Cons**: Manual, no version history, can forget

Create a backup script:

```bash
#!/bin/bash
# Save as ~/backup-obsidian.sh

VAULT_PATH="$HOME/Documents/Obsidian/YourVaultName"
BACKUP_DIR="$HOME/obsidian-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"
cp -r "$VAULT_PATH" "$BACKUP_DIR/vault-backup-$TIMESTAMP"

# Keep only last 10 backups
cd "$BACKUP_DIR"
ls -t | tail -n +11 | xargs rm -rf

echo "Backup created: $BACKUP_DIR/vault-backup-$TIMESTAMP"
```

Run manually or via cron job.

## What to Backup

### Essential
- All `.md` files (your notes)
- Attachments folder (images, PDFs, etc.)
- `.obsidian/plugins/` (custom plugins)
- `.obsidian/themes/` (custom themes)

### Optional (Settings)
- `.obsidian/app.json` (app settings)
- `.obsidian/appearance.json` (appearance settings)
- `.obsidian/core-plugins.json` (core plugins config)
- `.obsidian/community-plugins.json` (community plugins list)
- `.obsidian/hotkeys.json` (keyboard shortcuts)

### Skip
- `.obsidian/workspace` or `.obsidian/workspace.json` (session data)
- `.trash/` (deleted notes)
- `.DS_Store` (macOS metadata)

## Restore Process

### From Git

```bash
cd ~/Documents/Obsidian
git clone <your-repo-url> YourVaultName
```

### From Manual Backup

```bash
cp -r ~/obsidian-backups/vault-backup-TIMESTAMP ~/Documents/Obsidian/YourVaultName
```

### From Cloud Storage

Wait for sync to complete, then open vault in Obsidian.

## Opening Vault in Obsidian

1. Install Obsidian from https://obsidian.md or via Homebrew:
   ```bash
   brew install --cask obsidian
   ```

2. Open Obsidian

3. Click "Open folder as vault"

4. Navigate to your vault location and select it

5. Obsidian will index your notes

## Community Plugins

If you use community plugins, you may need to:

1. Trust the vault when opening
2. Enable community plugins in Settings → Community plugins
3. Wait for plugins to download (if using Sync)
4. Or manually reinstall plugins from Settings → Community plugins → Browse

## Tips

1. **Test your backups** - Periodically restore to verify backups work
2. **Multiple methods** - Use 2+ backup methods (e.g., Git + Obsidian Sync)
3. **Version history** - Git or Obsidian Sync provide version history
4. **Automation** - Automate backups so you don't forget
5. **Privacy** - If using Git, use private repository for personal notes
6. **Large files** - Git may struggle with many large attachments; consider Git LFS
7. **Mobile sync** - Obsidian Sync is best for iOS/Android sync

## Automated Git Backup with Obsidian Plugin

Install "Obsidian Git" community plugin:

1. Settings → Community plugins → Browse
2. Search for "Obsidian Git"
3. Install and enable
4. Configure backup interval (e.g., every 4 hours)
5. Plugin will auto-commit and push changes

This is the easiest Git method!

## Comparison Table

| Method | Cost | Auto | History | Difficulty | Mobile |
|--------|------|------|---------|------------|--------|
| Obsidian Sync | $$ | ✅ | ✅ | Easy | ✅ |
| Git | Free | ⚠️ | ✅ | Medium | ❌ |
| Git + Plugin | Free | ✅ | ✅ | Easy | ❌ |
| iCloud | Free | ✅ | ❌ | Easy | ✅ |
| Dropbox | Free/$ | ✅ | ❌ | Easy | ✅ |
| Manual | Free | ❌ | ❌ | Easy | ❌ |

## Recommended Setup

For most users: **Obsidian Sync** (if willing to pay) or **Git with Obsidian Git plugin** (free)

For developers: **Git** with manual commits or automated script

For simple backup: **iCloud Drive** + **Manual backups**

For maximum safety: **Git** + **Obsidian Sync** (redundancy)
