#!/bin/bash

#
# Backup Script - Save current Mac configuration
# Run this script to backup your current setup before reinstalling macOS
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "=================================="
echo "  macOS Backup Script"
echo "=================================="
echo ""

# Backup directory structure
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
CONFIG_DIR="$SCRIPT_DIR/config"
SCRIPTS_LOCAL_DIR="$SCRIPT_DIR/local-bin"
BREW_DIR="$SCRIPT_DIR/brew"

# Create directories
mkdir -p "$DOTFILES_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$SCRIPTS_LOCAL_DIR"
mkdir -p "$BREW_DIR"

log_info "Starting backup process..."
echo ""

# Backup dotfiles
log_info "Backing up dotfiles..."
dotfiles=(
    .zshrc
    .zshenv
    .zprofile
    .bashrc
    .bash_profile
    .gitconfig
    .vimrc
    .irbrc
    .netrc
)

for file in "${dotfiles[@]}"; do
    if [[ -f "$HOME/$file" ]]; then
        cp "$HOME/$file" "$DOTFILES_DIR/"
        log_success "Backed up $file"
    fi
done
echo ""

# Backup .local/bin scripts
log_info "Backing up .local/bin scripts..."
if [[ -d "$HOME/.local/bin" ]]; then
    cp -r "$HOME/.local/bin"/* "$SCRIPTS_LOCAL_DIR/" 2>/dev/null || true
    log_success "Backed up .local/bin scripts"
else
    log_warning ".local/bin directory not found"
fi
echo ""

# Backup .config directories
log_info "Backing up .config directories..."
config_dirs=(
    starship
    mise
    git
)

for dir in "${config_dirs[@]}"; do
    if [[ -d "$HOME/.config/$dir" ]]; then
        mkdir -p "$CONFIG_DIR/$dir"
        cp -r "$HOME/.config/$dir"/* "$CONFIG_DIR/$dir/" 2>/dev/null || true
        log_success "Backed up .config/$dir"
    fi
done
echo ""

# Backup Claude Code configuration
log_info "Backing up Claude Code configuration..."
if [[ -d "$HOME/.claude" ]]; then
    mkdir -p "$CONFIG_DIR/claude"
    # Backup settings and key files, but not logs/history
    [[ -f "$HOME/.claude/settings.json" ]] && cp "$HOME/.claude/settings.json" "$CONFIG_DIR/claude/"
    [[ -f "$HOME/.claude/anthropic_key.sh" ]] && cp "$HOME/.claude/anthropic_key.sh" "$CONFIG_DIR/claude/"
    [[ -f "$HOME/.claude/CLAUDE.md" ]] && cp "$HOME/.claude/CLAUDE.md" "$CONFIG_DIR/claude/"
    log_success "Backed up Claude Code configuration"
fi

if [[ -f "$HOME/.claude.json" ]]; then
    cp "$HOME/.claude.json" "$CONFIG_DIR/claude.json"
fi
echo ""

# Export Homebrew packages
log_info "Exporting Homebrew packages..."
if command -v brew &> /dev/null; then
    brew list --formula > "$BREW_DIR/formulas.txt"
    brew list --cask > "$BREW_DIR/casks.txt" 2>/dev/null || touch "$BREW_DIR/casks.txt"
    brew bundle dump --file="$BREW_DIR/Brewfile" --force
    log_success "Exported Homebrew packages"
else
    log_warning "Homebrew not found"
fi
echo ""

# Backup Warp configuration (if exists)
log_info "Backing up Warp configuration..."
if [[ -d "$HOME/.warp" ]]; then
    mkdir -p "$CONFIG_DIR/warp"
    cp -r "$HOME/.warp"/* "$CONFIG_DIR/warp/" 2>/dev/null || true
    log_success "Backed up Warp configuration"
fi
echo ""

# Create backup info file
log_info "Creating backup info..."
cat > "$SCRIPT_DIR/backup-info.txt" << EOF
Backup created: $(date)
macOS version: $(sw_vers -productVersion)
Hostname: $(hostname)
User: $(whoami)

Backed up:
- Dotfiles
- .local/bin scripts
- .config directories
- Claude Code configuration
- Homebrew packages list
- Warp configuration

Manual backup required for:
- Browser data (see docs/browser-backup.md)
- Obsidian notes
- Application data not in .config
EOF

echo ""
echo "=================================="
log_success "Backup complete!"
echo "=================================="
echo ""
log_info "All configurations have been backed up to:"
echo "  $SCRIPT_DIR"
echo ""
log_warning "Don't forget to:"
echo "  - Commit and push this repository to GitHub"
echo "  - Backup browser data manually (see docs/browser-backup.md)"
echo "  - Backup Obsidian vault separately"
echo ""
