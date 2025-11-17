# System Restore - Original Issues

## Chicken and Egg Problem - SOLVED ✓

**Problem:** You need Elixir to build vault, but you want vault to set up Elixir!

**Solution:** Self-bootstrapping wrapper script

The `vault` script is now a bash wrapper that:
1. Checks if the real vault escript exists
2. If not, installs Homebrew → mise → builds escript
3. Delegates to the real escript with your command

**Fresh system restore is now:**
```bash
git clone <repo> ~/code/laptop
cd ~/code/laptop
./vault restore -v /path/to/backup
```

Single entry point, zero manual steps!

See: QUICK_RESTORE.md

## Outstanding Issues to Fix

### 1. Owl.Data.do_chunk_by/5 Error
Install breaks with: "No function clause matching in Owl.Data.do_chunk_by/5"
- Need to investigate this error
- Occurs during restore process

### 2. Restore Progress
- Restore has no progress indication
- Need to add progress bars/status updates

### 3. Photo Library Permissions
- Breaks on photolibrary permissions
- Need to handle macOS permission dialogs
- Possibly add pre-flight permission checks

### 4. Manual Installs Still Needed
- Cursor + VSCode
- Licenses for Nord and Falcon
- ExpressVPN

These could potentially be added to apps.yaml:
```yaml
brew:
  casks:
    - visual-studio-code
    - cursor
    - expressvpn

local_pkg:
  - name: NordLayer
    pkg: "{installers}/private/NordLayer.pkg"
  - name: Falcon
    pkg: "{installers}/private/Falcon.pkg"
```

## License Key
JDR9-4VD2-CK5V-JVDK-6GP4-YWEM

