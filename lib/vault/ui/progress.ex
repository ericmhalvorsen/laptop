defmodule Vault.UI.Progress do
  @moduledoc """
  Progress UI for Vault.
  """

  @filled "█"
  @partials ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
  @bar_width_ratio 0.5

  def enabled? do
    System.get_env("DISABLE_VAULT_OUTPUT") != "1"
  end

  defp test_env? do
    Application.get_env(:vault, :env, :prod) == :test
  end

  def start_progress(_id, _label, total) when total <= 0, do: :ok

  def start_progress(id, label, total) do
    Vault.State.update_progress(id, fn _ -> %{total: total, current: 0} end)

    if enabled?() && !test_env?() do
      Owl.ProgressBar.start(
        id: id,
        label: label,
        total: total,
        bar_width_ratio: @bar_width_ratio,
        filled_symbol: @filled,
        partial_symbols: @partials
      )

      Owl.LiveScreen.add_block({:detail, id}, state: "")
    else
      :ok
    end
  end

  def increment(id) do
    Vault.State.update_progress(id, fn progress ->
      %{progress | current: progress.current + 1}
    end)

    if enabled?() && !test_env?() do
      Owl.ProgressBar.inc(id: id)

      if Vault.State.progress_finished?(id) do
        Owl.LiveScreen.await_render()
      end
    end

    :ok
  end

  def puts(iodata) do
    cond do
      !enabled?() ->
        :ok

      test_env?() ->
        IO.puts(iodata)

      true ->
        try do
          Owl.IO.puts(iodata)
        rescue
          ArgumentError ->
            # Fallback if LiveScreen/formatter crashes on large iodata
            IO.puts(iodata)
        end
    end
  end

  def tag(text, color) do
    cond do
      !enabled?() ->
        text

      test_env?() ->
        text

      true ->
        Owl.Data.tag(text, color)
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

  def set_detail(id, text) do
    if enabled?() && !test_env?() do
      safe_text =
        case text do
          bin when is_binary(bin) -> String.slice(bin, 0, 200)
          other -> to_string(other) |> String.slice(0, 200)
        end

      try do
        Owl.LiveScreen.update({:detail, id}, safe_text)
      rescue
        ArgumentError -> :ok
      end
    else
      :ok
    end
  end
end
