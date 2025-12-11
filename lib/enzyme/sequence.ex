defmodule Enzyme.Sequence do
  @moduledoc """
  A lens that applies multiple lenses in sequence.

  The `opts` field stores parse-time iso definitions that serve as defaults
  when resolving iso references at runtime.

  ## Tracing
  `Enzyme.Sequence` supports tracing of selection and transformation steps.
  Add the option `__trace__: true` to the opts stored in the lens enable
  tracing output via `IO.puts`. For each step in the sequence, tracing shows
  the current value being processed, the lens being applied, and the result
  after applying that lens. Indentation is used to represent the depth of
  the sequence.

  ```elixir
  seq = %Sequence{
    lenses: [%One{index: "user"}, %One{index: "name"}],
    opts: [__trace__: true]
  }

  data = [
    single(%{"user" => %{"name" => "alice", "age" => 30}}),
    single(%{"user" => %{"name" => "bob", "age" => 25}})
  ]

  Sequence.select(seq, many(data), {true, 0})
  ⏺ many(single(%{"user" => %{"age" => 30, "name" => "alice"}}), single(%{"user" => %{"age" => 25, "name" => "bob"}})).user.name
    ∟ single(%{"user" => %{"age" => 30, "name" => "alice"}}).user
      ∟ single(%{"age" => 30, "name" => "alice"}).name
        ∟ ▶ single("alice")
    ∟ single(%{"user" => %{"age" => 25, "name" => "bob"}}).user
      ∟ single(%{"age" => 25, "name" => "bob"}).name
        ∟ ▶ single("bob")
  ⏹ many(single("alice"), single("bob"))
  ```
  """

  defstruct lenses: [], opts: []

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.Protocol
  alias Enzyme.Sequence
  alias Enzyme.Single
  alias Enzyme.Types

  @type t :: %Sequence{
          lenses: list(any()),
          opts: list({atom(), any()})
        }

  @doc """
  Selects elements from a collection of wrapped values by applying each lens in sequence. Returns
  the wrapped value selected by the last lens in the sequence.
  """

  @spec select(Sequence.t(), Types.wrapped()) :: Types.wrapped()

  def select(%Sequence{} = lens, %None{} = none) do
    tracer = tracer(lens)

    none
    |> trace(lens, none, tracer)
    |> trace(lens, :end, tracer)
  end

  def select(%Sequence{lenses: []} = lens, %Single{} = data) do
    tracer = tracer(lens)

    data
    |> trace(lens, data, tracer)
    |> trace(lens, :end, tracer)
  end

  def select(%Sequence{} = lens, %Single{} = data) do
    tracer = tracer(lens)

    data
    |> select_next(lens.lenses, tracer)
    |> trace(lens, :end, tracer)
  end

  def select(%Sequence{} = lens, %Many{values: list} = data) when is_list(list) do
    tracer = tracer(lens)
    trace("", lens, data, tracer)

    list
    |> Enum.map(fn item -> select_next(item, lens.lenses, inc(tracer)) end)
    |> many()
    |> trace(lens, :end, tracer)
  end

  def select(%Sequence{} = lens, invalid) do
    trace(:exception, lens, invalid, tracer(lens))

    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  @doc """
  Transforms elements in a collection by applying each lens in sequence.
  The transform function is applied to the values selected by the last lens
  in the sequence.
  """

  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()

  def transform(lens, data, fun)

  def transform(%Sequence{} = lens, %None{} = none, _transform) do
    tracer = tracer(lens)

    none
    |> trace(lens, none, tracer)
    |> trace(lens, :end, tracer)
  end

  def transform(%Sequence{lenses: []} = lens, %Single{} = data, fun) when is_transform(fun) do
    tracer = tracer(lens)

    single(fun.(unwrap!(data)))
    |> trace(lens, data, tracer)
    |> trace(lens, :end, tracer)
  end

  def transform(%Sequence{lenses: lenses} = lens, %Single{} = data, fun)
      when is_transform(fun) do
    tracer = tracer(lens)
    trace("", lens, data, tracer)

    data
    |> transform_next(lenses, fun, inc(tracer))
    |> trace(lens, :end, tracer)
  end

  def transform(%Sequence{lenses: lenses} = lens, %Many{values: list}, fun)
      when is_list(list) and is_transform(fun) do
    tracer = tracer(lens)
    trace("", lens, list, tracer)

    list
    |> Enum.map(fn item -> transform_next(item, lenses, fun, inc(tracer)) end)
    |> many()
    |> trace(lens, :end, tracer)
  end

  def transform(%Sequence{} = lens, invalid, fun) when is_transform(fun) do
    trace(:exception, lens, invalid, tracer(lens))

    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%Sequence{} = lens, wrapped, fun)
      when is_wrapped(wrapped) and not is_transform(fun) do
    trace(:exception, lens, wrapped, tracer(lens))

    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a transformation function of arity 1, got: #{inspect(fun)}"
  end

  defp select_next(value, [], tracer) do
    value |> trace(:match, value, tracer)
  end

  defp select_next(value, [lens | rest], tracer) do
    lens
    |> Protocol.select(value)
    |> trace(lens, value, tracer)
    |> select_next(rest, inc(tracer))
  end

  defp transform_next(data, [], fun, tracer) do
    single(fun.(unwrap!(data))) |> trace(:match, data, tracer)
  end

  defp transform_next(data, [next | rest], fun, tracer) do
    next
    |> Protocol.transform(data, fn item ->
      trace(data, next, single(item), tracer)
      unwrap!(transform_next(single(item), rest, fun, inc(tracer)))
    end)
  end

  defp tracer(%Sequence{opts: opts}) do
    case Keyword.get(opts, :__trace__, false) do
      true -> {true, 0}
      false -> {false, 0}
    end
  end

  defp trace(result, _lens, _value, {false, _level}) do
    result
  end

  defp trace(:exception, lens, value, {true, level}) do
    indented(level, "!", "#{value}#{lens} - Exception")
    :exception
  end

  defp trace(result, _lens, :end, {true, level}) do
    indented(level, "⏹", "#{result}")
    result
  end

  defp trace(result, :match, values, {true, level}) when is_list(values) do
    list = Enum.map_join(values, ", ", &to_string/1)
    indented(level, "[#{list}] *")
    result
  end

  defp trace(result, lens, values, {true, level}) when is_list(values) do
    list = Enum.map_join(values, ", ", &to_string/1)
    indented(level, "[#{list}]#{lens}")
    result
  end

  defp trace(result, :match, value, {true, level}) do
    indented(level, "▶ #{value}")
    result
  end

  defp trace(result, lens, value, {true, level}) do
    indented(level, "#{value}#{lens}")
    result
  end

  def inc({tracing, level}) do
    {tracing, level + 1}
  end

  defp indented(0, message) do
    indented(0, "⏺", message)
  end

  defp indented(level, message) do
    indented(level, "∟", message)
  end

  defp indented(level, sign, message) do
    message
    |> String.split("\n")
    |> Enum.with_index(fn line, index -> indented_line(level, sign, line, index) end)
  end

  defp indented_line(level, sign, line, 0) do
    IO.puts("#{String.duplicate(" ", level * 2)}#{sign} #{line}")
  end

  defp indented_line(level, _sign, line, _index) do
    IO.puts("#{String.duplicate(" ", level * 2)}  #{line}")
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Sequence do
  alias Enzyme.Types
  alias Enzyme.Sequence

  @spec select(Sequence.t(), Types.wrapped()) :: any()
  def select(lens, collection), do: Sequence.select(lens, collection)

  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: Sequence.transform(lens, collection, fun)
end

defimpl String.Chars, for: Enzyme.Sequence do
  def to_string(%Enzyme.Sequence{lenses: []}) do
    "[]"
  end

  def to_string(%Enzyme.Sequence{lenses: lenses}) do
    Enum.map_join(lenses, "", &String.Chars.to_string/1)
  end
end
