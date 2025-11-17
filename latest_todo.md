# System Restore - Original Issues

## Chicken and Egg Problem - SOLVED ✓

The original restore process required:
1. Install homebrew
2. brew install git rsync
3. Clone laptop repo
4. brew install mise
5. mise install (Elixir/Erlang)
6. Build vault escript
7. Run vault restore

**Problem:** You need Elixir to build vault, but you want vault to set up Elixir!

**Solution:** Burrito portable executable
- Build once on a system with Elixir
- Get a self-contained executable that includes BEAM runtime
- Copy to fresh system and run immediately
- No dependencies needed!

See: PORTABLE_BUILD.md and QUICK_RESTORE.md

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

