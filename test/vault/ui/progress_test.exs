defmodule Vault.UI.ProgressTest do
  use ExUnit.Case, async: true

  alias Vault.UI.Progress

  setup do
    prev = System.get_env("DISABLE_VAULT_OUTPUT")
    System.put_env("DISABLE_VAULT_OUTPUT", "1")

    on_exit(fn ->
      case prev do
        nil -> System.delete_env("DISABLE_VAULT_OUTPUT")
        _ -> System.put_env("DISABLE_VAULT_OUTPUT", prev)
      end
    end)

    :ok
  end

  test "tag returns plain text when disabled" do
    assert Progress.enabled?() == false
    assert Progress.tag("hello", :green) == "hello"
  end

  test "puts/start/inc/await do not crash when disabled" do
    assert :ok == Progress.puts(["hello", " world"])
    assert :ok == Progress.start_progress(:t1, "Test", 0)
    assert :ok == Progress.start_progress(:t2, "Test", 10)
    assert :ok == Progress.increment(:t2)
  end
end
