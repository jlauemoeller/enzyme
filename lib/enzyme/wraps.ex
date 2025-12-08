defmodule Enzyme.Wraps do
  @moduledoc false

  import Enzyme.Guards

  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.Single
  alias Enzyme.Types

  @spec many(Types.collection()) :: Many.t()
  def many(collection) when is_collection(collection) do
    %Many{values: collection}
  end

  @spec single(any()) :: Single.t()
  def single(value) do
    %Single{value: value}
  end

  @spec none() :: None.t()
  def none do
    %None{}
  end

  @doc """
  Unwraps a value from `%Enzyme.None{}`, `%Enzyme.Single{}` or
  `%Enzyme.Many{}` structs, or recursively unwraps lists of such values.
  """

  @spec unwrap(Types.wrapped() | list()) :: any()

  def unwrap(list) when is_list(list) do
    Enum.map(list, &unwrap(&1))
  end

  def unwrap(%None{}), do: nil

  def unwrap(%Single{value: value}), do: value

  def unwrap(%Many{values: list}), do: list

  def unwrap(naked), do: naked

  @doc """
  Applies a select function to a wrapped value, handling `%Enzyme.None{}`,
  `%Enzyme.Single{}` and `%Enzyme.Many{}` uniformly. The select_fn should accept
  the unwrapped value and return a wrapped result.
  """

  @spec select_wrapped(
          Types.wrapped(),
          (any() -> Types.wrapped())
        ) :: Types.wrapped()

  def select_wrapped(%None{}, _select_fn) do
    %None{}
  end

  def select_wrapped(%Single{value: value}, select_fn) do
    select_fn.(value)
  end

  def select_wrapped(%Many{values: collection}, select_fn) when is_collection(collection) do
    selection =
      Enum.reduce(collection, [], fn item, acc ->
        case select_fn.(item) do
          %None{} -> acc
          wrapped -> [unwrap(wrapped) | acc]
        end
      end)

    many(Enum.reverse(selection))
  end

  @doc """
  Applies a transform function to a wrapped value, handling `%Enzyme.None{}`,
  `%Enzyme.Single{}`, and `%Enzyme.Many{}` uniformly. The transform_fn should
  accept the unwrapped value and transform function abd return a wrapped result.
  """

  @spec transform_wrapped(
          Types.wrapped(),
          (any() -> any()),
          (any(), (any() -> any()) -> Types.wrapped())
        ) :: Types.wrapped()

  def transform_wrapped(%None{}, _fun, _transform_fn) do
    %None{}
  end

  def transform_wrapped(%Single{value: value}, fun, transform_fn) when is_transform(fun) do
    transform_fn.(value, fun)
  end

  def transform_wrapped(%Many{values: collection}, fun, transform_fn)
      when is_collection(collection) and is_transform(fun) do
    many(Enum.map(collection, fn item -> unwrap(transform_fn.(item, fun)) end))
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
