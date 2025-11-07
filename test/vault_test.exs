defmodule VaultTest do
  use ExUnit.Case
  doctest Vault

  test "greets the world" do
    assert Vault.hello() == :world
  end
end
