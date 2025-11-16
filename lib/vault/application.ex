defmodule Vault.Application do
  @moduledoc """
  Vault CLI Application

  Contains utilities for backup, restore, and install of User
  directories / preferences / files to and from a vault directory.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Vault.State, %{}}
    ]

    Supervisor.start_link(
      children,
      [strategy: :one_for_one, name: Vault.Supervisor]
    )
  end
end
