#!/bin/sh
#
# Installation script for git hooks
# Configures Git to use the tracked hooks directory

echo "Configuring git hooks..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Configure Git to use the hooks directory
git config core.hooksPath hooks

echo "✓ Git configured to use tracked hooks"
echo ""
echo "The pre-commit hook will now:"
echo "  - Check code formatting with 'mix format'"
echo "  - Run linting with 'mix credo --strict'"
echo ""
echo "Make sure to run 'mix deps.get' to install credo if you haven't already."
