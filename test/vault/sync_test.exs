defmodule Vault.SyncTest do
  use ExUnit.Case, async: true
  alias Vault.Sync

  @moduletag :tmp_dir

  describe "copy_file/3" do
    test "copies a single file successfully", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.txt")
      dest = Path.join(tmp_dir, "dest.txt")

      File.write!(source, "test content")

      assert :ok = Sync.copy_file(source, dest)
      assert File.read!(dest) == "test content"
    end

    test "preserves permissions by default", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.txt")
      dest = Path.join(tmp_dir, "dest.txt")

      File.write!(source, "test")
      File.chmod!(source, 0o755)

      assert :ok = Sync.copy_file(source, dest)

      {:ok, source_stat} = File.stat(source)
      {:ok, dest_stat} = File.stat(dest)
      assert source_stat.mode == dest_stat.mode
    end

    test "creates parent directories if needed", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.txt")
      dest = Path.join([tmp_dir, "nested", "dir", "dest.txt"])

      File.write!(source, "test")

      assert :ok = Sync.copy_file(source, dest)
      assert File.read!(dest) == "test"
    end

    test "returns error for non-existent source", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "missing.txt")
      dest = Path.join(tmp_dir, "dest.txt")

      assert {:error, :enoent} = Sync.copy_file(source, dest)
    end

    test "dry run does not copy file", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.txt")
      dest = Path.join(tmp_dir, "dest.txt")

      File.write!(source, "test")

      assert :ok = Sync.copy_file(source, dest, dry_run: true)
      refute File.exists?(dest)
    end

    test "skips copy if file unchanged (with rsync)", %{tmp_dir: tmp_dir} do
      if Sync.available?() do
        source = Path.join(tmp_dir, "source.txt")
        dest = Path.join(tmp_dir, "dest.txt")

        File.write!(source, "test")
        Sync.copy_file(source, dest)

        # Modify dest timestamp
        stat = File.stat!(dest)
        File.touch!(dest, stat.mtime)

        # Copy again - should skip if unchanged
        assert :ok = Sync.copy_file(source, dest)
      else
        :skip
      end
    end
  end

  describe "copy_tree/3" do
    test "copies directory tree successfully", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      dest = Path.join(tmp_dir, "dest")

      File.mkdir_p!(Path.join(source, "subdir"))
      File.write!(Path.join(source, "file1.txt"), "content1")
      File.write!(Path.join([source, "subdir", "file2.txt"]), "content2")

      assert :ok = Sync.copy_tree(source, dest)
      assert File.read!(Path.join(dest, "file1.txt")) == "content1"
      assert File.read!(Path.join([dest, "subdir", "file2.txt"])) == "content2"
    end

    test "excludes files matching patterns", %{tmp_dir: tmp_dir} do
      if Sync.available?() do
        source = Path.join(tmp_dir, "source")
        dest = Path.join(tmp_dir, "dest")

        File.mkdir_p!(source)
        File.write!(Path.join(source, "keep.txt"), "keep")
        File.write!(Path.join(source, ".DS_Store"), "ignore")
        File.write!(Path.join(source, "test.log"), "ignore")

        assert :ok = Sync.copy_tree(source, dest, exclude: [".DS_Store", "*.log"])
        assert File.exists?(Path.join(dest, "keep.txt"))
        refute File.exists?(Path.join(dest, ".DS_Store"))
        refute File.exists?(Path.join(dest, "test.log"))
      else
        :skip
      end
    end

    test "dry run does not copy files", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      dest = Path.join(tmp_dir, "dest")

      File.mkdir_p!(source)
      File.write!(Path.join(source, "file.txt"), "content")

      assert :ok = Sync.copy_tree(source, dest, dry_run: true)
      refute File.exists?(dest)
    end

    test "returns ok for non-existent source", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "missing")
      dest = Path.join(tmp_dir, "dest")

      assert :ok = Sync.copy_tree(source, dest)
    end
  end

  describe "compute_transfer_count/3" do
    test "counts files to transfer", %{tmp_dir: tmp_dir} do
      if Sync.available?() do
        source = Path.join(tmp_dir, "source")
        dest = Path.join(tmp_dir, "dest")

        File.mkdir_p!(source)
        File.write!(Path.join(source, "file1.txt"), "content1")
        File.write!(Path.join(source, "file2.txt"), "content2")

        count = Sync.compute_transfer_count(source, dest)
        assert count > 0
      else
        :skip
      end
    end

    test "respects exclude patterns", %{tmp_dir: tmp_dir} do
      if Sync.available?() do
        source = Path.join(tmp_dir, "source")
        dest = Path.join(tmp_dir, "dest")

        File.mkdir_p!(source)
        File.write!(Path.join(source, "keep.txt"), "keep")
        File.write!(Path.join(source, ".DS_Store"), "ignore")

        count_all = Sync.compute_transfer_count(source, dest)
        count_exclude = Sync.compute_transfer_count(source, dest, [".DS_Store"])

        assert count_exclude < count_all
      else
        :skip
      end
    end
  end

  describe "available?/0" do
    test "returns boolean indicating rsync availability" do
      result = Sync.available?()
      assert is_boolean(result)
    end
  end
end
