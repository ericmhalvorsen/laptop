defmodule Vault.Backup.AppSupportTest do
  use ExUnit.Case
  alias Vault.Backup.AppSupport

  setup do
    home_dir = Path.join(System.tmp_dir!(), "vault_app_test_home_#{:rand.uniform(10000)}")
    vault_dir = Path.join(System.tmp_dir!(), "vault_app_test_vault_#{:rand.uniform(10000)}")

    File.mkdir_p!(home_dir)
    File.mkdir_p!(vault_dir)

    on_exit(fn ->
      File.rm_rf!(home_dir)
      File.rm_rf!(vault_dir)
    end)

    %{home_dir: home_dir, vault_dir: vault_dir}
  end

  describe "backup/3" do
    test "backs up Application Support directories", %{home_dir: home_dir, vault_dir: vault_dir} do
      # Create Application Support with app directories
      app_support = Path.join([home_dir, "Library", "Application Support"])
      File.mkdir_p!(Path.join([app_support, "Claude"]))
      File.mkdir_p!(Path.join([app_support, "Obsidian"]))

      File.write!(Path.join([app_support, "Claude", "config.json"]), "claude config")
      File.write!(Path.join([app_support, "Obsidian", "data.json"]), "obsidian data")

      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir)

      # Verify directories were backed up
      assert "Claude" in result.backed_up
      assert "Obsidian" in result.backed_up
      assert result.total_size > 0

      # Verify files exist in vault
      assert File.exists?(Path.join([vault_dir, "app-support", "Claude", "config.json"]))
      assert File.exists?(Path.join([vault_dir, "app-support", "Obsidian", "data.json"]))
    end

    test "excludes system directories", %{home_dir: home_dir, vault_dir: vault_dir} do
      app_support = Path.join([home_dir, "Library", "Application Support"])
      File.mkdir_p!(Path.join([app_support, "Claude"]))
      File.mkdir_p!(Path.join([app_support, "com.apple.Safari"]))
      File.mkdir_p!(Path.join([app_support, "CrashReporter"]))

      File.write!(Path.join([app_support, "Claude", "file.txt"]), "data")

      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir)

      # Should only backup Claude, not system directories
      assert result.backed_up == ["Claude"]

      # System directories should not exist in vault
      refute File.exists?(Path.join([vault_dir, "app-support", "com.apple.Safari"]))
      refute File.exists?(Path.join([vault_dir, "app-support", "CrashReporter"]))
    end

    test "handles nested directory structures", %{home_dir: home_dir, vault_dir: vault_dir} do
      app_support = Path.join([home_dir, "Library", "Application Support"])
      nested = Path.join([app_support, "MyApp", "data", "backups"])
      File.mkdir_p!(nested)
      File.write!(Path.join(nested, "file.db"), "database")

      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir)

      assert "MyApp" in result.backed_up

      # Verify nested structure preserved
      assert File.exists?(
               Path.join([vault_dir, "app-support", "MyApp", "data", "backups", "file.db"])
             )
    end

    test "returns empty result when Application Support doesn't exist", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir)

      assert result.backed_up == []
      assert result.total_size == 0
    end

    test "returns empty result when Application Support is empty", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      app_support = Path.join([home_dir, "Library", "Application Support"])
      File.mkdir_p!(app_support)

      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir)

      assert result.backed_up == []
      assert result.total_size == 0
    end

    test "creates vault/app-support directory if it doesn't exist", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      app_support = Path.join([home_dir, "Library", "Application Support"])
      File.mkdir_p!(Path.join([app_support, "TestApp"]))
      File.write!(Path.join([app_support, "TestApp", "file.txt"]), "data")

      app_support_dest = Path.join(vault_dir, "app-support")
      refute File.dir?(app_support_dest)

      assert {:ok, _result} = AppSupport.backup(home_dir, vault_dir)

      assert File.dir?(app_support_dest)
    end

    test "allows custom exclude patterns", %{home_dir: home_dir, vault_dir: vault_dir} do
      app_support = Path.join([home_dir, "Library", "Application Support"])
      File.mkdir_p!(Path.join([app_support, "Claude"]))
      File.mkdir_p!(Path.join([app_support, "TestApp"]))
      File.write!(Path.join([app_support, "Claude", "file.txt"]), "data")
      File.write!(Path.join([app_support, "TestApp", "file.txt"]), "data")

      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir, exclude: ["TestApp"])

      assert result.backed_up == ["Claude"]
      refute File.exists?(Path.join([vault_dir, "app-support", "TestApp"]))
    end
  end

  describe "backup/3 with dry_run option" do
    test "doesn't copy files in dry run mode", %{home_dir: home_dir, vault_dir: vault_dir} do
      app_support = Path.join([home_dir, "Library", "Application Support"])
      File.mkdir_p!(Path.join([app_support, "Claude"]))
      File.write!(Path.join([app_support, "Claude", "file.txt"]), "data")

      assert {:ok, result} = AppSupport.backup(home_dir, vault_dir, dry_run: true)

      assert result.backed_up == []
      assert result.total_size == 0

      # Files should NOT exist
      refute File.exists?(Path.join([vault_dir, "app-support", "Claude"]))
    end
  end
end
