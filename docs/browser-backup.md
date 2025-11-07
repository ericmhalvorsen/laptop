# Browser Data Backup and Restore

This guide covers backing up and restoring browser data for Brave and Chrome.

## Brave Browser

### Backup

Brave stores its data in the following locations on macOS:

- **Profile Data**: `~/Library/Application Support/BraveSoftware/Brave-Browser/`
- **Key locations**:
  - `Default/` - Default profile (bookmarks, history, extensions, etc.)
  - `Local State` - Browser settings

#### Manual Backup Steps

1. **Close Brave completely**

2. **Backup the entire profile**:
   ```bash
   cp -r ~/Library/Application\ Support/BraveSoftware/Brave-Browser/ ~/brave-backup/
   ```

3. **Essential files to backup** (if you want selective backup):
   - `Default/Bookmarks` - Bookmarks
   - `Default/History` - Browsing history
   - `Default/Cookies` - Cookies
   - `Default/Login Data` - Saved passwords
   - `Default/Preferences` - Settings
   - `Default/Extensions/` - Installed extensions
   - `Local State` - Browser-level settings

#### Using Brave Sync (Recommended)

1. Open Brave Settings → Sync
2. Set up a sync chain
3. Save your sync code securely
4. On new device, use "I have a sync code" option

### Restore

1. **Close Brave**

2. **Full restore**:
   ```bash
   rm -rf ~/Library/Application\ Support/BraveSoftware/Brave-Browser/
   cp -r ~/brave-backup/ ~/Library/Application\ Support/BraveSoftware/Brave-Browser/
   ```

3. **Selective restore** (copy individual files back to their locations)

## Chrome Browser

### Backup

Chrome stores its data in:

- **Profile Data**: `~/Library/Application Support/Google/Chrome/`
- **Key locations**:
  - `Default/` - Default profile
  - `Profile 1/`, `Profile 2/` - Additional profiles
  - `Local State` - Browser settings

#### Manual Backup Steps

1. **Close Chrome completely**

2. **Backup the entire profile**:
   ```bash
   cp -r ~/Library/Application\ Support/Google/Chrome/ ~/chrome-backup/
   ```

3. **Essential files** (similar to Brave):
   - `Default/Bookmarks`
   - `Default/History`
   - `Default/Cookies`
   - `Default/Login Data`
   - `Default/Preferences`
   - `Default/Extensions/`
   - `Local State`

#### Using Chrome Sync (Recommended)

1. Sign in to Chrome with your Google account
2. Enable sync in Settings → Sync and Google Services
3. Choose what to sync (bookmarks, history, passwords, etc.)
4. On new device, sign in and sync will restore everything

### Restore

1. **Close Chrome**

2. **Full restore**:
   ```bash
   rm -rf ~/Library/Application\ Support/Google/Chrome/
   cp -r ~/chrome-backup/ ~/Library/Application\ Support/Google/Chrome/
   ```

3. **Selective restore** (copy individual files back)

## Automated Backup Script

You can create a script to backup both browsers:

```bash
#!/bin/bash

BACKUP_DIR="$HOME/browser-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup Brave
if [[ -d "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" ]]; then
    echo "Backing up Brave..."
    cp -r "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" "$BACKUP_DIR/brave"
fi

# Backup Chrome
if [[ -d "$HOME/Library/Application Support/Google/Chrome" ]]; then
    echo "Backing up Chrome..."
    cp -r "$HOME/Library/Application Support/Google/Chrome" "$BACKUP_DIR/chrome"
fi

echo "Backup complete: $BACKUP_DIR"
```

## Best Practices

1. **Use built-in sync** - Both Brave and Chrome have excellent sync features
2. **Export bookmarks** - Regularly export bookmarks as HTML (Settings → Bookmarks → Bookmark manager → Export)
3. **Password manager** - Consider using a dedicated password manager instead of browser storage
4. **Extensions list** - Keep a list of your essential extensions
5. **Close browsers** - Always close browsers completely before backing up to avoid corrupt data
6. **Test restores** - Periodically test that your backups work

## Important Notes

- Browser data can be large (several GB), so ensure you have enough space
- Backing up while browser is running may result in corrupted data
- Some extensions may require re-authentication after restore
- Login sessions may expire and require re-login
- Consider using browser sync as your primary backup method and file backup as secondary

## Quick Reference

### Brave Locations
```
~/Library/Application Support/BraveSoftware/Brave-Browser/
```

### Chrome Locations
```
~/Library/Application Support/Google/Chrome/
```

### View Hidden Library Folder
```bash
# Open in Finder
open ~/Library

# Or make Library visible in Finder
chflags nohidden ~/Library/
```
