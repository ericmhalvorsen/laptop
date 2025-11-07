#!/bin/bash

#
# Homebrew Setup Script
# Installs all Homebrew formulas and casks from the backup
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${1:-$HOME/brew-backup-$(date +%Y%m%d-%H%M%S)}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

BREW_DIR="$SCRIPT_DIR/brew"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    log_warning "Homebrew is not installed. Please install it first."
    exit 1
fi

log_info "Updating Homebrew..."
brew update

# Install from Brewfile if it exists
if [[ -f "$BREW_DIR/Brewfile" ]]; then
    log_info "Installing packages from Brewfile..."
    brew bundle --file="$BREW_DIR/Brewfile"
    log_success "Packages installed from Brewfile"
else
    log_warning "No Brewfile found at $BREW_DIR/Brewfile"

    # Fall back to individual lists
    if [[ -f "$BREW_DIR/formulas.txt" ]]; then
        log_info "Installing formulas from list..."
        while IFS= read -r formula; do
            if [[ -n "$formula" ]]; then
                brew install "$formula" 2>/dev/null || log_warning "Failed to install $formula"
            fi
        done < "$BREW_DIR/formulas.txt"
    fi

    if [[ -f "$BREW_DIR/casks.txt" ]]; then
        log_info "Installing casks from list..."
        while IFS= read -r cask; do
            if [[ -n "$cask" ]]; then
                brew install --cask "$cask" 2>/dev/null || log_warning "Failed to install $cask"
            fi
        done < "$BREW_DIR/casks.txt"
    fi
fi

log_info "Cleaning up..."
brew cleanup

log_success "Homebrew setup complete"
