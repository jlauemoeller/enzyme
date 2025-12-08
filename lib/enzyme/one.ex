defmodule Enzyme.One do
  @moduledoc """
  A lens that selects a single element from a collection based on an index
  or key.
  """

  defstruct [:index]

  import Enzyme.Guards
  import Enzyme.Wraps

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

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, %Enzyme.Many{values: [[10, 20], [30, 40]]})
  %Enzyme.Many{values: [20, 40]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, %Enzyme.Single{value: {10, 20}})
  %Enzyme.Single{value: 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, %Enzyme.Many{values: [{10, 20}, {30, 40}]})
  %Enzyme.Many{values: [20, 40]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, {10, 20})
  %Enzyme.Single{value: 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.select(lens, [10, 20])
  %Enzyme.Single{value: 20}
  ```

  ```
  iex> lens = %Enzyme.One{index: "b"}
  iex> Enzyme.One.select(lens, %{"a" => 10, "b" => 20})
  %Enzyme.Single{value: 20}
  ```
  """

  @spec select(One.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()

  def select(%One{} = lens, wrapped) when is_wrapped(wrapped) do
    select_wrapped(wrapped, &select(lens, &1))
  end

  def select(%One{index: index}, tuple)
      when is_tuple(tuple) and is_integer(index) and index < tuple_size(tuple) and index >= 0 do
    single(elem(tuple, index))
  end

  def select(%One{index: index}, tuple) when is_tuple(tuple) and is_integer(index) do
    none()
  end

  def select(%One{index: index}, list) when is_list(list) and is_integer(index) do
    case Enum.at(list, index, none()) do
      %None{} -> none()
      value -> single(value)
    end
  end

  def select(%One{index: index} = lens, list) when is_list(list) and not is_integer(index) do
    selection =
      Enum.reduce(list, [], fn item, acc ->
        case select(lens, item) do
          %None{} -> acc
          %Single{value: value} -> [value | acc]
        end
      end)

    many(Enum.reverse(selection))
  end

  def select(%One{index: key}, map) when is_map(map) do
    if Map.has_key?(map, key) do
      single(Map.get(map, key))
    else
      none()
    end
  end

  def select(%One{index: index}, invalid) do
    raise ArgumentError,
          "Cannot select One value from #{inspect(invalid)} using index #{inspect(index)}: Not a list, tuple, or map"
  end

  @doc """
  Transforms a single element in a collection based on the index or key
  specified in the Selector. The collection can be a list, tuple, or map
  or it can be wrapped in a `%Enzyme.Single{value: value}` or
  `%Enzyme.Many{values: list}` struct. In these cases, the transformation is
  applied to the inner value(s) which must then be of the appropriate type, or
  have elements of the appropriate type. If the index or key is not found,
  the collection is returned unchanged.

  ## Examples

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: [10, 20]}, &(&1 * 10))
  %Enzyme.Single{value: [10, 200]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Many{values: [[10, 20], [30, 40]]}, &(&1 * 10))
  %Enzyme.Many{values: [[10, 200], [30, 400]]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Single{value: {10, 20}}, &(&1 * 10))
  %Enzyme.Single{value: {10, 200}}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, %Enzyme.Many{values: [{10, 20}, {30, 40}]}, &(&1 * 10))
  %Enzyme.Many{values: [{10, 200}, {30, 400}]}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, {10, 20}, &(&1 * 10))
  %Enzyme.Single{value: {10, 200}}
  ```

  ```
  iex> lens = %Enzyme.One{index: 1}
  iex> Enzyme.One.transform(lens, [10, 20], &(&1 * 10))
  %Enzyme.Single{value: [10, 200]}
  ```

  ```
  iex> lens = %Enzyme.One{index: "b"}
  iex> Enzyme.One.transform(lens, %{"a" => 10, "b" => 20}, &(&1 * 10))
  %Enzyme.Single{value: %{"a" => 10, "b" => 200}}
  ```
  """

  @spec transform(One.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()

  def transform(%One{} = lens, wrapped, fun)
      when is_wrapped(wrapped) and is_transform(fun) do
    transform_wrapped(wrapped, fun, &transform(lens, &1, &2))
  end

  def transform(%One{index: index} = lens, tuple, fun)
      when is_tuple(tuple) and is_integer(index) and is_transform(fun) do
    single(over_tuple(tuple, &transform(lens, &1, fun)))
  end

  def transform(%One{index: index}, list, fun)
      when is_list(list) and is_integer(index) and is_transform(fun) do
    single(List.update_at(list, index, fun))
  end

  def transform(%One{index: index} = lens, list, fun)
      when is_list(list) and not is_integer(index) and is_transform(fun) do
    transformed =
      Enum.map(list, fn item ->
        transform(lens, item, fun)
      end)

    many(Enum.map(transformed, fn wrapped -> unwrap(wrapped) end))
  end

  def transform(%One{index: key}, map, fun) when is_map(map) and is_transform(fun) do
    if Map.has_key?(map, key) do
      single(Map.update!(map, key, fun))
    else
      single(map)
    end
  end
end

defimpl Enzyme.Protocol, for: Enzyme.One do
  alias Enzyme.Types
  alias Enzyme.One

  @spec select(One.t(), Types.collection() | Types.wrapped()) :: any()
  def select(lens, collection), do: One.select(lens, collection)

  @spec transform(One.t(), Types.collection() | Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: One.transform(lens, collection, fun)
end
