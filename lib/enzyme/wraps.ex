defmodule Enzyme.Wraps do
  @moduledoc """
  Utility functions for working with wrapped Enzyme values.

  - A %None{} struct represents the absence of a value. When passed through
    lenses, their `select/2` and `transform/3` functions return %None{}.

  - A %Single{} structs wraps a single value which, as far as the library is
    concerned, can be any Elixir value. When %Single{} structs are passed
    through lenses, their `select/2` and `transform/3` functions operate on the
    wrapped value and return a new wrapped value, which may be a %None{},
    %Single{} or %Many{} struct.

  - A %Many{} struct wraps a list of values, each of which must be a wrapped
    value. When %Many{} structs are passed through lenses, their `select/2`
    and `transform/3` functions operate on each wrapped value in the list and
    return a new %Many{} struct containing the results.

  Wrapping and unwrapping functions are provided to facilitate working with
  these structs and should be used in favor of directly constructing them. The
  functions implements uniform handling of the different wrapped types and
  semantics around "double-wrapping".
  """

  import Enzyme.Guards

  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.Single
  alias Enzyme.Types

  @doc """
  Wraps a list of values in a `%Enzyme.Many{}` struct. If the input is already
  a `%Enzyme.Many{}` struct, it is returned unchanged. The list should consist
  of wrapped values.
  """
  @spec many(list()) :: Many.t()
  def many(%Many{} = many), do: many

  def many(list) when is_list(list) do
    %Many{values: list}
  end

  @doc """
  Wraps a value in a `%Enzyme.Single{}` struct. If the input is already a
  `%Enzyme.Single{}` struct, it is returned unchanged.
  """

  @spec single(any()) :: Single.t()
  def single(%Single{} = single), do: single

  def single(value) do
    %Single{value: value}
  end

  @spec none() :: None.t()
  def none do
    %None{}
  end

  @doc """
  Unwraps a value from `%Enzyme.None{}`, `%Enzyme.Single{}` or
  `%Enzyme.Many{}` structs. Unwrapping a "naked" (unwrapped) value returns the
  value unchanged.
  """

  @spec unwrap(Types.wrapped() | any()) :: any()

  def unwrap(%None{}), do: nil

  def unwrap(%Single{value: value}), do: value

  def unwrap(%Many{values: list}) do
    Enum.map(list, &unwrap(&1))
  end

  def unwrap(naked), do: naked

  def unwrap!(wrapped) when is_wrapped(wrapped) do
    unwrap(wrapped)
  end

  def unwrap!(naked) do
    raise ArgumentError,
          "Enzyme.Wraps.unwrap!/1 expected a wrapped value, got #{inspect(naked)}"
  end

  @doc """
  Applies an operation to a tuple by converting to list, applying the operation,
  and converting back to tuple. The operation should return a wrapped result.
  """

  @spec over_tuple(tuple(), (list() -> Types.wrapped())) :: tuple()

  def over_tuple(tuple, operation) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> operation.()
    |> unwrap()
    |> List.to_tuple()
  end
end
