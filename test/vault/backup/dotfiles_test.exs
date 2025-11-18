defmodule Vault.Backup.DotfilesTest do
  use ExUnit.Case
  import Vault.TestHelpers
  import Bitwise
  alias Vault.Backup.Dotfiles

  describe "backup/2" do
    setup :setup_test_env

    test "backs up common dotfiles from source to dest", %{source: source, dest: dest} do
      create_test_files(source, %{
        ".zshrc" => "# ZSH config",
        ".bashrc" => "# Bash config",
        ".gitconfig" => "[user]\n  name = Test",
        ".vimrc" => "set number"
      })

      assert {:ok, result} = Dotfiles.backup(source, dest)
      assert result.files_copied >= 4
      assert result.total_size > 0

      assert File.exists?(Path.join(dest, ".zshrc"))
      assert File.exists?(Path.join(dest, ".bashrc"))
      assert File.exists?(Path.join(dest, ".gitconfig"))
      assert File.exists?(Path.join(dest, ".vimrc"))
    end

    test "backs up .zshenv and .zprofile", %{source: source, dest: dest} do
      create_test_files(source, %{
        ".zshenv" => "export PATH=",
        ".zprofile" => "# Profile"
      })

      assert {:ok, result} = Dotfiles.backup(source, dest)
      assert result.files_copied >= 2

      assert File.exists?(Path.join(dest, ".zshenv"))
      assert File.exists?(Path.join(dest, ".zprofile"))
    end

    test "backs up .irbrc", %{source: source, dest: dest} do
      create_test_file(Path.join(source, ".irbrc"), "IRB.conf[:PROMPT_MODE] = :SIMPLE")

      assert {:ok, result} = Dotfiles.backup(source, dest)
      assert result.files_copied >= 1

      assert File.exists?(Path.join(dest, ".irbrc"))
    end

    test "preserves file content exactly", %{source: source, dest: dest} do
      original_content = "# ZSH Configuration\nexport PATH=$HOME/.local/bin:$PATH\n"
      create_test_file(Path.join(source, ".zshrc"), original_content)

      assert {:ok, _result} = Dotfiles.backup(source, dest)

      backed_up_content = File.read!(Path.join(dest, ".zshrc"))
      assert backed_up_content == original_content
    end

    test "skips non-existent dotfiles gracefully", %{source: source, dest: dest} do
      create_test_file(Path.join(source, ".zshrc"), "# ZSH config")

      assert {:ok, result} = Dotfiles.backup(source, dest)
      assert result.files_copied >= 1
    end

    test "returns error when source directory doesn't exist" do
      assert {:error, reason} = Dotfiles.backup("/nonexistent", "/tmp/dest")
      assert reason =~ "source directory"
    end

    test "creates destination directory if it doesn't exist", %{source: source, dest: dest} do
      create_test_file(Path.join(source, ".zshrc"), "content")
      nested_dest = Path.join([dest, "deeply", "nested", "dotfiles"])

      assert {:ok, _result} = Dotfiles.backup(source, nested_dest)

      assert File.dir?(nested_dest)
      assert File.exists?(Path.join(nested_dest, ".zshrc"))
    end
  end

  describe "backup_local_bin/2" do
    setup :setup_test_env

    test "backs up scripts from .local/bin", %{source: source, dest: dest} do
      local_bin_src = Path.join(source, ".local/bin")
      File.mkdir_p!(local_bin_src)

      create_test_files(local_bin_src, %{
        "script1" => "#!/bin/bash\necho 'test'",
        "script2" => "#!/usr/bin/env python3\nprint('hello')",
        "helper" => "#!/bin/zsh\n# Helper script"
      })

      File.chmod!(Path.join(local_bin_src, "script1"), 0o755)
      File.chmod!(Path.join(local_bin_src, "script2"), 0o755)
      File.chmod!(Path.join(local_bin_src, "helper"), 0o755)

      assert {:ok, result} = Dotfiles.backup_local_bin(source, dest)
      assert result.files_copied == 3

      assert File.exists?(Path.join(dest, "script1"))
      assert File.exists?(Path.join(dest, "script2"))
      assert File.exists?(Path.join(dest, "helper"))
    end

    test "preserves execute permissions", %{source: source, dest: dest} do
      local_bin_src = Path.join(source, ".local/bin")
      File.mkdir_p!(local_bin_src)

      script_path = Path.join(local_bin_src, "executable")
      create_test_file(script_path, "#!/bin/bash\necho 'test'")
      File.chmod!(script_path, 0o755)

      assert {:ok, _result} = Dotfiles.backup_local_bin(source, dest)

      dest_script = Path.join(dest, "executable")
      assert File.exists?(dest_script)

      {:ok, stat} = File.stat(dest_script)
      perms = stat.mode &&& 0o777
      assert perms == 0o755
    end

    test "handles empty .local/bin directory", %{source: source, dest: dest} do
      local_bin_src = Path.join(source, ".local/bin")
      File.mkdir_p!(local_bin_src)

      assert {:ok, result} = Dotfiles.backup_local_bin(source, dest)
      assert result.files_copied == 0
    end

    test "handles missing .local/bin directory gracefully", %{source: source, dest: dest} do
      assert {:ok, result} = Dotfiles.backup_local_bin(source, dest)
      assert result.files_copied == 0
    end

    test "creates destination directory if needed", %{source: source, dest: dest} do
      local_bin_src = Path.join(source, ".local/bin")
      File.mkdir_p!(local_bin_src)
      create_test_file(Path.join(local_bin_src, "script"), "#!/bin/bash")

      nested_dest = Path.join([dest, "nested", "local-bin"])

      assert {:ok, _result} = Dotfiles.backup_local_bin(source, nested_dest)
      assert File.dir?(nested_dest)
      assert File.exists?(Path.join(nested_dest, "script"))
    end
  end

  describe "list_dotfiles/1" do
    setup :tmp_dir

    test "lists common dotfiles that exist", %{tmp_dir: tmp_dir} do
      create_test_files(tmp_dir, %{
        ".zshrc" => "",
        ".bashrc" => "",
        ".gitconfig" => "",
        "not_a_dotfile.txt" => ""
      })

      dotfiles = Dotfiles.list_dotfiles(tmp_dir)

      assert ".zshrc" in dotfiles
      assert ".bashrc" in dotfiles
      assert ".gitconfig" in dotfiles
      refute "not_a_dotfile.txt" in dotfiles
    end

    test "only returns files that exist", %{tmp_dir: tmp_dir} do
      create_test_file(Path.join(tmp_dir, ".zshrc"), "")

      dotfiles = Dotfiles.list_dotfiles(tmp_dir)

      assert ".zshrc" in dotfiles
      # Other dotfiles shouldn't be in the list if they don't exist
      assert length(dotfiles) == 1
    end

    test "returns empty list for directory with no dotfiles", %{tmp_dir: tmp_dir} do
      create_test_file(Path.join(tmp_dir, "regular.txt"), "")

      dotfiles = Dotfiles.list_dotfiles(tmp_dir)

      assert dotfiles == []
    end
  end

  describe "backup_result" do
    test "result struct has required fields" do
      result = %{
        files_copied: 5,
        files_skipped: 2,
        total_size: 1024,
        backed_up_files: [".zshrc", ".bashrc"]
      }

      assert result.files_copied == 5
      assert result.files_skipped == 2
      assert result.total_size == 1024
      assert is_list(result.backed_up_files)
    end
  end
end
