defmodule Vault.TestHelpers do
  @moduledoc """
  Test helper utilities for Vault tests.
  Import this module in your test cases to access helper functions.
  """

  import ExUnit.Callbacks

  @doc """
  Creates a temporary directory for testing.
  Returns the path and ensures cleanup after test.

  ## Examples

      setup :tmp_dir

      test "some file operation", %{tmp_dir: tmp_dir} do
        # tmp_dir is automatically created and cleaned up
      end
  """
  def tmp_dir(_context \\ %{}) do
    path = Path.join(System.tmp_dir!(), "vault_test_#{:rand.uniform(999_999_999)}")
    File.mkdir_p!(path)

    on_exit(fn ->
      File.rm_rf!(path)
    end)

    %{tmp_dir: path}
  end

  @doc """
  Creates a test file with content at the given path.
  Automatically creates parent directories.
  """
  def create_test_file(path, content \\ "test content") do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
    path
  end

  @doc """
  Creates multiple test files in a directory structure.

  ## Examples

      create_test_files(tmp_dir, %{
        ".zshrc" => "zsh config",
        ".gitconfig" => "git config",
        ".config/starship.toml" => "starship config"
      })
  """
  def create_test_files(base_dir, file_map) when is_map(file_map) do
    Enum.each(file_map, fn {relative_path, content} ->
      full_path = Path.join(base_dir, relative_path)
      create_test_file(full_path, content)
    end)

    base_dir
  end

  @doc """
  Creates a dotfile in the given directory.
  """
  def create_dotfile(dir, name, content \\ "dotfile content") do
    path = Path.join(dir, name)
    create_test_file(path, content)
  end

  @doc """
  Creates a mock Homebrew environment for testing.
  """
  def create_homebrew_mock(tmp_dir) do
    brew_dir = Path.join(tmp_dir, "homebrew")
    File.mkdir_p!(brew_dir)

    create_test_files(brew_dir, %{
      "Brewfile" => """
      tap "homebrew/bundle"
      brew "git"
      brew "elixir"
      cask "warp"
      """,
      "formulas.txt" => "git\nelixir\n",
      "casks.txt" => "warp\n"
    })

    brew_dir
  end

  @doc """
  Creates mock dotfiles in a directory.
  Returns map of created files.
  """
  def create_mock_dotfiles(dir) do
    dotfiles = %{
      ".zshrc" => "# ZSH Config\nexport PATH=$HOME/.local/bin:$PATH",
      ".gitconfig" => "[user]\n  name = Test User\n  email = test@example.com",
      ".vimrc" => "set number\nset autoindent",
      ".tmux.conf" => "set -g prefix C-a"
    }

    create_test_files(dir, dotfiles)
    dotfiles
  end

  @doc """
  Sets up a complete test environment with source and destination dirs.
  """
  def setup_test_env(_context \\ %{}) do
    source = Path.join(System.tmp_dir!(), "vault_test_source_#{:rand.uniform(999_999_999)}")
    dest = Path.join(System.tmp_dir!(), "vault_test_dest_#{:rand.uniform(999_999_999)}")

    File.mkdir_p!(source)
    File.mkdir_p!(dest)

    on_exit(fn ->
      File.rm_rf!(source)
      File.rm_rf!(dest)
    end)

    %{source: source, dest: dest}
  end
end
