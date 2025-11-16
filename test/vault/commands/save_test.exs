defmodule Vault.Commands.SaveTest do
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

  @tag timeout: 120_000
  test "saves to vault using temp HOME, creating expected folders", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)

    # Create sample dotfiles and .local/bin
    create_test_files(home, %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH",
      ".config/starship.toml" => "format = \"$all\"",
      ".local/bin/myscript" => "#!/bin/sh\necho hi"
    })

    # Create Fonts
    create_test_files(Path.join([home, "Library", "Fonts"]), %{
      "MyFont.ttf" => "fontdata"
    })

    # Create Application Support
    create_test_files(Path.join([home, "Library", "Application Support", "SomeApp"]), %{
      "config.json" => "{}"
    })

    # Create Home public dir
    create_test_files(Path.join(home, "Documents"), %{"doc.txt" => "hello"})

    # Ensure brew/rsync do not run from host by emptying PATH
    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Save.run([], vault_path: vault_path, home_dir: home, skip_homebrew: true)
        end)
      end)

    # Headings
    assert output =~ "Vault Save"
    assert output =~ "Backing up dotfiles"
    # no homebrew
    assert output =~ "Backing up fonts"
    assert output =~ "Backing up Application Support"
    assert output =~ "Backing up home directories"

    # Verify files landed in vault
    assert File.exists?(Path.join([vault_path, "dotfiles", ".zshrc"]))
    assert File.exists?(Path.join([vault_path, "dotfiles", ".config", "starship.toml"]))
    assert File.exists?(Path.join([vault_path, "local-bin", "myscript"]))
    assert File.exists?(Path.join([vault_path, "fonts", "MyFont.ttf"]))
    assert File.exists?(Path.join([vault_path, "app-support", "SomeApp", "config.json"]))
    assert File.exists?(Path.join([vault_path, "home", "Documents", "doc.txt"]))
  end

  @tag timeout: 120_000
  test "handles empty HOME without crashing and prints summary", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault2")
    home = Path.join(tmp, "home2")
    File.mkdir_p!(home)

    output =
      with_env(%{"HOME" => home, "PATH" => "", "DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Save.run([], vault_path: vault_path, home_dir: home, skip_homebrew: true)
        end)
      end)

    assert output =~ "Vault Save"
    assert File.dir?(vault_path)
  end
end
