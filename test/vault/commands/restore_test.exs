defmodule Vault.Commands.RestoreTest do
  use ExUnit.Case
  import Vault.TestHelpers

  setup :tmp_dir

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
  test "restores dotfiles from vault using test config", %{tmp_dir: tmp} do
    vault_target = Path.join(tmp, "vault")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)

    create_test_files(Path.join(vault_target, "dotfiles"), %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH",
      ".config/starship.toml" => "format = \"$all\""
    })

    config_path = Path.join(tmp, "vault_test.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_target})

    Vault.Commands.Restore.run([], config_path: config_path, vault_target: vault_target)
    output = Vault.TestBuffer.get()

    assert output =~ "Vault Restore"
    assert File.exists?(Path.join(home, ".zshrc"))
    assert File.exists?(Path.join([home, ".config", "starship.toml"]))

    assert File.read!(Path.join(home, ".zshrc")) == "export PATH=$HOME/.local/bin:$PATH"
    assert File.read!(Path.join([home, ".config", "starship.toml"])) == "format = \"$all\""
  end

  @tag timeout: 120_000
  test "handles empty vault directory using test config", %{tmp_dir: tmp} do
    vault_target = Path.join(tmp, "vault2")
    home = Path.join(tmp, "home2")
    File.mkdir_p!(home)
    File.mkdir_p!(vault_target)

    config_path = Path.join(tmp, "vault_test_empty.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_target})

    Vault.Commands.Restore.run([], config_path: config_path, vault_target: vault_target)
    output = Vault.TestBuffer.get()

    assert output =~ "Vault Restore"
    assert output =~ "Skipping"
  end

  @tag timeout: 120_000
  test "dry-run shows what would be restored", %{tmp_dir: tmp} do
    vault_target = Path.join(tmp, "vault3")
    home = Path.join(tmp, "home3")
    File.mkdir_p!(home)

    create_test_files(Path.join(vault_target, "dotfiles"), %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH"
    })

    config_path = Path.join(tmp, "vault_test_dry.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_target})

    Vault.Commands.Restore.run([],
      config_path: config_path,
      vault_target: vault_target,
      dry_run: true
    )

    output = Vault.TestBuffer.get()

    assert output =~ "Vault Restore"
    assert output =~ "dry-run:"

    refute File.exists?(Path.join(home, ".zshrc"))
  end

  @tag timeout: 120_000
  test "round-trip: save then restore preserves files", %{tmp_dir: tmp} do
    vault_target = Path.join(tmp, "vault_rt")
    home1 = Path.join(tmp, "home_src")
    home2 = Path.join(tmp, "home_dest")
    File.mkdir_p!(home1)
    File.mkdir_p!(home2)

    create_test_files(home1, %{
      ".zshrc" => "original content",
      ".config/starship.toml" => "original toml"
    })

    config_path = Path.join(tmp, "vault_test_rt.yaml")
    write_test_config(config_path, %{home: home1, vault_dest: vault_target})

    Vault.Commands.Save.run([], config_path: config_path, vault_target: vault_target)

    config_path2 = Path.join(tmp, "vault_test_rt2.yaml")
    write_test_config(config_path2, %{home: home2, vault_dest: vault_target})

    Vault.Commands.Restore.run([], config_path: config_path2, vault_target: vault_target)

    assert File.exists?(Path.join(home2, ".zshrc"))
    assert File.exists?(Path.join([home2, ".config", "starship.toml"]))
    assert File.read!(Path.join(home2, ".zshrc")) == "original content"
    assert File.read!(Path.join([home2, ".config", "starship.toml"])) == "original toml"
  end
end
