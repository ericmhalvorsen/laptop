defmodule Vault.UI.ProgressTest do
  use ExUnit.Case, async: true

  alias Vault.UI.Progress

  test "tag returns plain text when disabled" do
    assert Progress.enabled?() == false
    assert Progress.tag("hello", :green) == "hello"
  end

  test "puts/start/inc/await do not crash when disabled" do
    assert ["hello", " world"] == Progress.puts(["hello", " world"])
    assert :ok == Progress.start_progress(:t1, "Test", 0)
    assert :ok == Progress.start_progress(:t2, "Test", 10)
    assert :ok == Progress.increment(:t2)
  end
end
