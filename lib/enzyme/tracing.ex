defmodule Enzyme.Tracing do
  @moduledoc false

  import Enzyme.Wraps

  alias Enzyme.Types

  @spec tracer(boolean() | IO.device()) :: Types.tracer()
  def tracer(false) do
    {false, 0, nil}
  end

  def tracer(true) do
    {true, 0, :stdio}
  end

  def tracer(device) do
    {true, 0, device}
  end

  def trace(_event, result, {false, _, _}) do
    result
  end

  def trace(:match, result, {true, level, device}) when is_list(result) do
    list = Enum.map_join(result, ", ", fn item -> format(single(item)) end)
    indented(device, level, "◀ [#{list}]")
    result
  end

  def trace(:match, result, {true, level, device}) do
    indented(device, level, "◀ #{format(result)}")
    result
  end

  def trace(:pick, result, {true, level, device}) when is_list(result) do
    list = Enum.map_join(result, ", ", fn item -> format(item) end)
    indented(device, level, "◆ [#{list}]")
    result
  end

  def trace(:pick, result, {true, level, device}) do
    indented(device, level, "◆ #{format(result)}")
    result
  end

  def trace(_event, _lens, input, {false, _level, _}) do
    input
  end

  def trace(event, lens, input, tracer, marker \\ "")

  def trace(:start, lens, input, {true, level, device}, marker) do
    indented(device, level, "⏺", "#{format(input)}#{lens} #{marker}")
    lens
  end

  def trace(:end, _lens, result, {true, level, device}, marker) do
    indented(device, level, "⏹", "#{format(result)} #{marker}")
    result
  end

  def trace(:next, lens, input, {true, 0, device}, marker) do
    trace(:start, lens, input, {true, 0, device}, marker)
  end

  def trace(:next, lens, input, {true, level, device}, marker) do
    indented(device, level, "▶ #{format(input)}#{lens} #{marker}")
    :next
  end

  def trace(:exception, lens, input, {true, level, device}, marker) do
    indented(device, level, "! #{format(input)}#{lens} #{marker}")
    :exception
  end

  @spec inc(Types.tracer()) :: Types.tracer()
  def inc({tracing, level, device}) do
    {tracing, level + 1, device}
  end

  @spec dec(Types.tracer()) :: Types.tracer()
  def dec({tracing, level, device}) do
    {tracing, level - 1, device}
  end

  defp indented(device, level, message) do
    indented(device, level, "└", message)
  end

  defp indented(device, level, sign, message) do
    message
    |> String.split("\n")
    |> Enum.with_index(fn line, index -> indented_line(device, level, sign, line, index) end)
  end

  defp indented_line(device, level, sign, line, 0) do
    IO.puts(device, "#{String.duplicate("┆   ", level)}#{sign} #{line}")
  end

  defp indented_line(device, level, _sign, line, _index) do
    IO.puts(device, "#{String.duplicate("┆   ", level)}┆   #{line}")
  end

  @syntax_colors [
    atom: :cyan,
    binary: :default_color,
    boolean: :magenta,
    charlist: :yellow,
    list: :magenta,
    map: :cyan,
    nil: :magenta,
    number: :yellow,
    string: :green,
    tuple: :cyan,
    variable: :light_cyan,
    call: :default_color,
    operator: :default_color
  ]

  defp format(value) do
    inspect(
      value,
      pretty: true,
      limit: :infinity,
      syntax_colors: @syntax_colors
    )
  end
end
