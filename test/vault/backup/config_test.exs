defmodule Vault.Backup.ConfigTest do
  use ExUnit.Case
  import Vault.TestHelpers
  alias Vault.Backup.Config

  describe "backup/2" do
    setup :setup_test_env

    test "backs up git config from .config/git", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)

      create_test_files(git_src, %{
        "ignore" => "*.swp\n.DS_Store",
        "attributes" => "*.bin binary"
      })

      assert {:ok, result} = Config.backup(source, dest)
      assert result.configs_backed_up >= 1
      assert "git" in result.backed_up_configs

      assert File.exists?(Path.join(dest, "git/ignore"))
      assert File.exists?(Path.join(dest, "git/attributes"))
    end

    test "backs up mise config from .config/mise", %{source: source, dest: dest} do
      mise_src = Path.join([source, ".config", "mise"])
      File.mkdir_p!(mise_src)

      create_test_files(mise_src, %{
        "config.toml" => "[tools]\nnode = \"20.0.0\""
      })

      assert {:ok, result} = Config.backup(source, dest)
      assert result.configs_backed_up >= 1
      assert "mise" in result.backed_up_configs

      assert File.exists?(Path.join(dest, "mise/config.toml"))
    end

    test "backs up multiple configs", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      mise_src = Path.join([source, ".config", "mise"])

      File.mkdir_p!(git_src)
      File.mkdir_p!(mise_src)

      create_test_file(Path.join(git_src, "ignore"), "*.swp")
      create_test_file(Path.join(mise_src, "config.toml"), "[tools]")

      assert {:ok, result} = Config.backup(source, dest)
      assert result.configs_backed_up >= 2
      assert "git" in result.backed_up_configs
      assert "mise" in result.backed_up_configs
    end

    test "skips configs that don't exist in source", %{source: source, dest: dest} do
      # Only create git config, not mise
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)
      create_test_file(Path.join(git_src, "ignore"), "*.swp")

      # Should succeed with only 1 config
      assert {:ok, result} = Config.backup(source, dest)
      assert result.configs_backed_up == 1
      assert "git" in result.backed_up_configs
      refute "mise" in result.backed_up_configs
    end

    test "creates .config directory in destination if needed", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)
      create_test_file(Path.join(git_src, "ignore"), "*.swp")

      nested_dest = Path.join([dest, "nested", "config"])

      assert {:ok, _result} = Config.backup(source, nested_dest)
      assert File.exists?(Path.join(nested_dest, "git/ignore"))
    end

    test "preserves nested directory structure", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)

      create_test_files(git_src, %{
        "config" => "[user]\nname = Test",
        "ignore" => "*.swp",
        "hooks/pre-commit.sh" => "#!/bin/bash\necho test"
      })

      assert {:ok, _result} = Config.backup(source, dest)

      assert File.exists?(Path.join(dest, "git/config"))
      assert File.exists?(Path.join(dest, "git/ignore"))
      assert File.exists?(Path.join(dest, "git/hooks/pre-commit.sh"))
    end

    test "returns error when source directory doesn't exist" do
      assert {:error, reason} = Config.backup("/nonexistent", "/tmp/dest")
      assert reason =~ "source directory"
    end

    test "preserves file content exactly", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)

      original_content = "# Git ignore\n*.swp\n.DS_Store\n"
      create_test_file(Path.join(git_src, "ignore"), original_content)

      assert {:ok, _result} = Config.backup(source, dest)

      backed_up_content = File.read!(Path.join(dest, "git/ignore"))
      assert backed_up_content == original_content
    end
  end

  describe "list_configs/1" do
    setup :tmp_dir

    test "lists configs that exist in source", %{tmp_dir: tmp_dir} do
      git_src = Path.join([tmp_dir, ".config", "git"])
      mise_src = Path.join([tmp_dir, ".config", "mise"])

      File.mkdir_p!(git_src)
      File.mkdir_p!(mise_src)

      create_test_file(Path.join(git_src, "ignore"), "")
      create_test_file(Path.join(mise_src, "config.toml"), "")

      configs = Config.list_configs(tmp_dir)

      assert "git" in configs
      assert "mise" in configs
    end

    test "only returns configs that have files in them", %{tmp_dir: tmp_dir} do
      git_src = Path.join([tmp_dir, ".config", "git"])
      File.mkdir_p!(git_src)
      create_test_file(Path.join(git_src, "ignore"), "")

      configs = Config.list_configs(tmp_dir)

      assert "git" in configs
      refute "mise" in configs
    end

    test "returns empty list when no configs exist", %{tmp_dir: tmp_dir} do
      configs = Config.list_configs(tmp_dir)

      assert configs == []
    end
  end

  describe "default_configs/0" do
    test "returns list of config apps to back up" do
      configs = Config.default_configs()

      assert is_list(configs)
      assert "git" in configs
      assert "mise" in configs
    end
  end

  describe "backup_config/3" do
    setup :setup_test_env

    test "backs up individual config directory", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)

      create_test_files(git_src, %{
        "ignore" => "*.swp",
        "config" => "[user]\nname = Test"
      })

      assert {:ok, result} = Config.backup_config("git", source, dest)
      assert result.files_copied >= 2

      assert File.exists?(Path.join(dest, "git/ignore"))
      assert File.exists?(Path.join(dest, "git/config"))
    end

    test "returns ok with 0 files if config doesn't exist", %{source: source, dest: dest} do
      # Don't create the git config

      assert {:ok, result} = Config.backup_config("git", source, dest)
      assert result.files_copied == 0
    end

    test "preserves directory structure in backup", %{source: source, dest: dest} do
      git_src = Path.join([source, ".config", "git"])
      File.mkdir_p!(git_src)

      create_test_files(git_src, %{
        "hooks/pre-commit" => "#!/bin/bash",
        "templates/hooks/commit-msg" => "#!/bin/bash"
      })

      assert {:ok, _result} = Config.backup_config("git", source, dest)

      assert File.exists?(Path.join(dest, "git/hooks/pre-commit"))
      assert File.exists?(Path.join(dest, "git/templates/hooks/commit-msg"))
    end
  end

  describe "config result" do
    test "result struct has required fields" do
      result = %{
        configs_backed_up: 2,
        total_size: 2048,
        backed_up_configs: ["git", "mise"]
      }

      assert result.configs_backed_up == 2
      assert result.total_size == 2048
      assert is_list(result.backed_up_configs)
    end
  end
end
