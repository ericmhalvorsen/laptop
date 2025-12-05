defmodule Vault.State do
  @moduledoc """
  State storage. Mainly holds progress counts.
  """

  use Agent

  def update_progress(id, update_func) do
    update(fn state ->
      updated_value = update_func.(Map.get(state, id))
      Map.put(state, id, updated_value)
    end)
  end

  def progress_finished?(id) do
    case get(id) do
      %{current: current, total: total} when is_number(current) and is_number(total) ->
        current >= total

      _ ->
        false
    end
  end

  def start_link(init) do
    Agent.start_link(fn -> init end, name: __MODULE__)
  end

  def get(val) do
    Agent.get(__MODULE__, fn state -> state[val] end)
  end

  def update(update_func) do
    Agent.update(__MODULE__, update_func)
  end

  def reset do
    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn _ -> %{} end)
    end
  end
end
