defmodule Enzyme.Sequence do
  @moduledoc """
  A lens that applies multiple lenses in sequence.

  The `opts` field stores parse-time iso definitions that serve as defaults
  when resolving iso references at runtime.
  """

  defstruct lenses: [], opts: []

  import Enzyme.Guards
  import Enzyme.Tracing
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

  @default_tracer {false, 0, :stdio}

  @doc """
  Selects elements from a collection of wrapped values by applying each lens in sequence. Returns
  the wrapped value selected by the last lens in the sequence.
  """

  @spec select(Sequence.t(), Types.wrapped()) :: Types.wrapped()
  @spec select(Sequence.t(), Types.wrapped(), Types.tracer()) :: Types.wrapped()

  def select(lens, data, tracer \\ @default_tracer)

  def select(%Sequence{}, %None{} = none, _tracer) do
    none
  end

  def select(%Sequence{lenses: []}, %Single{} = data, _tracer) do
    data
  end

  def select(%Sequence{} = lens, %Single{} = data, tracer) do
    select_next(data, lens.lenses, tracer)
  end

  def select(%Sequence{} = lens, %Many{values: list}, tracer) when is_list(list) do
    many(Enum.map(list, fn item -> select_next(item, lens.lenses, tracer) end))
  end

  def select(%Sequence{}, invalid, _tracer) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  @doc """
  Transforms elements in a collection by applying each lens in sequence.
  The transform function is applied to the values selected by the last lens
  in the sequence.
  """

  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()
  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any()), Types.tracer()) ::
          Types.wrapped()

  def transform(lens, data, fun, tracer \\ @default_tracer)

  def transform(%Sequence{}, %None{} = none, _transform, _tracer) do
    none
  end

  def transform(%Sequence{lenses: []}, %Single{} = data, fun, _tracer)
      when is_transform(fun) do
    single(fun.(unwrap!(data)))
  end

  def transform(%Sequence{lenses: lenses}, %Single{} = data, fun, tracer)
      when is_transform(fun) do
    transform_next(data, lenses, fun, tracer)
  end

  def transform(%Sequence{lenses: lenses}, %Many{values: list}, fun, tracer)
      when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> transform_next(item, lenses, fun, tracer) end))
  end

  def transform(%Sequence{}, invalid, fun, _tracer) when is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%Sequence{}, wrapped, fun, _tracer)
      when is_wrapped(wrapped) and not is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a transformation function of arity 1, got: #{inspect(fun)}"
  end

  defp select_next(value, [], tracer) do
    trace(:match, value, dec(tracer))
  end

  defp select_next(value, [lens | rest], tracer) do
    lens
    |> Protocol.select(value, tracer)
    |> select_next(rest, inc(tracer))
  end

  defp transform_next(data, [], fun, _tracer) do
    single(fun.(unwrap!(data)))
  end

  defp transform_next(data, [next | rest], fun, tracer) do
    continue = fn item ->
      unwrap!(transform_next(single(item), rest, fun, inc(tracer)))
    end

    Protocol.transform(next, data, continue, tracer)
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Sequence do
  alias Enzyme.Types
  alias Enzyme.Sequence

  @spec select(Sequence.t(), Types.wrapped()) :: any()
  @spec select(Sequence.t(), Types.wrapped(), Types.tracer()) :: any()
  def select(lens, collection), do: Sequence.select(lens, collection)
  def select(lens, collection, tracer), do: Sequence.select(lens, collection, tracer)

  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any())) :: any()
  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any()), Types.tracer()) :: any()
  def transform(lens, collection, fun), do: Sequence.transform(lens, collection, fun)

  def transform(lens, collection, fun, tracer),
    do: Sequence.transform(lens, collection, fun, tracer)
end

defimpl String.Chars, for: Enzyme.Sequence do
  def to_string(%Enzyme.Sequence{lenses: []}) do
    "[]"
  end

  def to_string(%Enzyme.Sequence{lenses: lenses}) do
    Enum.map_join(lenses, "", &String.Chars.to_string/1)
  end
end
