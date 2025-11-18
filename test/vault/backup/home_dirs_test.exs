defmodule Vault.Backup.HomeDirsTest do
  use ExUnit.Case
  alias Vault.Backup.HomeDirs

  setup do
    # Create temp source and destination directories
    source_dir = Path.join(System.tmp_dir!(), "vault_home_test_#{:rand.uniform(10000)}")
    dest_dir = Path.join(System.tmp_dir!(), "vault_dest_test_#{:rand.uniform(10000)}")

    File.mkdir_p!(source_dir)
    File.mkdir_p!(dest_dir)

    # Cleanup after test
    on_exit(fn ->
      File.rm_rf!(source_dir)
      File.rm_rf!(dest_dir)
    end)

    %{source_dir: source_dir, dest_dir: dest_dir}
  end

  describe "backup/3" do
    test "backs up specified directories from home to vault", %{
      source_dir: source_dir,
      dest_dir: dest_dir
    } do
      # Arrange - create test directories with files
      docs_dir = Path.join(source_dir, "Documents")
      File.mkdir_p!(docs_dir)
      File.write!(Path.join(docs_dir, "file1.txt"), "content1")
      File.write!(Path.join(docs_dir, "file2.txt"), "content2")

      downloads_dir = Path.join(source_dir, "Downloads")
      File.mkdir_p!(downloads_dir)
      File.write!(Path.join(downloads_dir, "download.zip"), "binary data")

      # Act
      dirs_to_backup = ["Documents", "Downloads"]
      assert {:ok, result} = HomeDirs.backup(source_dir, dest_dir, dirs_to_backup)

      # Assert - verify directories were created
      assert File.dir?(Path.join([dest_dir, "home", "Documents"]))
      assert File.dir?(Path.join([dest_dir, "home", "Downloads"]))

      # Verify files were copied
      assert File.exists?(Path.join([dest_dir, "home", "Documents", "file1.txt"]))
      assert File.exists?(Path.join([dest_dir, "home", "Documents", "file2.txt"]))
      assert File.exists?(Path.join([dest_dir, "home", "Downloads", "download.zip"]))

      # Verify content
      assert File.read!(Path.join([dest_dir, "home", "Documents", "file1.txt"])) == "content1"

      # Verify result
      assert result.backed_up == ["Documents", "Downloads"]
      assert result.skipped == []
    end

    test "skips directories that don't exist", %{source_dir: source_dir, dest_dir: dest_dir} do
      # Only create Documents, not Downloads
      docs_dir = Path.join(source_dir, "Documents")
      File.mkdir_p!(docs_dir)
      File.write!(Path.join(docs_dir, "file.txt"), "content")

      # Try to backup both
      dirs_to_backup = ["Documents", "Downloads", "Pictures"]

      assert {:ok, result} = HomeDirs.backup(source_dir, dest_dir, dirs_to_backup)

      # Verify only Documents was backed up
      assert result.backed_up == ["Documents"]
      assert "Downloads" in result.skipped
      assert "Pictures" in result.skipped
    end

    test "handles nested directories correctly", %{source_dir: source_dir, dest_dir: dest_dir} do
      # Create nested structure
      nested = Path.join([source_dir, "Documents", "Work", "Projects"])
      File.mkdir_p!(nested)
      File.write!(Path.join(nested, "project.txt"), "project data")

      assert {:ok, _result} = HomeDirs.backup(source_dir, dest_dir, ["Documents"])

      # Verify nested structure preserved
      assert File.exists?(
               Path.join([dest_dir, "home", "Documents", "Work", "Projects", "project.txt"])
             )

      assert File.read!(
               Path.join([dest_dir, "home", "Documents", "Work", "Projects", "project.txt"])
             ) ==
               "project data"
    end

    test "excludes common junk files", %{source_dir: source_dir, dest_dir: dest_dir} do
      docs_dir = Path.join(source_dir, "Documents")
      File.mkdir_p!(docs_dir)
      File.write!(Path.join(docs_dir, "important.txt"), "keep this")
      File.write!(Path.join(docs_dir, ".DS_Store"), "junk")

      # Create node_modules directory
      node_modules = Path.join([source_dir, "Documents", "node_modules"])
      File.mkdir_p!(node_modules)
      File.write!(Path.join(node_modules, "package.json"), "should be excluded")

      assert {:ok, _result} = HomeDirs.backup(source_dir, dest_dir, ["Documents"])

      # Important file should exist
      assert File.exists?(Path.join([dest_dir, "home", "Documents", "important.txt"]))

      # .DS_Store should NOT exist
      refute File.exists?(Path.join([dest_dir, "home", "Documents", ".DS_Store"]))

      # node_modules should NOT exist
      refute File.exists?(Path.join([dest_dir, "home", "Documents", "node_modules"]))
    end

    test "returns error if source directory doesn't exist" do
      result = HomeDirs.backup("/nonexistent/path", "/tmp/dest", ["Documents"])
      assert {:error, reason} = result
      assert reason =~ "source directory does not exist"
    end

    test "creates home directory in vault if it doesn't exist", %{
      source_dir: source_dir,
      dest_dir: dest_dir
    } do
      docs_dir = Path.join(source_dir, "Documents")
      File.mkdir_p!(docs_dir)
      File.write!(Path.join(docs_dir, "file.txt"), "content")

      # Ensure home dir doesn't exist
      home_dir = Path.join(dest_dir, "home")
      refute File.dir?(home_dir)

      assert {:ok, _result} = HomeDirs.backup(source_dir, dest_dir, ["Documents"])

      # Home dir should now exist
      assert File.dir?(home_dir)
    end

    test "works with empty directories", %{source_dir: source_dir, dest_dir: dest_dir} do
      # Create empty Documents directory
      docs_dir = Path.join(source_dir, "Documents")
      File.mkdir_p!(docs_dir)

      assert {:ok, result} = HomeDirs.backup(source_dir, dest_dir, ["Documents"])

      # Directory should be created even if empty
      assert File.dir?(Path.join([dest_dir, "home", "Documents"]))
      assert result.backed_up == ["Documents"]
    end

    test "handles empty directory list", %{source_dir: source_dir, dest_dir: dest_dir} do
      assert {:ok, result} = HomeDirs.backup(source_dir, dest_dir, [])

      assert result.backed_up == []
      assert result.skipped == []
    end
  end

  describe "backup/3 with dry_run option" do
    test "doesn't copy files in dry run mode", %{source_dir: source_dir, dest_dir: dest_dir} do
      docs_dir = Path.join(source_dir, "Documents")
      File.mkdir_p!(docs_dir)
      File.write!(Path.join(docs_dir, "file.txt"), "content")

      assert {:ok, result} = HomeDirs.backup(source_dir, dest_dir, ["Documents"], dry_run: true)

      # Should return what would be backed up
      assert result.backed_up == ["Documents"]

      # But files should NOT exist
      refute File.exists?(Path.join([dest_dir, "home", "Documents", "file.txt"]))
    end
  end
end
