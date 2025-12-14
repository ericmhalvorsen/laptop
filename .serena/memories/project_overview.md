# Project Overview

This is a macOS dotfiles and configuration backup/restore system called **Vault**.

## Purpose

Vault is an Elixir-based CLI tool that:
- Backs up macOS system configurations and dotfiles
- Restores configurations on fresh systems  
- Installs applications from configuration files
- Manages dotfiles synchronization between the repository and home directory

## Key Features

- Single entry point (`./vault`) that auto-installs dependencies (Homebrew, git, mise)
- Backs up to both git repo and external vault storage
- Restores configs from repo or full restore from vault backup
- Installs applications defined in config/apps.yaml
- Compiles to self-contained escript for easy distribution

## Architecture

The project consists of:
- **Vault Tool**: Elixir escript that performs backup/restore operations
- **Dotfiles**: Configuration files stored in `dotfiles/` directory
- **Config Files**: YAML configuration in `config/` defining backup steps and apps
- **Wrapper Script**: `./vault` bash script handling bootstrap and execution
