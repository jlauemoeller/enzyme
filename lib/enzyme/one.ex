defmodule Enzyme.One do
  @moduledoc """
  A lens that selects a single element from a collection based on an index
  or key.
  """

  defstruct [:index]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.One
  alias Enzyme.Single
  alias Enzyme.Types

  @type t :: %One{
          index: integer() | binary() | atom()
        }

  @doc """
  Selects a single element from a collection based on the index or key
  specified in the Enzyme. The collection can be a list, tuple, or map
  or it can be wrapped in a %Enzyme.Single{} or %Enzyme.Many{} struct. In these
  cases, the selection is applied to the inner value(s) which must then be of
  the appropriate type, or have elements of the appropriate type.

  Returns a %Enzyme.Single{} or %Enzyme.Many{} struct.

  ## Examples

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, %Enzyme.Single{value: [10, 20]})
  %Enzyme.Single{value: 20}
  ```
  """

  @spec select(One.t(), Types.wrapped()) :: Types.wrapped()

  def select(%One{}, %None{} = none) do
    none
  end

  def select(%One{index: index}, %Single{value: list})
      when is_integer(index) and is_list(list) do
    case Enum.at(list, index, none()) do
      %None{} -> none()
      value -> single(value)
    end
  end

  def select(%One{index: index}, %Single{value: list})
      when is_atom(index) and is_list(list) do
    case Keyword.get(list, index, none()) do
      %None{} -> none()
      value -> single(value)
    end
  end

  def select(%One{index: index}, %Single{value: tuple})
      when is_integer(index) and is_tuple(tuple) do
    if index < tuple_size(tuple) and index >= 0 do
      single(elem(tuple, index))
    else
      none()
    end
  end

  def select(%One{index: index}, %Single{value: map}) when is_map(map) do
    if Map.has_key?(map, index) do
      single(Map.get(map, index))
    else
      none()
    end
  end

  def select(%One{}, %Single{}) do
    none()
  end

  def select(%One{} = lens, %Many{values: list}) when is_list(list) do
    result =
      Enum.reduce(list, [], fn item, acc ->
        case select(lens, item) do
          %None{} -> acc
          selected -> [selected | acc]
        end
      end)

    many(Enum.reverse(result))
  end

  def select(%One{}, invalid) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  @doc """
  Transforms a single element in a collection based on an index or key.

  - For `%Enzyme.Single{value: value}`, applies the transform to the element
    at the specified index or key, returning a `%Enzyme.Single{value: transformed}`.
    Here `value` must be a list, tuple, or map.

  - For `%Enzyme.Many{values: list}`, applies the transform to the element at the
    specified index or key in each item of the list, returning a
    `%Enzyme.Many{values: transformed_list}`. Here each item in `list` must be a
    wrapped value that %One{} can operate on.

  ## Examples

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: [10, 20]}, &(&1 * 10))
  %Enzyme.Single{value: [10, 200]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Many{values: [%Enzyme.Single{value: [10, 20]}, %Enzyme.Single{value: [30, 40]}]}, &(&1 * 10))
  %Enzyme.Many{values: [%Enzyme.Single{value: [10, 200]}, %Enzyme.Single{value: [30, 400]}]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: {10, 20}}, &(&1 * 10))
  %Enzyme.Single{value: {10, 200}}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Many{values: [%Enzyme.Single{value: {10, 20}}, %Enzyme.Single{value: {30, 40}}]}, &(&1 * 10))
  %Enzyme.Many{values: [%Enzyme.Single{value: {10, 200}}, %Enzyme.Single{value: {30, 400}}]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: {10, 20}}, &(&1 * 10))
  %Enzyme.Single{value: {10, 200}}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: [10, 20]}, &(&1 * 10))
  %Enzyme.Single{value: [10, 200]}
  ```

  ```
  iex> lens = %Enzyme.One{index: "b"}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: %{"a" => 10, "b" => 20}}, &(&1 * 10))
  %Enzyme.Single{value: %{"a" => 10, "b" => 200}}
  ```
  """

  @spec transform(One.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()

  def transform(%One{}, %None{} = none, _fun) do
    none
  end

  def transform(%One{index: index}, %Single{value: tuple}, fun)
      when is_tuple(tuple) and is_integer(index) and index < tuple_size(tuple) and
             is_transform(fun) do
    tuple
    |> Tuple.to_list()
    |> List.update_at(index, fun)
    |> List.to_tuple()
    |> single()
  end

  def transform(%One{index: index}, %Single{value: tuple}, fun)
      when is_tuple(tuple) and is_integer(index) and index >= tuple_size(tuple) and
             is_transform(fun) do
    single(tuple)
  end

  def transform(%One{index: index}, %Single{value: list}, fun)
      when is_list(list) and is_integer(index) and is_transform(fun) do
    single(List.update_at(list, index, fun))
  end

  def transform(%One{index: index}, %Single{value: list}, fun)
      when is_list(list) and is_atom(index) and is_transform(fun) do
    if Keyword.has_key?(list, index) do
      single(Keyword.update!(list, index, fun))
    else
      single(list)
    end
  end

  def transform(%One{index: key}, %Single{value: map}, fun)
      when is_map(map) and is_transform(fun) do
    if Map.has_key?(map, key) do
      single(Map.update!(map, key, fun))
    else
      single(map)
    end
  end

  def transform(%One{}, %Single{} = value, fun) when is_transform(fun) do
    value
  end

  def transform(%One{} = lens, %Many{values: list}, fun)
      when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> transform(lens, item, fun) end))
  end

  def transform(%One{}, invalid, fun) when not is_wrapped(invalid) and is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%One{}, _invalid, fun) when not is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a transformation function of arity 1, got: #{inspect(fun)}"
  end
end

defimpl Enzyme.Protocol, for: Enzyme.One do
  alias Enzyme.Types
  alias Enzyme.One

  @spec select(One.t(), Types.wrapped()) :: any()
  def select(lens, collection), do: One.select(lens, collection)

  @spec transform(One.t(), Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: One.transform(lens, collection, fun)
end
