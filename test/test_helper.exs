# Configure ExUnit
System.put_env("DISABLE_VAULT_OUTPUT", "1")
ExUnit.start()

# Exclude slow tests by default (run with: mix test --include slow)
ExUnit.configure(exclude: [slow: true])

# Ensure test support directory is compiled
Code.require_file("support/test_helpers.ex", __DIR__)
