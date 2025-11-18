# Git Hooks

This directory contains git hooks for the project.

## Installation

To install the git hooks, run:

```bash
./hooks/install.sh
```

## Pre-commit Hook

The pre-commit hook automatically runs before each commit and performs the following checks:

1. **Code Formatting**: Runs `mix format --check-formatted` on all staged `.ex` and `.exs` files
2. **Linting**: Runs `mix credo --strict` to check for code quality issues

If either check fails, the commit will be prevented.

## Setup Requirements

Make sure you have the following dependencies installed:

1. Install Elixir dependencies:
   ```bash
   mix deps.get
   ```

2. The hook requires `credo` which is included in the project dependencies.

## Manual Usage

You can manually run the checks at any time:

```bash
# Format all code
mix format

# Run credo
mix credo --strict
```
