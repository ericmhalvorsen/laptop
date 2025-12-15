defmodule Vault.TestBuffer do
  @moduledoc """
  Test buffer for capturing Progress output during tests without writing to console.

  This module provides a way to capture output during tests while keeping the console
  silent. It uses an Agent to store output in memory that can be accessed by tests.
  """

  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def write(iodata) do
    Agent.update(__MODULE__, fn buffer -> [buffer, iodata] end)
  end

  def get do
    case Process.whereis(__MODULE__) do
      nil -> ""
      _pid -> Agent.get(__MODULE__, &IO.iodata_to_binary/1)
    end
  end

  def clear do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> Agent.update(__MODULE__, fn _ -> [] end)
    end
  end
end
