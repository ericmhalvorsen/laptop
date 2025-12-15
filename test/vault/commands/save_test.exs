defmodule Vault.Commands.SaveTest do
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
  test "saves dotfiles to vault using test config", %{tmp_dir: tmp} do
    vault_target = Path.join(tmp, "vault")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)

    create_test_files(home, %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH",
      ".config/starship.toml" => "format = \"$all\""
    })

    config_path = Path.join(tmp, "vault_test.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_target})

    Vault.Commands.Save.run([], config_path: config_path, vault_target: vault_target)
    output = Vault.TestBuffer.get()

    assert output =~ "Vault Save"
    assert File.exists?(Path.join([vault_target, "dotfiles", ".zshrc"]))
    assert File.exists?(Path.join([vault_target, "dotfiles", ".config", "starship.toml"]))
  end

  @tag timeout: 120_000
  test "handles empty home directory using test config", %{tmp_dir: tmp} do
    vault_target = Path.join(tmp, "vault2")
    home = Path.join(tmp, "home2")
    File.mkdir_p!(home)

    config_path = Path.join(tmp, "vault_test_empty.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_target})

    Vault.Commands.Save.run([], config_path: config_path, vault_target: vault_target)
    output = Vault.TestBuffer.get()

    assert output =~ "Vault Save"
    assert File.dir?(vault_target)
  end
end
