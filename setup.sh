#!/bin/bash

#
# macOS Setup Script
# Main entry point for setting up a new Mac with all configurations and applications
#

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Display banner
echo "=================================="
echo "  macOS Setup Script"
echo "=================================="
echo ""

# Confirm before proceeding
read -p "This will configure your Mac with dotfiles, applications, and settings. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Setup cancelled by user"
    exit 0
fi

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is designed for macOS only"
    exit 1
fi

# Create backup directory with timestamp
BACKUP_DIR="$HOME/mac-setup-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
log_info "Backups will be saved to: $BACKUP_DIR"

# Run setup scripts in order
log_info "Starting setup process..."
echo ""

# 1. Install Homebrew (if not installed)
log_info "Step 1: Checking Homebrew installation..."
if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    log_success "Homebrew installed"
else
    log_success "Homebrew already installed"
fi
echo ""

# 2. Install Homebrew packages and casks
if [[ -f "$SCRIPT_DIR/scripts/brew-setup.sh" ]]; then
    log_info "Step 2: Installing Homebrew packages..."
    bash "$SCRIPT_DIR/scripts/brew-setup.sh" "$BACKUP_DIR"
    echo ""
fi

# 3. Restore dotfiles
if [[ -f "$SCRIPT_DIR/scripts/dotfiles-restore.sh" ]]; then
    log_info "Step 3: Restoring dotfiles..."
    bash "$SCRIPT_DIR/scripts/dotfiles-restore.sh" "$BACKUP_DIR"
    echo ""
fi

# 4. Install oh-my-zsh
log_info "Step 4: Setting up oh-my-zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_success "oh-my-zsh installed"
else
    log_success "oh-my-zsh already installed"
fi
echo ""

# 5. Install additional applications
if [[ -f "$SCRIPT_DIR/scripts/apps-install.sh" ]]; then
    log_info "Step 5: Installing additional applications..."
    bash "$SCRIPT_DIR/scripts/apps-install.sh"
    echo ""
fi

# 6. Restore application configurations
if [[ -f "$SCRIPT_DIR/scripts/app-configs-restore.sh" ]]; then
    log_info "Step 6: Restoring application configurations..."
    bash "$SCRIPT_DIR/scripts/app-configs-restore.sh" "$BACKUP_DIR"
    echo ""
fi

# Summary
echo ""
echo "=================================="
log_success "Setup complete!"
echo "=================================="
echo ""
log_info "Backup location: $BACKUP_DIR"
echo ""
log_warning "NOTE: Some changes may require logging out and back in, or restarting your Mac"
log_info "You may want to:"
echo "  - Restart your terminal or run: source ~/.zshrc"
echo "  - Configure any applications that require manual setup"
echo "  - Review browser data backup/restore instructions in docs/browser-backup.md"
echo ""
