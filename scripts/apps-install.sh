#!/bin/bash

#
# Applications Installation Script
# Installs applications that require special handling (not via Homebrew)
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Function to check if app is installed
is_app_installed() {
    [[ -d "/Applications/$1.app" ]]
}

# Install Yaak (API client)
install_yaak() {
    if is_app_installed "Yaak"; then
        log_success "Yaak already installed"
        return
    fi

    log_info "Installing Yaak from GitHub..."

    # Get latest release URL
    YAAK_URL=$(curl -s https://api.github.com/repos/yaakapp/yaak/releases/latest | \
        grep "browser_download_url.*dmg" | \
        grep -i "darwin" | \
        cut -d '"' -f 4 | \
        head -n 1)

    if [[ -z "$YAAK_URL" ]]; then
        log_warning "Could not find Yaak download URL. Please install manually from https://github.com/yaakapp/yaak"
        return
    fi

    cd "$TEMP_DIR"
    curl -L -o yaak.dmg "$YAAK_URL"

    # Mount and copy
    hdiutil attach yaak.dmg -quiet
    cp -R "/Volumes/Yaak/Yaak.app" /Applications/ 2>/dev/null || \
        cp -R /Volumes/Yaak/*.app /Applications/ 2>/dev/null || \
        log_warning "Could not copy Yaak. Please install manually."
    hdiutil detach "/Volumes/Yaak" -quiet 2>/dev/null || true

    log_success "Yaak installed"
}

# Install RustDesk
install_rustdesk() {
    if is_app_installed "RustDesk"; then
        log_success "RustDesk already installed"
        return
    fi

    log_info "Installing RustDesk from GitHub..."

    # Determine architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        ARCH_SUFFIX="aarch64"
    else
        ARCH_SUFFIX="x86_64"
    fi

    RUSTDESK_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest | \
        grep "browser_download_url.*dmg" | \
        grep "$ARCH_SUFFIX" | \
        cut -d '"' -f 4 | \
        head -n 1)

    if [[ -z "$RUSTDESK_URL" ]]; then
        log_warning "Could not find RustDesk download URL. Please install manually from https://github.com/rustdesk/rustdesk"
        return
    fi

    cd "$TEMP_DIR"
    curl -L -o rustdesk.dmg "$RUSTDESK_URL"

    # Mount and copy
    hdiutil attach rustdesk.dmg -quiet
    cp -R /Volumes/RustDesk/*.app /Applications/ 2>/dev/null || \
        log_warning "Could not copy RustDesk. Please install manually."
    hdiutil detach /Volumes/RustDesk -quiet 2>/dev/null || true

    log_success "RustDesk installed"
}

# Install Docker Desktop
install_docker() {
    if is_app_installed "Docker"; then
        log_success "Docker already installed"
        return
    fi

    log_info "Installing Docker Desktop..."

    # Determine architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        DOCKER_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    else
        DOCKER_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi

    cd "$TEMP_DIR"
    curl -L -o Docker.dmg "$DOCKER_URL"

    # Mount and copy
    hdiutil attach Docker.dmg -quiet
    cp -R /Volumes/Docker/Docker.app /Applications/
    hdiutil detach /Volumes/Docker -quiet 2>/dev/null || true

    log_success "Docker Desktop installed"
    log_info "Note: You'll need to open Docker Desktop to complete setup"
}

# Install Warp Terminal
install_warp() {
    if is_app_installed "Warp"; then
        log_success "Warp already installed"
        return
    fi

    log_info "Installing Warp Terminal..."

    cd "$TEMP_DIR"
    curl -L -o Warp.dmg "https://app.warp.dev/download?package=dmg"

    # Mount and copy
    hdiutil attach Warp.dmg -quiet
    cp -R /Volumes/Warp/Warp.app /Applications/ 2>/dev/null || \
        log_warning "Could not copy Warp. Please install manually from https://www.warp.dev/"
    hdiutil detach /Volumes/Warp -quiet 2>/dev/null || true

    log_success "Warp installed"
}

# Main installation
log_info "Starting application installations..."
echo ""

install_yaak
echo ""

install_rustdesk
echo ""

install_docker
echo ""

install_warp
echo ""

log_success "Application installation complete!"
echo ""
log_warning "Note: Some applications may require manual configuration:"
echo "  - Docker Desktop: Open and agree to terms"
echo "  - RustDesk: Configure your connection settings"
echo "  - Warp: Sign in and sync settings"
