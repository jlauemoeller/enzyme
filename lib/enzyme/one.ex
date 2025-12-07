defmodule Enzyme.One do
  @moduledoc """
  A lens that selects a single element from a collection based on an index
  or key.
  """

  defstruct [:index]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.One

  @type t :: %__MODULE__{
          index: integer() | binary() | atom()
        }

  @doc """
  Selects a single element from a collection based on the index or key
  specified in the Enzyme. The collection can be a list, tuple, or map
  or it can be wrapped in a {:single, value} or {:many, list} tuple. In these
  cases, the selection is applied to the inner value(s) which must then be of
  the appropriate type, or have elements of the appropriate type.

  Returns a {:single, value} or {:many, list} tuple.

  ## Examples

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, {:single, [10, 20]})
  {:single, 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, {:many, [[10, 20], [30, 40]]})
  {:many, [20, 40]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, {:single, {10, 20}})
  {:single, 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, {:many, [{10, 20}, {30, 40}]})
  {:many, [20, 40]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, {10, 20})
  {:single, 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, [10, 20])
  {:single, 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: "b"}
  iex> Enzyme.One.select(lens, %{"a" => 10, "b" => 20})
  {:single, 20}
  ```
  """

  @spec select(t(), {:single, any()}) :: {:single, any()}
  def select(%One{} = lens, wrapped) when is_wrapped(wrapped) do
    select_wrapped(wrapped, &select(lens, &1))
  end

  @spec select(t(), tuple()) :: {:single, any()}
  def select(%One{index: index}, tuple)
      when is_tuple(tuple) and is_integer(index) and index < tuple_size(tuple) and index >= 0 do
    {:single, elem(tuple, index)}
  end

  def select(%One{index: index}, tuple) when is_tuple(tuple) and is_integer(index) do
    {:single, nil}
  end

  @spec select(t(), list()) :: {:single, any()}
  def select(%One{index: index}, list) when is_list(list) and is_integer(index) do
    {:single, Enum.at(list, index)}
  end

  @spec select(t(), map()) :: {:single, any()}
  def select(%One{index: key}, map) when is_map(map) do
    {:single, Map.get(map, key)}
  end

  def select(%One{index: index}, invalid) do
    raise ArgumentError,
          "Cannot select One value from #{inspect(invalid)} using index #{inspect(index)}: Not a list, tuple, or map"
  end

  @doc """
  Transforms a single element in a collection based on the index or key
  specified in the Selector. The collection can be a list, tuple, or map
  or it can be wrapped in a `{:single, value}` or `{:many, list}` tuple. In these
  cases, the transformation is applied to the inner value(s) which must then be
  of the appropriate type, or have elements of the appropriate type. If the index
  or key is not found, the collection is returned unchanged.

  ## Examples

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, {:single, [10, 20]}, &(&1 * 10))
  {:single, [10, 200]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, {:many, [[10, 20], [30, 40]]}, &(&1 * 10))
  {:many, [[10, 200], [30, 400]]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, {:single, {10, 20}}, &(&1 * 10))
  {:single, {10, 200}}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, {:many, [{10, 20}, {30, 40}]}, &(&1 * 10))
  {:many, [{10, 200}, {30, 400}]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, {10, 20}, &(&1 * 10))
  {:single, {10, 200}}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, [10, 20], &(&1 * 10))
  {:single, [10, 200]}
  ```

  ```
  iex> lens = %Enzyme.One{index: "b"}
  iex> Enzyme.One.transform(lens, %{"a" => 10, "b" => 20}, &(&1 * 10))
  {:single, %{"a" => 10, "b" => 200}}
  ```
  """

  @spec transform(t(), {:single, any()} | {:many, list()} | any(), (any() -> any())) ::
          {:single, any()} | {:many, list()}
  def transform(%One{} = lens, wrapped, fun)
      when is_wrapped(wrapped) and is_transform(fun) do
    transform_wrapped(wrapped, fun, &transform(lens, &1, &2))
  end

  @spec transform(t(), tuple(), (any() -> any())) :: {:single, tuple()}
  def transform(%One{index: index} = lens, tuple, fun)
      when is_tuple(tuple) and is_integer(index) and is_transform(fun) do
    {:single, over_tuple(tuple, &transform(lens, &1, fun))}
  end

  @spec transform(t(), list(), (any() -> any())) :: {:single, list()}
  def transform(%One{index: index}, list, fun)
      when is_list(list) and is_integer(index) and is_transform(fun) do
    {:single, List.update_at(list, index, fun)}
  end

  @spec transform(t(), map(), (any() -> any())) :: {:single, map()}
  def transform(%One{index: key}, map, fun) when is_map(map) and is_transform(fun) do
    if Map.has_key?(map, key) do
      {:single, Map.update!(map, key, fun)}
    else
      {:single, map}
    end
  end
end

defimpl Enzyme.Protocol, for: Enzyme.One do
  def select(lens, collection), do: Enzyme.One.select(lens, collection)
  def transform(lens, collection, fun), do: Enzyme.One.transform(lens, collection, fun)
end
