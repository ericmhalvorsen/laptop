# Code Style and Conventions

## Naming Conventions

- **Modules**: PascalCase (e.g., `Vault.Config`, `Vault.Commands.Save`)
- **Functions**: snake_case (e.g., `load/1`, `resolve_steps/2`)
- **Variables**: snake_case
- **Atoms**: snake_case

## Code Structure

- Use `@moduledoc` for module documentation
- Use `@doc` for public function documentation
- Private functions use `defp`
- Leverage pattern matching extensively
- Use pipeline operator `|>` for data transformations

## Documentation

- Moduledocs describe the module's purpose
- Function docs include:
  - Brief description
  - `## Options` section for keyword list parameters when applicable
  - Examples when helpful
- Keep docs concise and focused

## Testing

- Tests use ExUnit framework
- Test files mirror source structure: `lib/vault/config.ex` → `test/vault/config_test.exs`
- Use `async: true` when possible for parallel test execution
- Use `describe` blocks to group related tests
- Use module tags like `@moduletag :tmp_dir` for test setup
- Setup blocks for common test initialization

## Formatting

- Automated via `mix format`
- Configuration in `.formatter.exs`
- Formats: `mix.exs`, `.formatter.exs`, and all `.ex`/`.exs` files in `config/`, `lib/`, `test/`
