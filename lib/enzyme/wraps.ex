defmodule Enzyme.Wraps do
  @moduledoc false

  import Enzyme.Guards

  @doc """
  Unwraps a value from {:single, value} or {:many, list} tuples, or recursively
  unwraps lists of such values.
  """

  @spec unwrap(list()) :: list()
  def unwrap(list) when is_list(list) do
    Enum.map(list, &unwrap(&1))
  end

  @spec unwrap({:single, any()}) :: any()
  def unwrap({:single, value}), do: value

  @spec unwrap({:many, list()}) :: list()
  def unwrap({:many, list}), do: list

  @spec unwrap(any()) :: any()
  def unwrap(naked), do: naked

  @doc """
  Applies a select function to a wrapped value, handling {:single, _} and {:many, _} uniformly.
  The select_fn should accept the unwrapped value and return a wrapped result.
  """

  @spec select_wrapped({:single, any()}, (any() -> {:single, any()} | {:many, list()})) ::
          {:single, any()} | {:many, list()}
  def select_wrapped({:single, value}, select_fn) do
    select_fn.(value)
  end

  @spec select_wrapped({:many, list()}, (any() -> {:single, any()} | {:many, list()})) ::
          {:many, list()}
  def select_wrapped({:many, collection}, select_fn) when is_collection(collection) do
    {:many, Enum.map(collection, fn item -> unwrap(select_fn.(item)) end)}
  end

  @doc """
  Applies a transform function to a wrapped value, handling {:single, _} and {:many, _} uniformly.
  The transform_fn should accept the unwrapped value and transform function, returning a wrapped result.
  """

  @spec transform_wrapped(
          {:single, any()} | {:many, list()},
          (any() -> any()),
          (any(), (any() -> any()) -> {:single, any()} | {:many, list()})
        ) :: {:single, any()} | {:many, list()}
  def transform_wrapped({:single, value}, fun, transform_fn) when is_transform(fun) do
    transform_fn.(value, fun)
  end

  @spec transform_wrapped(
          {:single, any()} | {:many, list()},
          (any() -> any()),
          (any(), (any() -> any()) -> {:single, any()} | {:many, list()})
        ) :: {:many, list()}
  def transform_wrapped({:many, collection}, fun, transform_fn)
      when is_collection(collection) and is_transform(fun) do
    {:many, Enum.map(collection, fn item -> unwrap(transform_fn.(item, fun)) end)}
  end

  @doc """
  Applies an operation to a tuple by converting to list, applying the operation,
  and converting back to tuple. The operation should return a wrapped result.
  """
  @spec over_tuple(tuple(), (list() -> {:many, list()})) :: {:many, tuple()}
  def over_tuple(tuple, operation) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> operation.()
    |> unwrap()
    |> List.to_tuple()
  end
end
