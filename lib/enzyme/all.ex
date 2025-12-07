defmodule Enzyme.All do
  @moduledoc """
  A selector that selects all elements from a collection.
  """

  defstruct []

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.All

  @type t :: %__MODULE__{}
  @type wrapped :: {:single, any()} | {:many, list()}

  @doc """
  Selects all elements from a collection. The collection can be a list, tuple,
  or map or it can be wrapped in a `{:single, value}` or `{:many, list}` tuple.
  In these cases, the selection is applied to the inner value(s) which must then
  be of the appropriate type, or have elements of the appropriate type. NOTE -
  for Maps only values are returned, not the `{key, value}` pairs.

  Returns a `{:many, list}` tuple.

  ## Examples

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, {:single, [10, 20]})
  {:many, [10, 20]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, {:many, [[10, 20], [30, 40]]})
  {:many, [[10, 20], [30, 40]]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, {10, 20})
  {:many, {10, 20}}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, [10, 20])
  {:many, [10, 20]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.select(lens, %{"a" => 10, "b" => 20})
  {:many, [10, 20]}
  ```
  """

  @spec select(t(), wrapped()) :: wrapped()
  def select(%All{} = lens, wrapped) when is_wrapped(wrapped) do
    select_wrapped(wrapped, &select(lens, &1))
  end

  @spec select(t(), tuple()) :: {:many, tuple()}
  def select(%All{} = lens, tuple) when is_tuple(tuple) do
    {:many, over_tuple(tuple, &select(lens, &1))}
  end

  @spec select(t(), list()) :: {:many, list()}
  def select(%All{}, list) when is_list(list) do
    {:many, list}
  end

  @spec select(t(), map()) :: {:many, map()}
  def select(%All{}, map) when is_map(map) do
    {:many, Map.values(map)}
  end

  def select(%All{}, invalid) do
    raise ArgumentError,
          "Cannot select All values from #{inspect(invalid)}: Not a list, tuple, or map"
  end

  @doc """
  Transforms all elements in a collection. The collection can be a list, tuple,
  or map or it can be wrapped in a `{:single, value}` or `{:many, list}` tuple.
  In these cases, the transformation is applied to the inner value(s) which must
  then be of the appropriate type, or have elements of the appropriate type.

  Returns a `{:many, list}` tuple.

  ## Examples

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, {:single, [10, 20]}, &(&1 * 10))
  {:many, [100, 200]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, {:many, [[10, 20], [30, 40]]}, &(&1 * 10))
  {:many, [[100, 200], [300, 400]]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, {:single, {10, 20}}, &(&1 * 10))
  {:many, {100, 200}}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, {:many, [{10, 20}, {30, 40}]}, &(&1 * 10))
  {:many, [{100, 200}, {300, 400}]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, {10, 20}, &(&1 * 10))
  {:many, {100, 200}}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, [10, 20], &(&1 * 10))
  {:many, [100, 200]}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %{"a" => 10, "b" => 20}, &(&1 * 10))
  {:many, %{"a" => 100, "b" => 200}}
  ```
  """

  @spec transform(t(), wrapped(), (any() -> any())) :: wrapped()
  def transform(%All{} = lens, wrapped, fun)
      when is_wrapped(wrapped) and is_transform(fun) do
    transform_wrapped(wrapped, fun, &transform(lens, &1, &2))
  end

  @spec transform(t(), tuple(), (any() -> any())) :: {:many, tuple()}
  def transform(%All{} = lens, tuple, fun) when is_tuple(tuple) and is_transform(fun) do
    {:many, over_tuple(tuple, &transform(lens, &1, fun))}
  end

  @spec transform(t(), list(), (any() -> any())) :: {:many, list()}
  def transform(%All{}, list, fun) when is_list(list) and is_transform(fun) do
    {:many, Enum.map(list, fun)}
  end

  @spec transform(t(), map(), (any() -> any())) :: {:many, map()}
  def transform(%All{}, map, fun) when is_map(map) and is_transform(fun) do
    {:many, Map.new(map, fn {key, value} -> {key, fun.(value)} end)}
  end
end

defimpl Enzyme.Protocol, for: Enzyme.All do
  def select(lens, collection), do: Enzyme.All.select(lens, collection)
  def transform(lens, collection, fun), do: Enzyme.All.transform(lens, collection, fun)
end
