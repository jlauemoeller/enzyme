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
  alias Enzyme.None
  alias Enzyme.Single
  alias Enzyme.Types

  @type t :: %Filter{
          predicate: (any() -> boolean()),
          expression: Expression.t() | nil
        }

  @doc """
  Selects elements based on a predicate function.

  - For `%Enzyme.Single{value: value}`, it returns `%Enzyme.Single{value: value}`
    if the predicate returns true, otherwise returns %Enzyme.None{}.

  - For `%Enzyme.Many{values: list}`, returns an `Enzyme.Many{}` containing only
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
  iex> Enzyme.Filter.select(lens, %Enzyme.Many{values: [%Enzyme.Single{value: 10}, %Enzyme.Single{value: 20}, %Enzyme.Single{value: 30}]})
  %Enzyme.Many{values: [%Enzyme.Single{value: 20}, %Enzyme.Single{value: 30}]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 100 end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Many{values: [%Enzyme.Single{value: 10}, %Enzyme.Single{value: 20}, %Enzyme.Single{value: 30}]})
  %Enzyme.Many{values: []}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> x > 15 end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Single{value: {10, 20, 30}})
  %Enzyme.Many{values: [%Enzyme.Single{value: 20}, %Enzyme.Single{value: 30}]}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn %{active: a} -> a end}
  iex> Enzyme.Filter.select(lens, %Enzyme.Many{values: [%Enzyme.Single{value: %{active: true, name: "a"}}, %Enzyme.Single{value: %{active: false, name: "b"}}]})
  %Enzyme.Many{values: [%Enzyme.Single{value: %{active: true, name: "a"}}]}
  ```
  """

  @spec select(Filter.t(), Types.wrapped()) :: Types.wrapped()

  def select(%Filter{}, %None{} = none) do
    none
  end

  def select(%Filter{predicate: pred}, %Single{value: list}) when is_list(list) do
    many(Enum.filter(list, pred) |> Enum.map(&single/1))
  end

  def select(%Filter{predicate: pred}, %Single{value: tuple}) when is_tuple(tuple) do
    many(Enum.filter(Tuple.to_list(tuple), pred) |> Enum.map(&single/1))
  end

  def select(%Filter{predicate: pred}, %Single{value: value}) do
    if pred.(value), do: single(value), else: none()
  end

  def select(%Filter{} = lens, %Many{values: list}) when is_list(list) do
    selection =
      Enum.reduce(list, [], fn item, acc ->
        case select(lens, item) do
          %None{} -> acc
          selected -> [selected | acc]
        end
      end)

    many(Enum.reverse(selection))
  end

  def select(%Filter{}, invalid) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  @doc """
  Transforms elements that match the predicate.

  - For `Enzyme.Single{value: value}`, applies the transform only if the predicate
    returns true, otherwise returns the value unchanged. Returns
    `%Enzyme.Single{value: transformed}`.

  - For `Enzyme.Many{values: list}`, applies the transform only to elements for
    which the predicate returns true; other elements remain unchanged. In this
    case the function returns `%Enzyme.Many{values: transformed_list}`. The
    length of the list remains the same.

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
  iex> lens = %Enzyme.Filter{predicate: fn x -> length(x) > 2 end}
  iex> Enzyme.Filter.transform(lens, %Enzyme.Single{value: [1, 2, 3]}, &(Enum.join(&1, ", ")))
  %Enzyme.Single{value: "1, 2, 3"}
  ```

  ```
  iex> lens = %Enzyme.Filter{predicate: fn x -> length(x) > 2 end}
  iex> Enzyme.Filter.transform(lens, %Enzyme.Many{values: [%Enzyme.Single{value: [1, 2]}, %Enzyme.Single{value: [3, 4, 5]}]}, &(Enum.join(&1, ", ")))
  %Enzyme.Many{values: [%Enzyme.Single{value: [1, 2]}, %Enzyme.Single{value: "3, 4, 5"}]}
  ```
  """

  @spec transform(Filter.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()

  def transform(%Filter{predicate: pred}, %Enzyme.Single{value: value} = wrapped, fun)
      when is_transform(fun) do
    if pred.(value), do: single(fun.(value)), else: wrapped
  end

  def transform(%Filter{} = filter, %Enzyme.Many{values: list}, fun)
      when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> transform(filter, item, fun) end))
  end

  def transform(%Filter{}, invalid, fun) when is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%Filter{}, _invalid, fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a function of arity 1, got: #{inspect(fun)}"
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Filter do
  alias Enzyme.Types
  alias Enzyme.Filter

  @spec select(Filter.t(), Types.wrapped()) :: any()
  def select(lens, collection), do: Filter.select(lens, collection)

  @spec transform(Filter.t(), Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: Filter.transform(lens, collection, fun)
end
