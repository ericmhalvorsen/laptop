#!/bin/sh
#
# Installation script for git hooks
# Run this script to install the pre-commit hook

echo "Installing git hooks..."

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Check if we're in a git repository
if [ ! -d "$GIT_HOOKS_DIR" ]; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Install pre-commit hook
if [ -f "$HOOKS_DIR/pre-commit" ]; then
  cp "$HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
  chmod +x "$GIT_HOOKS_DIR/pre-commit"
  echo "✓ Installed pre-commit hook"
else
  echo "Error: pre-commit hook not found in $HOOKS_DIR"
  exit 1
fi

echo ""
echo "✓ Git hooks installed successfully!"
echo ""
echo "The pre-commit hook will now:"
echo "  - Check code formatting with 'mix format'"
echo "  - Run linting with 'mix credo --strict'"
echo ""
echo "Make sure to run 'mix deps.get' to install credo if you haven't already."
