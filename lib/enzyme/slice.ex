defmodule Enzyme.Slice do
  @moduledoc """
  A lens that selects multiple elements from a collection based on a list of
  indices or keys.
  """

  defstruct [:indices]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Slice
  alias Enzyme.Types

  @type t :: %Slice{
          indices: list(integer() | binary() | atom())
        }

  @doc """
  Selects multiple elements from a collection based on the list of indices or
  keys specified in the Enzyme. The collection can be a list, tuple, or map
  or it can be wrapped in a `%Enzyme.Single{}` or `%Enzyme.Many{}` struct. In these
  cases, the selection is applied to the inner value(s) which must then be of
  the appropriate type, or have elements of the appropriate type.

  Returns a `%Enzyme.Many{}` struct.
  ## Examples

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.select(lens, %Enzyme.Single{value: [10, 20, 30]})
  %Enzyme.Many{values: [10, 20]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.select(lens, %Enzyme.Many{values: [[10, 20, 30], [40, 50, 60]]})
  %Enzyme.Many{values: [[10, 20], [40, 50]]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.select(lens, %Enzyme.Single{value: {10, 20, 30}})
  %Enzyme.Many{values: {10, 20}}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.select(lens, %Enzyme.Many{values: [{10, 20, 30}, {40, 50, 60}]})
  %Enzyme.Many{values: [{10, 20}, {40, 50}]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.select(lens, {10, 20, 30})
  %Enzyme.Many{values: {10, 20}}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.select(lens, [10, 20, 30])
  %Enzyme.Many{values: [10, 20]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: ["a", "b"]}
  iex> Enzyme.Slice.select(lens, %{"a" => 10, "b" => 20, "c" => 30})
  %Enzyme.Many{values: [10, 20]}
  ```
  """

  @spec select(Slice.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()

  def select(%Slice{} = lens, wrapped) when is_wrapped(wrapped) do
    select_wrapped(wrapped, &select(lens, &1))
  end

  def select(%Slice{} = lens, tuple) when is_tuple(tuple) do
    many(over_tuple(tuple, &select(lens, &1)))
  end

  def select(%Slice{indices: indices}, list)
      when is_list(list) and is_list(indices) do
    {result, _} =
      Enum.reduce(list, {[], 0}, fn element, {acc, i} ->
        if i in indices do
          {[element | acc], i + 1}
        else
          {acc, i + 1}
        end
      end)

    many(Enum.reverse(result))
  end

  def select(%Slice{indices: indices}, map) when is_map(map) and is_list(indices) do
    result =
      Enum.reduce(indices, [], fn index, acc ->
        if Map.has_key?(map, index) do
          [Map.get(map, index) | acc]
        else
          acc
        end
      end)

    many(Enum.reverse(result))
  end

  @doc """
  Transforms multiple elements in a collection based on the list of indices or
  keys specified in the Selector. The collection can be a list, tuple, or map
  or it can be wrapped in a `%Enzyme.Single{}` or `%Enzyme.Many{}` struct. In these
  cases, the transformation is applied to the inner value(s) which must then be of
  the appropriate type, or have elements of the appropriate type.

  Returns a `%Enzyme.Many{}` struct.

  ## Examples

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Many{values: [[10, 20, 30], [40, 50, 60]]}, &(&1 * 10))
  %Enzyme.Many{values: [[100, 200, 30], [400, 500, 60]]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Single{value: {10, 20, 30}}, &(&1 * 10))
  %Enzyme.Many{values: {100, 200, 30}}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Many{values: [{10, 20, 30}, {40, 50, 60}]}, &(&1 * 10))
  %Enzyme.Many{values: [{100, 200, 30}, {400, 500, 60}]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, {10, 20, 30}, &(&1 * 10))
  %Enzyme.Many{values: {100, 200, 30}}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, [10, 20, 30], &(&1 * 10))
  %Enzyme.Many{values: [100, 200, 30]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: ["a", "b"]}
  iex> Enzyme.Slice.transform(lens, %{"a" => 10, "b" => 20, "c" => 30}, &(&1 * 10))
  %Enzyme.Many{values: %{"a" => 100, "b" => 200, "c" => 30}}
  ```
  """

  @spec transform(Slice.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()

  def transform(%Slice{} = lens, wrapped, fun)
      when is_wrapped(wrapped) and is_transform(fun) do
    transform_wrapped(wrapped, fun, &transform(lens, &1, &2))
  end

  def transform(%Slice{} = lens, tuple, fun)
      when is_tuple(tuple) and is_transform(fun) do
    many(over_tuple(tuple, &transform(lens, &1, fun)))
  end

  def transform(%Slice{indices: indices}, list, fun)
      when is_list(list) and is_list(indices) and is_transform(fun) do
    {result, _} =
      Enum.reduce(list, {[], 0}, fn element, {acc, i} ->
        if i in indices do
          {[fun.(element) | acc], i + 1}
        else
          {[element | acc], i + 1}
        end
      end)

    many(Enum.reverse(result))
  end

  def transform(%Slice{indices: keys}, map, fun)
      when is_map(map) and is_transform(fun) do
    many(Map.new(map, fn {k, v} -> {k, if(k in keys, do: fun.(v), else: v)} end))
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Slice do
  alias Enzyme.Types
  alias Enzyme.Slice

  @spec select(Slice.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()
  def select(lens, collection), do: Slice.select(lens, collection)

  @spec transform(Slice.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()
  def transform(lens, collection, fun), do: Slice.transform(lens, collection, fun)
end
