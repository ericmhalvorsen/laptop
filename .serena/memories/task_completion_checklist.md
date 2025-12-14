# Task Completion Checklist

When completing a development task, follow this checklist:

## 1. Code Quality

- [ ] Run `mix format` to ensure code is properly formatted
- [ ] Run `mix credo` to check for code quality issues
- [ ] Fix any warnings or issues reported by credo

## 2. Testing

- [ ] Write tests for new functionality
- [ ] Ensure all tests pass with `mix test`
- [ ] Check test coverage if needed with `mix coveralls`
- [ ] Verify no flaky or timing-dependent tests

## 3. Build Verification

- [ ] Run `mix compile` to ensure no compilation errors
- [ ] If CLI changes were made, rebuild escript with `mix escript.build`
- [ ] Test the escript executable if CLI functionality changed

## 4. Documentation

- [ ] Add/update `@moduledoc` for new/modified modules
- [ ] Add/update `@doc` for new/modified public functions
- [ ] Update README.md if user-facing changes were made

## 5. Git

- [ ] Review changes with `git diff`
- [ ] Ensure no unintended files are staged
- [ ] Write clear commit message describing the change
