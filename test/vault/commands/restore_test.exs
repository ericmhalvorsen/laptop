defmodule Vault.Commands.RestoreTest do
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
  test "restores dotfiles from vault using test config", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)

    # Create vault structure
    create_test_files(Path.join(vault_path, "dotfiles"), %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH",
      ".config/starship.toml" => "format = \"$all\""
    })

    config_path = Path.join(tmp, "vault_test.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_path})

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Restore.run([], config_path: config_path, vault_path: vault_path)
        end)
      end)

    assert output =~ "Vault Restore"
    assert File.exists?(Path.join(home, ".zshrc"))
    assert File.exists?(Path.join([home, ".config", "starship.toml"]))

    # Verify content
    assert File.read!(Path.join(home, ".zshrc")) == "export PATH=$HOME/.local/bin:$PATH"
    assert File.read!(Path.join([home, ".config", "starship.toml"])) == "format = \"$all\""
  end

  @tag timeout: 120_000
  test "handles empty vault directory using test config", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault2")
    home = Path.join(tmp, "home2")
    File.mkdir_p!(home)
    File.mkdir_p!(vault_path)

    config_path = Path.join(tmp, "vault_test_empty.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_path})

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Restore.run([], config_path: config_path, vault_path: vault_path)
        end)
      end)

    assert output =~ "Vault Restore"
    assert output =~ "Skipping"
  end

  @tag timeout: 120_000
  test "dry-run shows what would be restored", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault3")
    home = Path.join(tmp, "home3")
    File.mkdir_p!(home)

    # Create vault structure
    create_test_files(Path.join(vault_path, "dotfiles"), %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH"
    })

    config_path = Path.join(tmp, "vault_test_dry.yaml")
    write_test_config(config_path, %{home: home, vault_dest: vault_path})

    output =
      with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
        capture_io(fn ->
          Vault.Commands.Restore.run([],
            config_path: config_path,
            vault_path: vault_path,
            dry_run: true
          )
        end)
      end)

    assert output =~ "Vault Restore"
    assert output =~ "dry-run:"

    # Files should NOT be created in dry-run mode
    refute File.exists?(Path.join(home, ".zshrc"))
  end

  @tag timeout: 120_000
  test "round-trip: save then restore preserves files", %{tmp_dir: tmp} do
    vault_path = Path.join(tmp, "vault_rt")
    home1 = Path.join(tmp, "home_src")
    home2 = Path.join(tmp, "home_dest")
    File.mkdir_p!(home1)
    File.mkdir_p!(home2)

    # Create original files
    create_test_files(home1, %{
      ".zshrc" => "original content",
      ".config/starship.toml" => "original toml"
    })

    config_path = Path.join(tmp, "vault_test_rt.yaml")
    write_test_config(config_path, %{home: home1, vault_dest: vault_path})

    # Save
    with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
      capture_io(fn ->
        Vault.Commands.Save.run([], config_path: config_path, vault_path: vault_path)
      end)
    end)

    # Restore to different home
    config_path2 = Path.join(tmp, "vault_test_rt2.yaml")
    write_test_config(config_path2, %{home: home2, vault_dest: vault_path})

    with_env(%{"DISABLE_VAULT_OUTPUT" => :unset}, fn ->
      capture_io(fn ->
        Vault.Commands.Restore.run([], config_path: config_path2, vault_path: vault_path)
      end)
    end)

    # Verify files were restored with correct content
    assert File.exists?(Path.join(home2, ".zshrc"))
    assert File.exists?(Path.join([home2, ".config", "starship.toml"]))
    assert File.read!(Path.join(home2, ".zshrc")) == "original content"
    assert File.read!(Path.join([home2, ".config", "starship.toml"])) == "original toml"
  end
end
