defmodule Vault.Commands.InstallTest do
  use ExUnit.Case
  import Vault.TestHelpers

  setup :tmp_dir

  defp write_test_config(path, opts) do
    home = opts[:home] || "~/"
    git_dest = opts[:git_dest] || "./"

    config = """
    :steps:
      - :name: brew
        :label: "Brewfile"

      - :name: apt
        :label: "APT Packages"

      - :name: snap
        :label: "Snap Packages"

      - :name: scripts
        :contents:
          - .local/bin/*

      - :name: dotfiles
        :contents:
          - .zshrc
          - .gitconfig

    :git:
      :dest: #{git_dest}
      :steps:
        - brew
        - apt
        - snap
        - scripts
        - dotfiles

    :vault:
      :dest: ~/VaultBackup
      :steps: []

    :defaults:
      :relative_root: #{home}
      :exclude_patterns: []
    """

    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, config)
    path
  end

  @tag timeout: 120_000
  test "dry-run shows platform and steps without copying files", %{tmp_dir: tmp} do
    git_dir = Path.join(tmp, "git-repo")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)
    File.mkdir_p!(git_dir)

    # Create git step directories
    create_test_files(Path.join(git_dir, "dotfiles"), %{
      ".zshrc" => "export PATH=$HOME/.local/bin:$PATH",
      ".gitconfig" => "[user]\n  name = Test"
    })

    create_test_files(Path.join(git_dir, "scripts"), %{
      ".local/bin/foo" => "#!/bin/bash\necho foo"
    })

    # Create config in git directory
    config_path = Path.join(git_dir, "config/vault.yaml")
    write_test_config(config_path, home: home, git_dest: git_dir)

    # Change to git directory (install reads from cwd)
    original_dir = File.cwd!()
    File.cd!(git_dir)

    try do
      Vault.Commands.Install.run([], config_path: config_path, dry_run: true)
      output = Vault.TestBuffer.get()

      # Should show header
      assert output =~ "Vault Install (Bootstrap)"
      assert output =~ "Installing from:"

      # Should show platform
      assert output =~ "Platform:"

      # Should show dry-run messages
      assert output =~ "dry-run:"

      # Should show dotfiles and scripts restoration
      assert output =~ "dotfiles"
      assert output =~ "scripts"

      # Should NOT actually copy files
      refute File.exists?(Path.join(home, ".zshrc"))
      refute File.exists?(Path.join(home, ".gitconfig"))
      refute File.exists?(Path.join([home, ".local", "bin", "foo"]))
    after
      File.cd!(original_dir)
    end
  end

  @tag timeout: 120_000
  test "dry-run shows restore steps for dotfiles and scripts", %{tmp_dir: tmp} do
    git_dir = Path.join(tmp, "git-repo")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)
    File.mkdir_p!(git_dir)

    # Create git step directories with test files
    create_test_files(Path.join(git_dir, "dotfiles"), %{
      ".zshrc" => "zsh config",
      ".gitconfig" => "git config"
    })

    create_test_files(Path.join(git_dir, "scripts"), %{
      ".local/bin/test-script" => "#!/bin/bash\necho test"
    })

    config_path = Path.join(git_dir, "config/vault.yaml")
    write_test_config(config_path, home: home, git_dest: git_dir)

    original_dir = File.cwd!()
    File.cd!(git_dir)

    try do
      Vault.Commands.Install.run([], config_path: config_path, dry_run: true)
      output = Vault.TestBuffer.get()

      assert output =~ "Install complete"
      assert output =~ "dry-run:"
      assert output =~ "would restore scripts"
      assert output =~ "would restore dotfiles"
    after
      File.cd!(original_dir)
    end
  end

  @tag timeout: 120_000
  test "skips missing git step directories gracefully", %{tmp_dir: tmp} do
    git_dir = Path.join(tmp, "git-repo")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)
    File.mkdir_p!(git_dir)

    # Only create dotfiles, not scripts
    create_test_files(Path.join(git_dir, "dotfiles"), %{
      ".zshrc" => "zsh config"
    })

    config_path = Path.join(git_dir, "config/vault.yaml")
    write_test_config(config_path, home: home, git_dest: git_dir)

    original_dir = File.cwd!()
    File.cd!(git_dir)

    try do
      Vault.Commands.Install.run([], config_path: config_path, dry_run: true)
      output = Vault.TestBuffer.get()

      assert output =~ "Install complete"
      assert output =~ "Skipping scripts"
      assert output =~ "would restore dotfiles"
    after
      File.cd!(original_dir)
    end
  end

  @tag timeout: 120_000
  test "shows brew restoration message on macOS", %{tmp_dir: tmp} do
    git_dir = Path.join(tmp, "git-repo")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)
    File.mkdir_p!(git_dir)

    # Create Brewfile
    create_test_files(Path.join(git_dir, "brew"), %{
      "Brewfile" => """
      brew "git"
      brew "elixir"
      cask "warp"
      """
    })

    config_path = Path.join(git_dir, "config/vault.yaml")
    write_test_config(config_path, home: home, git_dest: git_dir)

    original_dir = File.cwd!()
    File.cd!(git_dir)

    try do
      Vault.Commands.Install.run([], config_path: config_path, dry_run: true)
      output = Vault.TestBuffer.get()

      # Should mention Homebrew restoration (if on macOS) or skip it
      if :os.type() == {:unix, :darwin} do
        assert output =~ "Restoring Homebrew packages"
      end
    after
      File.cd!(original_dir)
    end
  end

  @tag timeout: 120_000
  test "handles empty git repository gracefully", %{tmp_dir: tmp} do
    git_dir = Path.join(tmp, "git-repo")
    home = Path.join(tmp, "home")
    File.mkdir_p!(home)
    File.mkdir_p!(git_dir)

    config_path = Path.join(git_dir, "config/vault.yaml")
    write_test_config(config_path, home: home, git_dest: git_dir)

    original_dir = File.cwd!()
    File.cd!(git_dir)

    try do
      Vault.Commands.Install.run([], config_path: config_path)
      output = Vault.TestBuffer.get()

      assert output =~ "Install complete"
      # Should skip all steps gracefully
      assert output =~ "Skipping" or output =~ "not found"
    after
      File.cd!(original_dir)
    end
  end
end
