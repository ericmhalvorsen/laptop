defmodule Vault.UI.Progress do
  @moduledoc """
  Progress UI for Vault.
  """

  @filled "█"
  @partials ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
  @bar_width_ratio 0.5

  @progresses %{}

  def enabled? do
    System.get_env("DISABLE_VAULT_OUTPUT") != "1"
  end

  def start_progress(_id, _label, total) when total <= 0, do: :ok
  def start_progress(id, label, total) do
    @progresses = Map.put(@progresses, id, %{label: label, total: total, current: 0})

    if enabled?() do
      Owl.ProgressBar.start(
        id: id,
        label: label,
        total: total,
        bar_width_ratio: @bar_width_ratio,
        filled_symbol: @filled,
        partial_symbols: @partials
      )
    else
      :ok
    end
  end

  def increment(id) do
    @progresses = Map.update!(@progresses, id, fn progress ->
      %{progress | current: progress.current + 1}
    end)

    if enabled?() do
      Owl.ProgressBar.inc(id: id)
      if finished?(id) do
        Owl.LiveScreen.await_render()
      end
    end

    :ok
  end

  def puts(iodata) do
    if enabled?() do
      Owl.IO.puts(iodata)
    else
      :ok
    end
  end

  def tag(text, color) do
    if enabled?() do
      Owl.Data.tag(text, color)
    else
      text
    end
  end

  def setup_logger do
    if enabled?() && !:persistent_term.get({__MODULE__, :logger_setup}, false) do
      :persistent_term.put({__MODULE__, :logger_setup}, true)
      _ = :logger.remove_handler(:default)

      :logger.add_handler(:default, :logger_std_h, %{
        config: %{type: {:device, Owl.LiveScreen}},
        formatter: Logger.Formatter.new()
      })
    else
      :ok
    end
  end

  def finished?(id) do
    @progresses[id] && @progresses[id].current >= @progresses[id].total
  end
end
