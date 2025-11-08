defmodule Vault.Backup.FontsTest do
  use ExUnit.Case
  alias Vault.Backup.Fonts

  setup do
    # Create temp home and vault directories
    home_dir = Path.join(System.tmp_dir!(), "vault_fonts_test_home_#{:rand.uniform(10000)}")
    vault_dir = Path.join(System.tmp_dir!(), "vault_fonts_test_vault_#{:rand.uniform(10000)}")

    File.mkdir_p!(home_dir)
    File.mkdir_p!(vault_dir)

    on_exit(fn ->
      File.rm_rf!(home_dir)
      File.rm_rf!(vault_dir)
    end)

    %{home_dir: home_dir, vault_dir: vault_dir}
  end

  describe "backup/3" do
    test "backs up font files from ~/Library/Fonts", %{home_dir: home_dir, vault_dir: vault_dir} do
      # Create ~/Library/Fonts directory with test fonts
      fonts_dir = Path.join([home_dir, "Library", "Fonts"])
      File.mkdir_p!(fonts_dir)

      File.write!(Path.join(fonts_dir, "CustomFont.ttf"), "fake ttf data")
      File.write!(Path.join(fonts_dir, "AnotherFont.otf"), "fake otf data")

      assert {:ok, result} = Fonts.backup(home_dir, vault_dir)

      # Verify fonts were copied
      assert result.fonts_copied == 2
      assert result.total_size > 0

      # Verify files exist in vault
      assert File.exists?(Path.join([vault_dir, "fonts", "CustomFont.ttf"]))
      assert File.exists?(Path.join([vault_dir, "fonts", "AnotherFont.otf"]))

      # Verify content
      assert File.read!(Path.join([vault_dir, "fonts", "CustomFont.ttf"])) == "fake ttf data"
    end

    test "returns empty result when ~/Library/Fonts doesn't exist", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      # Don't create Library/Fonts directory
      assert {:ok, result} = Fonts.backup(home_dir, vault_dir)

      assert result.fonts_copied == 0
      assert result.total_size == 0
    end

    test "returns empty result when ~/Library/Fonts is empty", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      # Create empty fonts directory
      fonts_dir = Path.join([home_dir, "Library", "Fonts"])
      File.mkdir_p!(fonts_dir)

      assert {:ok, result} = Fonts.backup(home_dir, vault_dir)

      assert result.fonts_copied == 0
      assert result.total_size == 0
    end

    test "creates vault/fonts directory if it doesn't exist", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      fonts_dir = Path.join([home_dir, "Library", "Fonts"])
      File.mkdir_p!(fonts_dir)
      File.write!(Path.join(fonts_dir, "Font.ttf"), "data")

      fonts_dest = Path.join(vault_dir, "fonts")
      refute File.dir?(fonts_dest)

      assert {:ok, _result} = Fonts.backup(home_dir, vault_dir)

      assert File.dir?(fonts_dest)
    end

    test "handles various font file extensions", %{home_dir: home_dir, vault_dir: vault_dir} do
      fonts_dir = Path.join([home_dir, "Library", "Fonts"])
      File.mkdir_p!(fonts_dir)

      File.write!(Path.join(fonts_dir, "font.ttf"), "ttf")
      File.write!(Path.join(fonts_dir, "font.otf"), "otf")
      File.write!(Path.join(fonts_dir, "font.woff"), "woff")
      File.write!(Path.join(fonts_dir, "font.woff2"), "woff2")

      assert {:ok, result} = Fonts.backup(home_dir, vault_dir)

      assert result.fonts_copied == 4
    end

    test "skips non-regular files (directories, symlinks)", %{
      home_dir: home_dir,
      vault_dir: vault_dir
    } do
      fonts_dir = Path.join([home_dir, "Library", "Fonts"])
      File.mkdir_p!(fonts_dir)

      File.write!(Path.join(fonts_dir, "Font.ttf"), "data")

      # Create a subdirectory
      File.mkdir_p!(Path.join(fonts_dir, "FontFamily"))

      assert {:ok, result} = Fonts.backup(home_dir, vault_dir)

      # Should only copy the regular file, not the directory
      assert result.fonts_copied == 1
    end
  end

  describe "backup/3 with dry_run option" do
    test "doesn't copy files in dry run mode", %{home_dir: home_dir, vault_dir: vault_dir} do
      fonts_dir = Path.join([home_dir, "Library", "Fonts"])
      File.mkdir_p!(fonts_dir)
      File.write!(Path.join(fonts_dir, "Font.ttf"), "data")

      assert {:ok, result} = Fonts.backup(home_dir, vault_dir, dry_run: true)

      # Returns 0 in dry run
      assert result.fonts_copied == 0
      assert result.total_size == 0

      # Files should NOT exist
      refute File.exists?(Path.join([vault_dir, "fonts", "Font.ttf"]))
    end
  end
end
