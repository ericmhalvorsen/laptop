defmodule Vault.Utils do
  @moduledoc """
  Utility functions for external command paths in Vault.
  """
  use Memoize

  @doc """
  Returns the path to the brew executable, or nil if not found.
  """
  defmemo brew_path do
    System.find_executable("brew") ||
      if(File.exists?("/opt/homebrew/bin/brew"), do: "/opt/homebrew/bin/brew") ||
      if(File.exists?("/usr/local/bin/brew"), do: "/usr/local/bin/brew") ||
      nil
  end

  @doc """
  Returns the path to the apt executable, or nil if not found.
  """
  defmemo apt_path do
    System.find_executable("apt") ||
      if(File.exists?("/usr/bin/apt"), do: "/usr/bin/apt") ||
      nil
  end

  @doc """
  Returns the path to the dpkg executable, or nil if not found.
  """
  defmemo dpkg_path do
    System.find_executable("dpkg") ||
      if(File.exists?("/usr/bin/dpkg"), do: "/usr/bin/dpkg") ||
      nil
  end

  @doc """
  Returns the path to the snap executable, or nil if not found.
  """
  defmemo snap_path do
    System.find_executable("snap") ||
      if(File.exists?("/usr/bin/snap"), do: "/usr/bin/snap") ||
      nil
  end
end
