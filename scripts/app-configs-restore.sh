#!/bin/bash

#
# Application Configurations Restore Script
# Restores application configurations from backup
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${1:-$HOME/app-config-backup-$(date +%Y%m%d-%H%M%S)}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

CONFIG_DIR="$SCRIPT_DIR/config"
SCRIPTS_LOCAL_DIR="$SCRIPT_DIR/local-bin"

mkdir -p "$BACKUP_DIR"

# Restore .local/bin scripts
if [[ -d "$SCRIPTS_LOCAL_DIR" ]] && [[ -n "$(ls -A "$SCRIPTS_LOCAL_DIR" 2>/dev/null)" ]]; then
    log_info "Restoring .local/bin scripts..."
    mkdir -p "$HOME/.local/bin"

    # Backup existing scripts
    if [[ -d "$HOME/.local/bin" ]] && [[ -n "$(ls -A "$HOME/.local/bin" 2>/dev/null)" ]]; then
        cp -r "$HOME/.local/bin"/* "$BACKUP_DIR/local-bin/" 2>/dev/null || true
    fi

    # Copy scripts
    cp -r "$SCRIPTS_LOCAL_DIR"/* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin"/*
    log_success "Restored .local/bin scripts"
else
    log_warning "No .local/bin scripts to restore"
fi
echo ""

# Restore .config directories
log_info "Restoring .config directories..."
if [[ -d "$CONFIG_DIR" ]]; then
    for dir in "$CONFIG_DIR"/*; do
        if [[ -d "$dir" ]]; then
            dirname=$(basename "$dir")

            # Skip claude and warp, handle them separately
            if [[ "$dirname" == "claude" ]] || [[ "$dirname" == "warp" ]]; then
                continue
            fi

            # Backup existing config
            if [[ -d "$HOME/.config/$dirname" ]]; then
                mkdir -p "$BACKUP_DIR/.config"
                cp -r "$HOME/.config/$dirname" "$BACKUP_DIR/.config/" 2>/dev/null || true
            fi

            # Copy new config
            mkdir -p "$HOME/.config/$dirname"
            cp -r "$dir"/* "$HOME/.config/$dirname/" 2>/dev/null || true
            log_success "Restored .config/$dirname"
        fi
    done
else
    log_warning "No .config directory to restore"
fi
echo ""

# Restore Claude Code configuration
if [[ -d "$CONFIG_DIR/claude" ]]; then
    log_info "Restoring Claude Code configuration..."

    # Backup existing config
    if [[ -d "$HOME/.claude" ]]; then
        mkdir -p "$BACKUP_DIR/.claude"
        cp -r "$HOME/.claude"/* "$BACKUP_DIR/.claude/" 2>/dev/null || true
    fi

    # Restore settings
    mkdir -p "$HOME/.claude"
    cp -r "$CONFIG_DIR/claude"/* "$HOME/.claude/" 2>/dev/null || true

    # Make scripts executable
    [[ -f "$HOME/.claude/anthropic_key.sh" ]] && chmod +x "$HOME/.claude/anthropic_key.sh"

    log_success "Restored Claude Code configuration"
fi

# Restore claude.json if it exists
if [[ -f "$CONFIG_DIR/claude.json" ]]; then
    [[ -f "$HOME/.claude.json" ]] && cp "$HOME/.claude.json" "$BACKUP_DIR/claude.json"
    cp "$CONFIG_DIR/claude.json" "$HOME/.claude.json"
    log_success "Restored .claude.json"
fi
echo ""

# Restore Warp configuration
if [[ -d "$CONFIG_DIR/warp" ]]; then
    log_info "Restoring Warp configuration..."

    # Backup existing config
    if [[ -d "$HOME/.warp" ]]; then
        mkdir -p "$BACKUP_DIR/.warp"
        cp -r "$HOME/.warp"/* "$BACKUP_DIR/.warp/" 2>/dev/null || true
    fi

    # Restore config
    mkdir -p "$HOME/.warp"
    cp -r "$CONFIG_DIR/warp"/* "$HOME/.warp/" 2>/dev/null || true
    log_success "Restored Warp configuration"
else
    log_warning "No Warp configuration to restore"
fi
echo ""

# Install NVM if needed
if ! command -v nvm &> /dev/null && grep -q "NVM_DIR" "$HOME/.zshrc" 2>/dev/null; then
    log_info "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    log_success "NVM installed"
fi
echo ""

# Install asdf if needed
if ! command -v asdf &> /dev/null && [[ -f "$HOME/.zshrc" ]] && grep -q "asdf" "$HOME/.zshrc"; then
    log_info "Installing asdf..."
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    log_success "asdf installed"
fi
echo ""

log_success "Application configurations restored successfully"
log_info "Original files backed up to: $BACKUP_DIR"
