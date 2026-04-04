defmodule Vault.ConfigTest do
  use ExUnit.Case, async: true
  alias Vault.Config
  alias Vault.TestBuffer


  @moduletag :tmp_dir

  describe "load/1" do
    test "loads a valid configuration and resolves steps", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "vault.yaml")
      yaml_content = """
      version: 1
      :steps:
        - :name: brew
          :label: "Homebrew"
        - :name: dotfiles
          :label: "Dotfiles"
      :git:
        :steps:
          - brew
      :vault:
        :steps:
          - brew
          - dotfiles
      :defaults:
        :exclude_patterns:
          - "*.log"
      """
      File.write!(config_path, yaml_content)

      config = Config.load(config_path: config_path)

      assert config.version == 1
      assert config.defaults.exclude_patterns == ["*.log"]

      # Verify step resolution in git
      assert [%{name: :brew, label: "Homebrew"}] = config.git.steps

      # Verify step resolution in vault
      assert [
               %{name: :brew, label: "Homebrew"},
               %{name: :dotfiles, label: "Dotfiles"}
             ] = config.vault.steps
    end

    test "handles missing steps with a warning", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "vault_missing_steps.yaml")
      yaml_content = """
      :steps:
        - :name: existing
          :label: "Existing"
      :git:
        :steps:
          - existing
          - missing
      :vault:
        :steps: []
      """
      File.write!(config_path, yaml_content)

      TestBuffer.clear()
      config = Config.load(config_path: config_path)

      # Verify the missing step is partially resolved
      assert [%{name: :existing}, %{name: :missing}] = config.git.steps

      # Verify warning output
      output = TestBuffer.get()
      assert output =~ "Warning: Step 'missing' not found in :steps list"
    end
  end

  describe "default_excludes/1" do
    test "returns exclude patterns from config", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "vault_excludes.yaml")
      yaml_content = """
      :steps: []
      :git:
        :steps: []
      :vault:
        :steps: []
      :defaults:
        :exclude_patterns:
          - "node_modules"
          - ".git"
      """
      File.write!(config_path, yaml_content)

      excludes = Config.default_excludes(config_path: config_path)
      assert excludes == ["node_modules", ".git"]
    end

    test "returns empty list when no exclude patterns are defined", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "vault_no_excludes.yaml")
      yaml_content = """
      :steps: []
      :git:
        :steps: []
      :vault:
        :steps: []
      :defaults:
        :other: "value"
      """
      File.write!(config_path, yaml_content)

      excludes = Config.default_excludes(config_path: config_path)
      assert excludes == []
    end
  end
end
