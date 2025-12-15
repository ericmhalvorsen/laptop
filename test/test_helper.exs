ExUnit.start()
ExUnit.configure(exclude: [slow: true])

# Start the TestBuffer for capturing Progress output during tests
{:ok, _} = Vault.TestBuffer.start_link()

Code.require_file("support/test_helpers.ex", __DIR__)
