defmodule Vault.BackupTest do
  use ExUnit.Case, async: true
  alias Vault.Backup
  alias Vault.State

  @moduletag :tmp_dir

  setup do
    # Start State agent if not already started
    unless Process.whereis(State) do
      {:ok, _} = State.start_link(%{})
    end

    :ok
  end

  describe "backup/4 with tracker excludes" do
    test "excludes subdirectories that were backed up in a previous step", %{tmp_dir: tmp_dir} do
      if Vault.Sync.available?() do
        source = Path.join(tmp_dir, "source")
        dest1 = Path.join(tmp_dir, "dest1")
        dest2 = Path.join(tmp_dir, "dest2")

        # Create directory structure:
        # source/
        #   .config/
        #     app1/file.txt
        #     app2/file.txt
        #   .local/
        #     bin/script.sh
        File.mkdir_p!(Path.join(source, ".config/app1"))
        File.mkdir_p!(Path.join(source, ".config/app2"))
        File.mkdir_p!(Path.join(source, ".local/bin"))
        File.write!(Path.join(source, ".config/app1/file.txt"), "content1")
        File.write!(Path.join(source, ".config/app2/file.txt"), "content2")
        File.write!(Path.join(source, ".local/bin/script.sh"), "script")

        # Reset state
        State.reset()

        # Step 1: Backup just .config/app1
        {:ok, result1} =
          Backup.backup(source, dest1, [".config/app1/"], verbose: true)

        assert result1.backed_up == [".config/app1/"]
        assert File.exists?(Path.join(dest1, ".config/app1/file.txt"))
        refute File.exists?(Path.join(dest1, ".config/app2/file.txt"))

        # Step 2: Backup entire .config directory
        # Should exclude .config/app1 because it was already backed up
        {:ok, result2} =
          Backup.backup(source, dest2, [".config/"], verbose: true)

        assert result2.backed_up == [".config/"]

        # .config/app1 should NOT be in dest2 because it's excluded via tracker
        refute File.exists?(Path.join(dest2, ".config/app1/file.txt"))
        # .config/app2 SHOULD be in dest2
        assert File.exists?(Path.join(dest2, ".config/app2/file.txt"))
      else
        :skip
      end
    end

    test "tracker excludes work with multiple nested levels", %{tmp_dir: tmp_dir} do
      if Vault.Sync.available?() do
        source = Path.join(tmp_dir, "source")
        dest1 = Path.join(tmp_dir, "dest1")
        dest2 = Path.join(tmp_dir, "dest2")

        # Create deeply nested structure
        File.mkdir_p!(Path.join(source, ".config/app/sub1/deep"))
        File.mkdir_p!(Path.join(source, ".config/app/sub2"))
        File.write!(Path.join(source, ".config/app/sub1/deep/file.txt"), "deep")
        File.write!(Path.join(source, ".config/app/sub2/file.txt"), "sub2")
        File.write!(Path.join(source, ".config/app/root.txt"), "root")

        State.reset()

        # Step 1: Backup .config/app/sub1/
        {:ok, _} = Backup.backup(source, dest1, [".config/app/sub1/"], verbose: true)
        assert File.exists?(Path.join(dest1, ".config/app/sub1/deep/file.txt"))

        # Step 2: Backup entire .config/
        # Should exclude .config/app/sub1/ and everything under it
        {:ok, _} = Backup.backup(source, dest2, [".config/"], verbose: true)

        refute File.exists?(Path.join(dest2, ".config/app/sub1/deep/file.txt"))
        assert File.exists?(Path.join(dest2, ".config/app/sub2/file.txt"))
        assert File.exists?(Path.join(dest2, ".config/app/root.txt"))
      else
        :skip
      end
    end

    test "tracker excludes work for root directory backup (everything else)", %{tmp_dir: tmp_dir} do
      if Vault.Sync.available?() do
        source = Path.join(tmp_dir, "source")
        dest1 = Path.join(tmp_dir, "dest1")
        dest2 = Path.join(tmp_dir, "dest2")
        dest3 = Path.join(tmp_dir, "dest3")

        # Create structure
        File.mkdir_p!(Path.join(source, ".config/app"))
        File.mkdir_p!(Path.join(source, "Documents"))
        File.mkdir_p!(Path.join(source, "other"))
        File.write!(Path.join(source, ".config/app/file.txt"), "config")
        File.write!(Path.join(source, "Documents/doc.txt"), "doc")
        File.write!(Path.join(source, "other/file.txt"), "other")

        State.reset()

        # Step 1: Backup .config
        {:ok, _} = Backup.backup(source, dest1, [".config/"], verbose: true)
        assert File.exists?(Path.join(dest1, ".config/app/file.txt"))

        # Step 2: Backup Documents
        {:ok, _} = Backup.backup(source, dest2, ["Documents/"], verbose: true)
        assert File.exists?(Path.join(dest2, "Documents/doc.txt"))

        # Step 3: Backup "everything else" (root)
        # Should exclude .config and Documents since they were already backed up
        {:ok, _} = Backup.backup(source, dest3, ["./"], verbose: true)

        refute File.exists?(Path.join(dest3, ".config/app/file.txt"))
        refute File.exists?(Path.join(dest3, "Documents/doc.txt"))
        assert File.exists?(Path.join(dest3, "other/file.txt"))
      else
        :skip
      end
    end
  end
end
