defmodule Enzyme.Sequence do
  @moduledoc """
  A lens that applies multiple lenses in sequence.

  The `opts` field stores parse-time iso definitions that serve as defaults
  when resolving iso references at runtime.
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

  def select(%Sequence{}, %None{} = none) do
    none
  end

  def select(%Sequence{lenses: []}, %Single{} = data) do
    data
  end

  def select(%Sequence{lenses: lenses}, %Single{} = data) do
    select_next(data, lenses)
  end

  def select(%Sequence{lenses: lenses}, %Many{values: list}) when is_list(list) do
    many(Enum.map(list, fn item -> select_next(item, lenses) end))
  end

  def select(%Sequence{}, invalid) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  @doc """
  Transforms elements in a collection by applying each lens in sequence.
  The transform function is applied to the values selected by the last lens
  in the sequence.
  """

  @spec transform(Sequence.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()

  def transform(%Sequence{}, %None{} = none, _transform) do
    none
  end

  def transform(%Sequence{lenses: []}, %Single{} = data, fun) when is_transform(fun) do
    single(fun.(unwrap!(data)))
  end

  def transform(%Sequence{lenses: lenses}, %Single{} = data, fun)
      when is_transform(fun) do
    transform_next(data, lenses, fun)
  end

  def transform(%Sequence{lenses: lenses}, %Many{values: list}, fun)
      when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> transform_next(item, lenses, fun) end))
  end

  def transform(%Sequence{}, invalid, fun) when is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%Sequence{}, wrapped, fun)
      when is_wrapped(wrapped) and not is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a transformation function of arity 1, got: #{inspect(fun)}"
  end

  defp select_next(value, []) do
    value
  end

  defp select_next(value, [lens | rest]) do
    lens
    |> Protocol.select(value)
    |> select_next(rest)
  end

  defp transform_next(data, [], fun) do
    single(fun.(unwrap!(data)))
  end

  defp transform_next(data, [next | rest], fun) do
    Protocol.transform(next, data, fn item ->
      unwrap!(transform_next(single(item), rest, fun))
    end)
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
