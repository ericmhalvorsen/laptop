# Suggested Commands

## Development Commands

### Setup
```bash
mise install              # Install Elixir/Erlang versions
mix deps.get             # Fetch dependencies
mix escript.build        # Build the vault escript
```

### Testing
```bash
mix test                 # Run all tests
mix test path/to/test    # Run specific test file
mix test --trace         # Run tests with detailed output
mix coveralls            # Run tests with coverage report
mix coveralls.html       # Generate HTML coverage report
```

### Code Quality
```bash
mix format               # Format code
mix format --check-formatted  # Check if code is formatted
mix credo                # Run linter
mix credo --strict       # Run linter with strict rules
```

### Building
```bash
mix compile              # Compile the project
mix escript.build        # Build the escript executable
```

## Vault Commands

```bash
./vault --help           # Show help
./bin/vault save         # Backup configs to repo
./bin/vault restore      # Restore configs from repo
./bin/vault install      # Install apps from config
./bin/vault status       # Check backup status
```

With vault target (local or remote):
```bash
./bin/vault save --vault-target /path/to/backup
./bin/vault save --vault-target user@host:/backups/vault
./bin/vault restore --vault-target /path/to/backup
./bin/vault restore --vault-target user@host:/backups/vault
./bin/vault status --vault-target /path/to/backup

# With SSH key for remote targets
./bin/vault save --vault-target user@host:/backups/vault --ssh-key ~/.ssh/id_rsa
```

## System Commands (macOS/Darwin)

Standard Unix commands work on Darwin:
```bash
ls, cd, grep, find, cat, mkdir, rm, cp, mv, pwd
```

Note: Darwin uses BSD versions of some tools, which may differ slightly from GNU versions.
