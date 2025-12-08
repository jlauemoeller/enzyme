defmodule Enzyme.All do
  @moduledoc """
  A selector that selects all elements from a collection.
  """

  defstruct []

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.All
  alias Enzyme.Types

  @type t :: %All{}

  @doc """
  Selects all elements from a collection. The collection can be a list, tuple,
  or map or it can be wrapped in a `%Enzyme.Single{}` or `%Enzyme.Many{}` struct.
  In these cases, the selection is applied to the inner value(s) which must then
  be of the appropriate type, or have elements of the appropriate type. NOTE -
  for Maps only values are returned, not the `{key, value}` pairs.

  Returns a `%Many{}` value.

  ## Examples

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, %Enzyme.Single{value: [10, 20]})
  %Enzyme.Many{values: [10, 20]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, %Enzyme.Many{values: [[10, 20], [30, 40]]})
  %Enzyme.Many{values: [[10, 20], [30, 40]]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, {10, 20})
  %Enzyme.Many{values: {10, 20}}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, [10, 20])
  %Enzyme.Many{values: [10, 20]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, %{"a" => 10, "b" => 20})
  %Enzyme.Many{values: [10, 20]}
  ```
  """

  @spec select(All.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()

  def select(%All{} = lens, wrapped) when is_wrapped(wrapped) do
    select_wrapped(wrapped, &select(lens, &1))
  end

  def select(%All{} = lens, tuple) when is_tuple(tuple) do
    many(over_tuple(tuple, &select(lens, &1)))
  end

  def select(%All{}, list) when is_list(list) do
    many(list)
  end

  def select(%All{}, map) when is_map(map) do
    many(Map.values(map))
  end

  def select(%All{}, invalid) do
    raise ArgumentError,
          "Cannot select All values from #{inspect(invalid)}: Not a list, tuple, map, or wrapped value"
  end

  @doc """
  Transforms all elements in a collection. The collection can be a list, tuple,
  or map or it can be wrapped in a `%Single{}` or `%Many{}` struct.
  In these cases, the transformation is applied to the inner value(s) which must
  then be of the appropriate type, or have elements of the appropriate type.

  Returns a `%Many{}` value.

  ## Examples

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %Enzyme.Single{value: [10, 20]}, &(&1 * 10))
  %Enzyme.Many{values: [100, 200]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %Enzyme.Many{values: [[10, 20], [30, 40]]}, &(&1 * 10))
  %Enzyme.Many{values: [[100, 200], [300, 400]]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %Enzyme.Single{value: {10, 20}}, &(&1 * 10))
  %Enzyme.Many{values: {100, 200}}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %Enzyme.Many{values: [{10, 20}, {30, 40}]}, &(&1 * 10))
  %Enzyme.Many{values: [{100, 200}, {300, 400}]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, {10, 20}, &(&1 * 10))
  %Enzyme.Many{values: {100, 200}}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, [10, 20], &(&1 * 10))
  %Enzyme.Many{values: [100, 200]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %{"a" => 10, "b" => 20}, &(&1 * 10))
  %Enzyme.Many{values: %{"a" => 100, "b" => 200}}
  ```
  """

  @spec transform(All.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()

  def transform(%All{} = lens, wrapped, fun)
      when is_wrapped(wrapped) and is_transform(fun) do
    transform_wrapped(wrapped, fun, &transform(lens, &1, &2))
  end

  def transform(%All{} = lens, tuple, fun) when is_tuple(tuple) and is_transform(fun) do
    many(over_tuple(tuple, &transform(lens, &1, fun)))
  end

  def transform(%All{}, list, fun) when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fun))
  end

  def transform(%All{}, map, fun) when is_map(map) and is_transform(fun) do
    many(Map.new(map, fn {key, value} -> {key, fun.(value)} end))
  end
end

defimpl Enzyme.Protocol, for: Enzyme.All do
  alias Enzyme.Types
  alias Enzyme.All

  @spec select(All.t(), Types.collection() | Types.wrapped()) :: any()
  def select(lens, collection), do: All.select(lens, collection)

  @spec transform(All.t(), Types.collection() | Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: All.transform(lens, collection, fun)
end
