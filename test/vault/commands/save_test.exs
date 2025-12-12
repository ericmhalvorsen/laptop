defmodule Vault.Commands.SaveTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  import Vault.TestHelpers

  setup :tmp_dir

  defp with_env(env, fun) do
    old = Enum.map(env, fn {k, _} -> {k, System.get_env(k)} end)

    Enum.each(env, fn {k, v} ->
      if v == :unset, do: System.delete_env(k), else: System.put_env(k, v)
    end)

    try do
      fun.()
    after
      Enum.each(old, fn {k, v} ->
        if is_nil(v), do: System.delete_env(k), else: System.put_env(k, v)
      end)
    end
  end

  defp write_test_config(path, opts) do
    home = opts.home
    vault_dest = opts.vault_dest

    config = """
:steps:
  - :name: dotfiles
    :label: "Dotfiles"
    :contents:
      - .zshrc
      - .config/starship.toml

:git:
  :dest: #{Path.join(home, "git-backup")}
  :steps: []

:vault:
  :dest: #{vault_dest}
  :steps:
    - dotfiles

:defaults:
  :relative_root: #{home}
  :exclude_patterns: []
"""

    File.write!(path, config)
    path
  end

  @tag timeout: 120_000
  test "saves dotfiles to vault using test config", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)

    create_test_files(home, %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH",
      ".config/starship.toml" => "format = \"$all\""
    })

    config_path = Path.join(tmp, "vault_test.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_path})

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Save.run([], config_path: config_path, vault_path: vault_path)
        end)
      end)

    assert output =~ "Vault Save"
    assert File.exists?(Path.join([vault_path, "dotfiles", ".zshrc"]))
    assert File.exists?(Path.join([vault_path, "dotfiles", ".config", "starship.toml"]))
  end

  @tag timeout: 120_000
  test "handles empty home directory using test config", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault2")
    home = Path.join(tmp, "home2")
    File.mkdir_p!(home)

    config_path = Path.join(tmp, "vault_test_empty.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_path})

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Save.run([], config_path: config_path, vault_path: vault_path)
        end)
      end)

    assert output =~ "Vault Save"
    assert File.dir?(vault_path)
  end
end
