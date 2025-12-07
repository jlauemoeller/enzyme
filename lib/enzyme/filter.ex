defmodule Enzyme.Filter do
  @moduledoc """
  A lens that filters elements based on a predicate function.

  When filters contain isos that need runtime resolution, the expression
  is stored and compiled to a predicate after iso resolution.
  """

  defstruct [:predicate, :expression]

  alias Enzyme.Expression
  alias Enzyme.Filter

  import Enzyme.Guards
  import Enzyme.Wraps

  @type collection :: list() | map() | tuple()

  @type t :: %__MODULE__{
          predicate: (any() -> boolean()),
          expression: Expression.t() | nil
        }

  @doc """
  Selects elements from a collection based on the predicate function.

  For `{:single, value}`, returns the value if the predicate returns true,
  otherwise returns nil.

  For `{:many, list}`, returns only the elements for which the predicate
  returns true.

  ## Examples

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, {:single, 20})
  {:single, 20}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, {:single, 10})
  {:single, nil}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, {:many, [10, 20, 30]})
  {:many, [20, 30]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, [10, 20, 30])
  {:many, [20, 30]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, {10, 20, 30})
  {:many, {20, 30}}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn %{active: a} -> a end}
  iex> Enzyme.Filter.select(lens, {:many, [%{active: true, name: "a"}, %{active: false, name: "b"}]})
  {:many, [%{active: true, name: "a"}]}
  ```
  """

  @spec select(t(), {:single, any()}) :: {:single, any()}
  def select(%Filter{predicate: pred}, {:single, value}) do
    if pred.(value), do: {:single, value}, else: {:single, nil}
  end

  @spec select(t(), {:many, collection()}) :: {:many, list()}
  def select(%Filter{predicate: pred}, {:many, collection}) when is_collection(collection) do
    {:many, Enum.filter(collection, pred)}
  end

  @spec select(t(), tuple()) :: {:many, tuple()}
  def select(%Filter{} = lens, tuple) when is_tuple(tuple) do
    {:many, over_tuple(tuple, &select(lens, {:many, &1}))}
  end

  @spec select(t(), list()) :: {:many, list()}
  def select(%Filter{predicate: pred}, list) when is_list(list) do
    {:many, Enum.filter(list, pred)}
  end

  def select(%Filter{}, invalid) do
    raise ArgumentError,
          "Cannot filter #{inspect(invalid)}: Filter requires a list, tuple, or wrapped value"
  end

  @doc """
  Transforms elements in a collection that match the predicate.

  For `{:single, value}`, applies the transform only if the predicate returns true,
  otherwise returns the value unchanged.

  For `{:many, list}`, applies the transform only to elements for which the predicate
  returns true; other elements remain unchanged.

  ## Examples

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, {:single, 20}, &(&1 * 10))
  {:single, 200}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, {:single, 10}, &(&1 * 10))
  {:single, 10}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, {:many, [10, 20, 30]}, &(&1 * 10))
  {:many, [10, 200, 300]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, [10, 20, 30], &(&1 * 10))
  {:many, [10, 200, 300]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, {10, 20, 30}, &(&1 * 10))
  {:many, {10, 200, 300}}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn %{active: a} -> a end}
  iex> Enzyme.Filter.transform(lens, {:many, [%{active: true, n: 1}, %{active: false, n: 2}]}, &Map.put(&1, :n, &1.n * 10))
  {:many, [%{active: true, n: 10}, %{active: false, n: 2}]}
  ```
  """

  @spec transform(t(), {:single, any()}, (any() -> any())) :: {:single, any()}
  def transform(%Filter{predicate: pred}, {:single, value}, fun) when is_transform(fun) do
    if pred.(value), do: {:single, fun.(value)}, else: {:single, value}
  end

  @spec transform(t(), {:many, collection()}, (any() -> any())) :: {:many, list()}
  def transform(%Filter{predicate: pred}, {:many, collection}, fun)
      when is_collection(collection) and is_transform(fun) do
    {:many, conditionally_map(collection, pred, fun)}
  end

  @spec transform(t(), tuple(), (any() -> any())) :: {:many, tuple()}
  def transform(%Filter{} = lens, tuple, fun) when is_tuple(tuple) and is_transform(fun) do
    {:many, over_tuple(tuple, &transform(lens, {:many, &1}, fun))}
  end

  @spec transform(t(), list(), (any() -> any())) :: {:many, list()}
  def transform(%Filter{predicate: pred}, list, fun) when is_list(list) and is_transform(fun) do
    {:many, conditionally_map(list, pred, fun)}
  end

  @spec transform(t(), map(), (any() -> any())) :: {:single, any()}
  def transform(%Filter{predicate: pred}, map, fun) when is_map(map) and is_transform(fun) do
    if pred.(map), do: {:single, fun.(map)}, else: {:single, map}
  end

  defp conditionally_map(collection, pred, fun) do
    Enum.map(collection, fn item -> if pred.(item), do: fun.(item), else: item end)
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Filter do
  def select(lens, collection), do: Enzyme.Filter.select(lens, collection)
  def transform(lens, collection, fun), do: Enzyme.Filter.transform(lens, collection, fun)
end
