defmodule Vault.State do
  @moduledoc """
  State storage. Mainly holds progress counts and step statistics.
  """

  use Agent

  def update_progress(id, update_func) do
    update(fn state ->
      current_progress = Map.get(state, id)

      # Initialize progress if it doesn't exist
      current_progress = if current_progress do
        current_progress
      else
        %{current: 0, total: 0}
      end

      updated_value = update_func.(current_progress)
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

  @doc """
  Initializes step stats tracking for a new session.
  """
  def init_step_stats do
    update(fn state -> Map.put(state, :step_stats, []) end)
  end

  @doc """
  Adds a step's stats to the tracking list.

  ## Parameters
    * `step_name` - The name of the step
    * `stats` - Map containing :count, :total_size, and :runtime_ms
  """
  def add_step_stat(step_name, stats) do
    update(fn state ->
      step_stats = Map.get(state, :step_stats, [])
      new_stat = Map.merge(%{name: step_name}, stats)
      Map.put(state, :step_stats, [new_stat | step_stats])
    end)
  end

  @doc """
  Gets all accumulated step stats.
  """
  def get_step_stats do
    get(:step_stats) || []
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
