defmodule Vault.UI.Progress do
  @moduledoc """
  Progress UI for Vault.
  """

  @filled "█"
  @partials ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
  @bar_width_ratio 0.5

  @spec enabled? :: boolean()
  def enabled? do
    !test?() && System.get_env("DISABLE_VAULT_OUTPUT") != "1"
  end

  @spec test? :: boolean()
  def test? do
    Application.get_env(:vault, :env, :prod) == :test
  end

  def start_progress(_id, _label, total) when total <= 0, do: :ok

  def start_progress(id, label, total) do
    Vault.State.update_progress(id, fn _ -> %{total: total, current: 0} end)

    if enabled?() && total > 0 do
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

  @spec set_detail(any(), any()) :: :ok
  def set_detail(id, text) do
    if enabled?() do
      safe_text =
        case text do
          bin when is_binary(bin) -> String.slice(bin, 0, 200)
          other -> to_string(other) |> String.slice(0, 200)
        end

      Owl.LiveScreen.update({:detail, id}, safe_text)
    else
      :ok
    end
  end

  @spec increment(String.t()) :: :ok
  def increment(id) do
    Vault.State.update_progress(id, fn progress ->
      %{progress | current: progress.current + 1}
    end)

    if enabled?() do
      Owl.ProgressBar.inc(id: id)
      if Vault.State.progress_finished?(id), do: set_detail(id, "")
    end

    :ok
  end

  @spec tag(String.t() | list(String.t()), atom()) :: String.t() | list(String.t())
  def tag(text, color) do
    if enabled?(), do: Owl.Data.tag(text, color), else: text
  end

  @spec puts(any()) :: nil | :ok | any()
  def puts(iodata) do
    case enabled?() do
      false -> if test?(), do: Vault.TestBuffer.write(iodata)
      true -> Owl.IO.puts(iodata)
    end

    iodata
  end

  @spec info(any()) :: :ok | any()
  def info(messages) do
    [messages] |> List.flatten() |> tag(:cyan) |> puts
  end

  @spec debug(String.t() | list(String.t())) :: list(String.t())
  def debug(messages) do
    [messages]
    |> List.flatten()
    |> Enum.map(fn m -> "   ---- DEBUG ---- #{m}" end)
    |> tag([:magenta, :faint])
    |> puts()
  end

  @spec warn(any()) :: :ok | any()
  def warn(messages) do
    [messages] |> List.flatten() |> tag(:yellow) |> puts
  end

  @spec error(any()) :: nil | :ok | any()
  def error(messages) do
    [messages] |> List.flatten() |> tag(:red) |> puts
  end
end
