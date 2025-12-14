# Design Patterns and Guidelines

## Project Architecture

### Command Pattern
- CLI commands are isolated in `lib/vault/commands/`
- Each command module handles a specific operation (save, restore, install, status)
- Commands receive options and delegate to core modules

### Separation of Concerns
- `lib/vault/backup.ex` - Core backup logic
- `lib/vault/restore.ex` - Core restore logic
- `lib/vault/sync.ex` - File synchronization
- `lib/vault/config.ex` - Configuration loading and management
- `lib/vault/state.ex` - State management across operations
- `lib/vault/ui/` - UI/display components

### Configuration-Driven Design
- Operations defined in `config/vault.yaml` as steps
- Steps referenced by name and resolved at runtime
- Allows flexible configuration without code changes

## Common Patterns

### Options Handling
- Functions accept keyword lists for options (e.g., `load(opts \\ [])`)
- Use pattern matching to extract specific options
- Provide sensible defaults

### Error Handling
- Use `{:ok, result}` / `{:error, reason}` tuples
- Display errors via `Vault.UI.Progress` for consistent formatting
- Call `System.halt(1)` for fatal errors after displaying message

### State Management
- Use `Vault.State` agent to track backed up paths across steps
- Prevents duplicate backups of the same directories
- Reset state between operations

### UI Feedback
- Use `Vault.UI.Progress` for all user-facing output
- Tag output with status (success/error/info via colors)
- Provide verbose mode for detailed operation logging

## Best Practices

- Keep functions focused and single-purpose
- Leverage pattern matching over conditionals
- Use pipes for data transformations
- Private functions for internal logic
- Avoid side effects in pure functions when possible
