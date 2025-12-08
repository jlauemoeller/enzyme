defmodule Enzyme.Filter do
  @moduledoc """
  A lens that filters elements based on a predicate function.

  When filters contain isos that need runtime resolution, the expression
  is stored and compiled to a predicate after iso resolution.
  """

  defstruct [:predicate, :expression]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Expression
  alias Enzyme.Filter
  alias Enzyme.Many
  alias Enzyme.Single
  alias Enzyme.Types

  @type t :: %Filter{
          predicate: (any() -> boolean()),
          expression: Expression.t() | nil
        }

  @doc """
  Selects elements from a collection based on the predicate function.

  For `%Enzyme.Single{value: value}`, it returns `%Enzyme.Single{value: value}`
  if the predicate returns true, otherwise returns %Enzyme.None{}.

  For `%Enzyme.Many{values: list}`, returns an `Enzyme.Many{} containing only
  the elements for which the predicate returns true. If no elements match,
  returns `%Enzyme.Many{values: []}`.

  ## Examples

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Single{value: 20})
  %Enzyme.Single{value: 20}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Single{value: 10})
  %Enzyme.None{}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Many{values: [10, 20, 30]})
  %Enzyme.Many{values: [20, 30]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 100 end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Many{values: [10, 20, 30]})
  %Enzyme.Many{values: []}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, [10, 20, 30])
  %Enzyme.Many{values: [20, 30]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, {10, 20, 30})
  %Enzyme.Many{values: {20, 30}}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn %{active: a} -> a end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Many{values: [%{active: true, name: "a"}, %{active: false, name: "b"}]})
  %Enzyme.Many{values: [%{active: true, name: "a"}]}
  ```
  """

  @spec select(Filter.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()

  def select(%Filter{predicate: pred}, %Single{value: value}) do
    if pred.(value), do: single(value), else: none()
  end

  def select(%Filter{predicate: pred}, %Many{values: collection})
      when is_collection(collection) do
    many(Enum.filter(collection, pred))
  end

  def select(%Filter{} = lens, tuple) when is_tuple(tuple) do
    many(over_tuple(tuple, &select(lens, many(&1))))
  end

  def select(%Filter{predicate: pred}, list) when is_list(list) do
    many(Enum.filter(list, pred))
  end

  def select(%Filter{}, invalid) do
    raise ArgumentError,
          "Cannot filter #{inspect(invalid)}: Filter requires a list, tuple, or wrapped value"
  end

  @doc """
  Transforms elements in a collection that match the predicate.

  For `Enzyme.Single{value: value}`, applies the transform only if the predicate
  returns true, otherwise returns the value unchanged.

  For `Enzyme.Many{values: list}`, applies the transform only to elements for
  which the predicate returns true; other elements remain unchanged.

  ## Examples

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, %Enzyme.Single{value: 20}, &(&1 * 10))
  %Enzyme.Single{value: 200}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, %Enzyme.Single{value: 10}, &(&1 * 10))
  %Enzyme.Single{value: 10}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, %Enzyme.Many{values: [10, 20, 30]}, &(&1 * 10))
  %Enzyme.Many{values: [10, 200, 300]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, [10, 20, 30], &(&1 * 10))
  %Enzyme.Many{values: [10, 200, 300]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.transform(lens, {10, 20, 30}, &(&1 * 10))
  %Enzyme.Many{values: {10, 200, 300}}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn %{active: a} -> a end}
  iex> Enzyme.Filter.transform(lens, %Enzyme.Many{values: [%{active: true, n: 1}, %{active: false, n: 2}]}, &Map.put(&1, :n, &1.n * 10))
  %Enzyme.Many{values: [%{active: true, n: 10}, %{active: false, n: 2}]}
  ```
  """

  @spec transform(Filter.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()

  def transform(%Filter{predicate: pred}, %Enzyme.Single{value: value}, fun)
      when is_transform(fun) do
    if pred.(value), do: single(fun.(value)), else: single(value)
  end

  def transform(%Filter{predicate: pred}, %Enzyme.Many{values: collection}, fun)
      when is_collection(collection) and is_transform(fun) do
    many(conditionally_map(collection, pred, fun))
  end

  def transform(%Filter{} = lens, tuple, fun) when is_tuple(tuple) and is_transform(fun) do
    many(over_tuple(tuple, &transform(lens, many(&1), fun)))
  end

  def transform(%Filter{predicate: pred}, list, fun) when is_list(list) and is_transform(fun) do
    many(conditionally_map(list, pred, fun))
  end

  def transform(%Filter{predicate: pred}, map, fun) when is_map(map) and is_transform(fun) do
    if pred.(map), do: single(fun.(map)), else: single(map)
  end

  defp conditionally_map(collection, pred, fun) do
    Enum.map(collection, fn item -> if pred.(item), do: fun.(item), else: item end)
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Filter do
  alias Enzyme.Types
  alias Enzyme.Filter

  @spec select(Filter.t(), Types.collection() | Types.wrapped()) :: any()
  def select(lens, collection), do: Filter.select(lens, collection)

  @spec transform(Filter.t(), Types.collection() | Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: Filter.transform(lens, collection, fun)
end
