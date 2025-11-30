defmodule Vault.Utils.FileUtilsTest do
  use ExUnit.Case
  import Vault.TestHelpers
  alias Vault.Utils.FileUtils

  describe "list_files_recursive/2" do
    setup :tmp_dir

    test "lists all files recursively", %{tmp_dir: tmp_dir} do
      create_test_files(tmp_dir, %{
        "file1.txt" => "",
        "nested/file2.txt" => "",
        "nested/deep/file3.txt" => "",
        "other/file4.txt" => ""
      })

      assert {:ok, files} = FileUtils.list_files_recursive(tmp_dir)

      assert "file1.txt" in files
      assert "nested/file2.txt" in files
      assert "nested/deep/file3.txt" in files
      assert "other/file4.txt" in files
    end

    test "excludes specified patterns", %{tmp_dir: tmp_dir} do
      create_test_files(tmp_dir, %{
        "file1.txt" => "",
        ".DS_Store" => "",
        "node_modules/package.json" => "",
        "src/main.js" => ""
      })

      assert {:ok, files} =
               FileUtils.list_files_recursive(tmp_dir, exclude: [".DS_Store", "node_modules"])

      assert "file1.txt" in files
      assert "src/main.js" in files
      refute ".DS_Store" in files
      refute Enum.any?(files, &String.contains?(&1, "node_modules"))
    end

    test "handles empty directory", %{tmp_dir: tmp_dir} do
      assert {:ok, []} = FileUtils.list_files_recursive(tmp_dir)
    end
  end

  describe "ensure_dir/1" do
    setup :tmp_dir

    test "creates directory if it doesn't exist", %{tmp_dir: tmp_dir} do
      new_dir = Path.join(tmp_dir, "new_directory")

      assert {:ok, ^new_dir} = FileUtils.ensure_dir(new_dir)
      assert File.dir?(new_dir)
    end

    test "creates nested directories", %{tmp_dir: tmp_dir} do
      new_dir = Path.join([tmp_dir, "deeply", "nested", "directory"])

      assert {:ok, ^new_dir} = FileUtils.ensure_dir(new_dir)
      assert File.dir?(new_dir)
    end

    test "succeeds if directory already exists", %{tmp_dir: tmp_dir} do
      existing_dir = Path.join(tmp_dir, "existing")
      File.mkdir_p!(existing_dir)

      assert {:ok, ^existing_dir} = FileUtils.ensure_dir(existing_dir)
      assert File.dir?(existing_dir)
    end
  end

  describe "file_size/1" do
    setup :tmp_dir

    test "returns size of a file", %{tmp_dir: tmp_dir} do
      file = Path.join(tmp_dir, "test.txt")
      content = "Hello, World!"
      File.write!(file, content)

      assert {:ok, size} = FileUtils.file_size(file)
      assert size == byte_size(content)
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = FileUtils.file_size("/nonexistent/file.txt")
    end
  end

  describe "format_size/1" do
    test "formats bytes" do
      assert FileUtils.format_size(500) == "500 B"
      assert FileUtils.format_size(1023) == "1023 B"
    end

    test "formats kilobytes" do
      assert FileUtils.format_size(1024) == "1.0 KB"
      assert FileUtils.format_size(2048) == "2.0 KB"
      assert FileUtils.format_size(1536) == "1.5 KB"
    end

    test "formats megabytes" do
      assert FileUtils.format_size(1_048_576) == "1.0 MB"
      assert FileUtils.format_size(2_097_152) == "2.0 MB"
      assert FileUtils.format_size(1_572_864) == "1.5 MB"
    end

    test "formats gigabytes" do
      assert FileUtils.format_size(1_073_741_824) == "1.0 GB"
      assert FileUtils.format_size(2_147_483_648) == "2.0 GB"
      assert FileUtils.format_size(1_610_612_736) == "1.5 GB"
    end
  end
end
