#!/bin/bash

#
# Dotfiles Restore Script
# Restores dotfiles from the backup to the home directory
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${1:-$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

DOTFILES_DIR="$SCRIPT_DIR/dotfiles"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_warning "No dotfiles directory found at $DOTFILES_DIR"
    exit 0
fi

log_info "Restoring dotfiles..."
mkdir -p "$BACKUP_DIR"

# Backup existing dotfiles before overwriting
for file in "$DOTFILES_DIR"/*; do
    filename=$(basename "$file")

    # Skip if it's not a file
    [[ ! -f "$file" ]] && continue

    # Backup existing file
    if [[ -f "$HOME/$filename" ]]; then
        cp "$HOME/$filename" "$BACKUP_DIR/$filename"
        log_info "Backed up existing $filename"
    fi

    # Copy new dotfile
    cp "$file" "$HOME/$filename"
    log_success "Restored $filename"
done

log_success "Dotfiles restored successfully"
log_info "Original files backed up to: $BACKUP_DIR"
