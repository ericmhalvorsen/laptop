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
SCRIPTS_LOCAL_DIR="$SCRIPT_DIR/local-bin"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_warning "No dotfiles directory found at $DOTFILES_DIR"
    exit 0
fi

log_info "Restoring dotfiles..."
mkdir -p "$BACKUP_DIR"

for file in "$DOTFILES_DIR"/*; do
    filename=$(basename "$file")

    [[ ! -f "$file" ]] && continue

    if [[ -f "$HOME/$filename" ]]; then
        cp "$HOME/$filename" "$BACKUP_DIR/$filename"
        log_info "Backed up existing $filename"
    fi

    cp "$file" "$HOME/$filename"
    log_success "Restored $filename"
done

if [[ -d "$SCRIPTS_LOCAL_DIR" ]] && [[ -n "$(ls -A "$SCRIPTS_LOCAL_DIR" 2>/dev/null)" ]]; then
    log_info "Restoring .local/bin scripts..."
    mkdir -p "$HOME/.local/bin"

    if [[ -d "$HOME/.local/bin" ]] && [[ -n "$(ls -A "$HOME/.local/bin" 2>/dev/null)" ]]; then
        cp -r "$HOME/.local/bin"/* "$BACKUP_DIR/local-bin/" 2>/dev/null || true
    fi

    cp -r "$SCRIPTS_LOCAL_DIR"/* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin"/*
    log_success "Restored .local/bin scripts"
else
    log_warning "No .local/bin scripts to restore"
fi
echo ""

log_success "Dotfiles restored successfully"
log_info "Original files backed up to: $BACKUP_DIR"
