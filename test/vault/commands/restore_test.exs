defmodule Vault.Commands.RestoreTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  import Vault.TestHelpers

  setup :tmp_dir

  defp with_env(env, fun) do
    old = Enum.map(env, fn {k, _} -> {k, System.get_env(k)} end)
    Enum.each(env, fn {k, v} -> if v == :unset, do: System.delete_env(k), else: System.put_env(k, v) end)
    try do
      fun.()
    after
      Enum.each(old, fn {k, v} -> if is_nil(v), do: System.delete_env(k), else: System.put_env(k, v) end)
    end
  end

  test "dry-run restores full flow when vault has data", %{tmp_dir: tmp_dir} do
    vault_path = Path.join(tmp_dir, "vault")
    home_dir = Path.join(tmp_dir, "home")
    File.mkdir_p!(vault_path)
    File.mkdir_p!(home_dir)

    # Prepare vault structure
    # home/
    File.mkdir_p!(Path.join([vault_path, "home", "Documents"]))
    create_test_file(Path.join([vault_path, "home", "Documents", "file.txt"]), "docs")

    # fonts/
    fonts_dir = Path.join([vault_path, "fonts"])
    File.mkdir_p!(fonts_dir)
    create_test_file(Path.join(fonts_dir, "MyFont.ttf"), "fontdata")

    # dotfiles/
    ddir = Path.join([vault_path, "dotfiles"])
    File.mkdir_p!(ddir)
    create_test_file(Path.join(ddir, ".zshrc"), "export PATH")

    # local-bin/
    lbin = Path.join([vault_path, "local-bin"])
    File.mkdir_p!(lbin)
    create_test_file(Path.join(lbin, "myscript"), "#!/bin/sh\necho hi")

    # app-support/
    asrc = Path.join([vault_path, "app-support", "SomeApp"])
    File.mkdir_p!(asrc)
    create_test_file(Path.join(asrc, "config.json"), "{}")

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Restore.run([], vault_path: vault_path, dry_run: true)
        end)
      end)

    # Headings
    assert output =~ "Vault Restore"
    assert output =~ "Restoring home directories"
    assert output =~ "Restoring fonts"
    assert output =~ "Restoring dotfiles and ~/.local/bin"
    assert output =~ "Restoring Application Support"

    # Dry-run lines
    assert output =~ "dry-run:"
    assert output =~ "would copy"

    # Key paths referenced
    assert output =~ Path.join(vault_path, "home")
    assert output =~ Path.join(vault_path, "fonts")
    assert output =~ Path.join(vault_path, "dotfiles")
    assert output =~ Path.join(vault_path, "local-bin")
    assert output =~ Path.join(vault_path, "app-support")
  end

  test "dry-run prints helpful messages when vault is empty", %{tmp_dir: tmp_dir} do
    vault_path = Path.join(tmp_dir, "vault_empty")
    File.mkdir_p!(vault_path)

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Restore.run([], vault_path: vault_path, dry_run: true)
        end)
      end)

    assert output =~ "No home data found in vault/home/"
    assert output =~ "No fonts found in vault/fonts/"
    assert output =~ "No dotfiles found in vault/dotfiles/"
    assert output =~ "No Application Support data found in vault/app-support/"
  end
end
