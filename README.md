# macOS Setup Scripts

Automated setup scripts for configuring a new Mac with all your applications, dotfiles, and configurations.

## Overview

This repository contains scripts to backup your current Mac configuration and restore it on a new machine. It handles:

- ✅ Dotfiles (.zshrc, .gitconfig, .vimrc, etc.)
- ✅ Scripts in .local/bin
- ✅ Homebrew packages (formulas and casks)
- ✅ Application configurations (.config directories)
- ✅ Claude Code settings
- ✅ Warp terminal configuration
- ✅ oh-my-zsh setup
- ✅ Development tools (NVM, asdf, mise, etc.)
- ✅ Applications (Yaak, RustDesk, Docker, Warp)
- 📖 Browser data (manual - see docs/browser-backup.md)
- 📖 Obsidian notes (manual backup recommended)

## Quick Start

### On Your Current Mac (Backup)

1. Clone this repository:
   ```bash
   cd ~/code
   git clone <your-repo-url> laptop
   cd laptop
   ```

2. Run the backup script:
   ```bash
   ./backup.sh
   ```

3. Commit and push to GitHub:
   ```bash
   git add .
   git commit -m "Backup Mac configuration"
   git push
   ```

### On Your New Mac (Restore)

1. Install Xcode Command Line Tools (if not already installed):
   ```bash
   xcode-select --install
   ```

2. Clone this repository:
   ```bash
   mkdir -p ~/code
   cd ~/code
   git clone <your-repo-url> laptop
   cd laptop
   ```

3. Run the setup script:
   ```bash
   ./setup.sh
   ```

4. Follow any prompts and wait for completion

5. Restart your terminal or run:
   ```bash
   source ~/.zshrc
   ```

## What Gets Backed Up

### Dotfiles
- `.zshrc` - Zsh configuration
- `.zshenv` - Zsh environment variables
- `.zprofile` - Zsh profile
- `.bashrc`, `.bash_profile` - Bash configuration
- `.gitconfig` - Git configuration
- `.vimrc` - Vim configuration
- `.irbrc` - Ruby IRB configuration
- `.netrc` - Network credentials

### Scripts
- All scripts in `~/.local/bin/`

### Configurations
- Starship prompt config
- Mise (dev tool version manager)
- Git config
- Claude Code settings
- Warp terminal settings

### Applications & Packages
- Complete Homebrew formula list
- Complete Homebrew cask list
- Brewfile for easy restoration

## Scripts

### Main Scripts

- **`backup.sh`** - Backup current Mac configuration
- **`setup.sh`** - Main setup script for new Mac

### Subscripts (in `scripts/`)

- **`dotfiles-restore.sh`** - Restore dotfiles to home directory
- **`brew-setup.sh`** - Install Homebrew packages
- **`apps-install.sh`** - Install applications (Yaak, RustDesk, Docker, Warp)
- **`app-configs-restore.sh`** - Restore application configurations

## Directory Structure

```
laptop/
├── backup.sh                  # Backup current system
├── setup.sh                   # Main setup script
├── README.md                  # This file
│
├── scripts/                   # Individual setup scripts
│   ├── dotfiles-restore.sh
│   ├── brew-setup.sh
│   ├── apps-install.sh
│   └── app-configs-restore.sh
│
├── dotfiles/                  # Backed up dotfiles
│   ├── .zshrc
│   ├── .gitconfig
│   └── ...
│
├── local-bin/                 # Scripts from ~/.local/bin
│   ├── claude-wrapper
│   ├── ecs-ssh
│   └── ...
│
├── config/                    # Application configurations
│   ├── starship/
│   ├── mise/
│   ├── claude/
│   └── warp/
│
├── brew/                      # Homebrew package lists
│   ├── Brewfile
│   ├── formulas.txt
│   └── casks.txt
│
└── docs/                      # Documentation
    └── browser-backup.md      # Browser backup guide
```

## Manual Steps

Some things require manual setup or backup:

### Obsidian Notes
Obsidian vaults are typically stored in:
- `~/Documents/Obsidian/` or custom location
- Recommended: Use Obsidian Sync or Git for version control

### Browser Data
See [docs/browser-backup.md](docs/browser-backup.md) for detailed instructions on:
- Brave browser backup/restore
- Chrome browser backup/restore
- Using browser sync features

### SSH Keys
If you have SSH keys, backup manually:
```bash
cp -r ~/.ssh ~/ssh-backup
```

### GPG Keys
If you use GPG:
```bash
gpg --export-secret-keys > ~/gpg-backup.key
```

## Applications Installed

### Via Homebrew
See `brew/formulas.txt` and `brew/casks.txt` for complete lists.

Currently includes:
- Git, Vim, Wget
- Starship, Mise, ASDF
- Redis, PostgreSQL client
- eza (modern ls)
- htop
- And many more...

### Via Custom Installers
- **Yaak** - API client (from GitHub)
- **RustDesk** - Remote desktop (from GitHub)
- **Docker Desktop** - Container platform
- **Warp** - Modern terminal

## Customization

### Adding More Dotfiles
Edit `backup.sh` and add to the `dotfiles` array:
```bash
dotfiles=(
    .zshrc
    .gitconfig
    .your-new-file
)
```

### Adding More Config Directories
Edit `backup.sh` and add to the `config_dirs` array:
```bash
config_dirs=(
    starship
    mise
    your-app
)
```

### Adding More Applications
Edit `scripts/apps-install.sh` and add a new function following the existing pattern.

## Troubleshooting

### Homebrew Installation Fails
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check internet connection
- Run `brew doctor` to diagnose issues

### Permission Denied Errors
- Make scripts executable: `chmod +x *.sh scripts/*.sh`
- Some operations may require sudo

### Application Won't Install
- Check `scripts/apps-install.sh` for specific error messages
- Many apps can be manually installed if automated install fails
- Check GitHub releases page for manual downloads

### Settings Don't Apply
- Some changes require logging out and back in
- Terminal settings require restarting the terminal
- Run `source ~/.zshrc` to reload shell configuration

## Keeping Backups Updated

Run `backup.sh` periodically to keep your backup current:
```bash
cd ~/code/laptop
./backup.sh
git add .
git commit -m "Update backup $(date +%Y-%m-%d)"
git push
```

Consider setting up a cron job or reminder to run this monthly.

## Security Notes

- The `.netrc` file may contain credentials - ensure your repository is private
- Consider using environment variables or a password manager instead of storing credentials in dotfiles
- SSH keys and GPG keys are NOT backed up by these scripts - handle those separately
- Claude Code API keys are backed up - keep repository private

## Contributing

This is a personal setup repository, but feel free to fork and adapt for your needs.

## License

MIT License - See LICENSE file for details

## Additional Resources

- [Homebrew Documentation](https://docs.brew.sh/)
- [oh-my-zsh Documentation](https://github.com/ohmyzsh/ohmyzsh/wiki)
- [Starship Prompt](https://starship.rs/)
- [Mise Documentation](https://mise.jdx.dev/)
- [Claude Code Documentation](https://docs.claude.com/claude-code)
