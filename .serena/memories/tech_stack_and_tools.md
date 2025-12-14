# Tech Stack and Tools

## Primary Language

- **Elixir** ~> 1.19
- Compiles to escript for standalone execution

## Dependencies

### Core Libraries
- `yaml_elixir` ~> 2.9 - YAML parsing for config files
- `owl` ~> 0.13 - CLI UI and formatting
- `ucwidth` ~> 0.2 - Unicode width calculations
- `memoize` ~> 1.4 - Function memoization

### Development Tools
- `credo` ~> 1.7 - Linting and code analysis (dev/test only)
- `excoveralls` ~> 0.18 - Test coverage (test only)

## External Tools

- **mise** - Runtime version management (Elixir/Erlang)
- **Homebrew** - macOS package manager
- **git** - Version control
- **rsync** - File synchronization (used by backup/restore)

## Build System

- **Mix** - Elixir build tool
- Creates escript at `bin/.vault-escript`
- Main module: `Vault.CLI`
