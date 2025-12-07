defmodule Enzyme.Sequence do
  @moduledoc """
  A lens that applies multiple lenses in sequence.

  The `opts` field stores parse-time iso definitions that serve as defaults
  when resolving iso references at runtime.
  """

  defstruct lenses: [], opts: []

  alias Enzyme.Protocol
  alias Enzyme.Sequence

  import Enzyme.Guards
  import Enzyme.Wraps

  @type collection :: list() | map() | tuple()

  @type t :: %__MODULE__{
          lenses: list(any()),
          opts: list({atom(), any()})
        }

  @doc """
  Selects elements from a collection by applying each lens in sequence.
  """
  @spec select(t(), collection()) :: any()
  def select(%Sequence{lenses: lenses}, collection) when is_collection(collection) do
    select_next(collection, lenses)
  end

  @doc """
  Transforms elements in a collection by applying each lens in sequence.
  """

  @spec transform(t(), collection(), (any() -> any())) :: any()
  def transform(%Sequence{lenses: lenses}, collection, transform)
      when is_collection(collection) and is_transform(transform) do
    transform_next(collection, lenses, transform)
  end

  defp select_next(collection, []), do: collection

  defp select_next(collection, [next | rest]) do
    Protocol.select(next, collection) |> select_next(rest)
  end

  defp transform_next(nil, _, _), do: nil

  defp transform_next(collection, [], transform) do
    transform.(collection)
  end

  defp transform_next(collection, [lens], transform) do
    Protocol.transform(lens, collection, transform) |> unwrap()
  end

  defp transform_next(collection, [next | rest], transform) do
    result =
      Protocol.transform(next, collection, fn item ->
        transform_next(item, rest, transform)
      end)

    result |> unwrap()
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Sequence do
  def select(lens, collection), do: Enzyme.Sequence.select(lens, collection)
  def transform(lens, collection, fun), do: Enzyme.Sequence.transform(lens, collection, fun)
end
