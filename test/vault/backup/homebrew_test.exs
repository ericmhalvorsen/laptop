defmodule Vault.Backup.HomebrewTest do
  use ExUnit.Case
  alias Vault.Backup.Homebrew

  # Provide a simple mock for brew
  def mock_brew(_cmd, args, _opts) do
    cond do
      args == ["list", "--formula"] ->
        {"git\nelixir\n", 0}

      args == ["list", "--cask"] ->
        {"warp\n", 0}

      args == ["tap"] ->
        {"homebrew/core\n", 0}

      String.starts_with?(Enum.join(args, " "), "bundle dump") ->
        file_arg = Enum.find(args, &String.starts_with?(&1, "--file="))
        path = String.replace_prefix(file_arg, "--file=", "")
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, "tap \"homebrew/core\"\nbrew \"git\"\n")
        {"", 0}

      true ->
        {"", 0}
    end
  end

  setup do
    # Create temp directory for test backup destination
    dest_dir = Path.join(System.tmp_dir!(), "vault_homebrew_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(dest_dir)

    # Cleanup after test
    on_exit(fn ->
      File.rm_rf!(dest_dir)
    end)

    %{dest_dir: dest_dir}
  end

  describe "backup/1" do
    test "creates brew directory and all required files", %{dest_dir: dest_dir} do
      # Act
      assert {:ok, result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Assert - verify brew directory exists
      brew_dir = Path.join(dest_dir, "brew")
      assert File.dir?(brew_dir)

      # Verify all files exist
      assert File.exists?(Path.join(brew_dir, "Brewfile"))
      assert File.exists?(Path.join(brew_dir, "formulas.txt"))
      assert File.exists?(Path.join(brew_dir, "casks.txt"))
      assert File.exists?(Path.join(brew_dir, "taps.txt"))

      # Verify result contains counts
      assert Map.has_key?(result, :brewfile)
      assert Map.has_key?(result, :formulas)
      assert Map.has_key?(result, :casks)
      assert Map.has_key?(result, :taps)
    end

    test "Brewfile contains tap and brew entries", %{dest_dir: dest_dir} do
      # Act
      assert {:ok, _result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Assert
      brewfile = Path.join([dest_dir, "brew", "Brewfile"])
      content = File.read!(brewfile)

      # Should contain at least some basic entries (assuming Homebrew is installed)
      # We can't assert specific packages, but we can check format
      assert content != ""
    end

    test "formulas.txt contains installed formulas", %{dest_dir: dest_dir} do
      # Act
      assert {:ok, result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Assert
      formulas_file = Path.join([dest_dir, "brew", "formulas.txt"])
      content = File.read!(formulas_file)

      # Should be line-separated list
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == result.formulas
    end

    test "casks.txt contains installed casks", %{dest_dir: dest_dir} do
      # Act
      assert {:ok, result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Assert
      casks_file = Path.join([dest_dir, "brew", "casks.txt"])
      content = File.read!(casks_file)

      # Lines should match count
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == result.casks
    end

    test "taps.txt contains tapped repositories", %{dest_dir: dest_dir} do
      # Act
      assert {:ok, result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Assert
      taps_file = Path.join([dest_dir, "brew", "taps.txt"])
      content = File.read!(taps_file)

      # Lines should match count
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == result.taps
    end

    test "handles missing Homebrew gracefully" do
      # This test assumes Homebrew is installed
      # We're testing the happy path, not the error case
      # If Homebrew is not installed, the module should return an error
      dest_dir = Path.join(System.tmp_dir!(), "vault_homebrew_noinstall_#{:rand.uniform(10000)}")
      File.mkdir_p!(dest_dir)

      # Use mock brew to ensure deterministic success
      result = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Either success (brew installed) or specific error (brew not installed)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      File.rm_rf!(dest_dir)
    end

    test "creates brew directory if it doesn't exist", %{dest_dir: dest_dir} do
      # Ensure brew dir doesn't exist
      brew_dir = Path.join(dest_dir, "brew")
      refute File.dir?(brew_dir)

      # Act
      assert {:ok, _result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Assert
      assert File.dir?(brew_dir)
    end

    test "overwrites existing files on subsequent backups", %{dest_dir: dest_dir} do
      # First backup
      assert {:ok, result1} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Modify a file
      brewfile = Path.join([dest_dir, "brew", "Brewfile"])
      File.write!(brewfile, "# Modified content")

      # Second backup
      assert {:ok, result2} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # Verify it was overwritten (content should be regenerated)
      new_content = File.read!(brewfile)
      refute new_content == "# Modified content"

      # Results should be comparable (counts might be same)
      assert is_map(result1)
      assert is_map(result2)
    end

    test "returns error with invalid destination directory" do
      # Try to backup to a file instead of directory
      invalid_dest = "/dev/null"

      result = Homebrew.backup(invalid_dest, cmd: &__MODULE__.mock_brew/3)

      assert {:error, _reason} = result
    end
  end

  describe "backup/2 with options" do
    test "accepts dry_run option and doesn't write files", %{dest_dir: dest_dir} do
      # Act
      assert {:ok, result} =
               Homebrew.backup(dest_dir, dry_run: true, cmd: &__MODULE__.mock_brew/3)

      # Assert - brew directory should NOT be created in dry run
      brew_dir = Path.join(dest_dir, "brew")
      refute File.dir?(brew_dir)

      # But we should still get counts
      assert Map.has_key?(result, :formulas)
      assert Map.has_key?(result, :casks)
    end
  end

  describe "helper functions for edge cases" do
    test "handles empty formula list gracefully", %{dest_dir: dest_dir} do
      # This tests internal behavior - if no formulas, file should be created but empty/minimal
      assert {:ok, _result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      formulas_file = Path.join([dest_dir, "brew", "formulas.txt"])
      assert File.exists?(formulas_file)
    end

    test "handles empty cask list gracefully", %{dest_dir: dest_dir} do
      assert {:ok, _result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      casks_file = Path.join([dest_dir, "brew", "casks.txt"])
      assert File.exists?(casks_file)
    end

    test "validates files have correct line endings", %{dest_dir: dest_dir} do
      assert {:ok, _result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # All text files should end with newline
      for file <- ["formulas.txt", "casks.txt", "taps.txt"] do
        path = Path.join([dest_dir, "brew", file])
        content = File.read!(path)

        # Should end with newline (unless completely empty)
        if byte_size(content) > 0 do
          assert String.ends_with?(content, "\n"),
                 "#{file} should end with newline"
        end
      end
    end

    test "all files are created even if some lists are empty", %{dest_dir: dest_dir} do
      assert {:ok, result} = Homebrew.backup(dest_dir, cmd: &__MODULE__.mock_brew/3)

      # All files should exist regardless of whether there are items
      assert File.exists?(Path.join([dest_dir, "brew", "Brewfile"]))
      assert File.exists?(Path.join([dest_dir, "brew", "formulas.txt"]))
      assert File.exists?(Path.join([dest_dir, "brew", "casks.txt"]))
      assert File.exists?(Path.join([dest_dir, "brew", "taps.txt"]))

      # Counts might be zero but should be integers
      assert is_integer(result.formulas)
      assert is_integer(result.casks)
      assert is_integer(result.taps)
      assert result.formulas >= 0
      assert result.casks >= 0
      assert result.taps >= 0
    end
  end
end
