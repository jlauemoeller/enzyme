defmodule Enzyme.Slice do
  @moduledoc """
  A lens that selects multiple elements from a collection based on a list of
  indices or keys.
  """

  defstruct [:indices]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.Single
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
  %Enzyme.Many{values: [%Enzyme.Single{value: 10}, %Enzyme.Single{value: 20}]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: ["a", "b"]}
  iex> Enzyme.Slice.select(lens, %Enzyme.Single{value: %{"a" => 10, "b" => 20, "c" => 30}})
  %Enzyme.Many{values: [%Enzyme.Single{value: 10}, %Enzyme.Single{value: 20}]}
  ```
  """

  @spec select(Slice.t(), Types.wrapped()) :: Types.wrapped()

  def select(%Slice{}, %None{} = none) do
    none
  end

  def select(%Slice{indices: indices}, %Single{value: list})
      when is_list(list) and is_list(indices) do
    many(pick_from_list(list, indices))
  end

  def select(%Slice{indices: indices}, %Single{value: tuple})
      when is_tuple(tuple) and is_list(indices) do
    many(pick_from_list(Tuple.to_list(tuple), indices))
  end

  def select(%Slice{indices: indices}, %Single{value: map})
      when is_map(map) and is_list(indices) do
    result =
      Enum.reduce(indices, [], fn index, acc ->
        if Map.has_key?(map, index) do
          [single(Map.get(map, index)) | acc]
        else
          acc
        end
      end)

    many(Enum.reverse(result))
  end

  def select(%Slice{} = lens, %Many{values: list}) when is_list(list) do
    selection =
      Enum.reduce(list, [], fn item, acc ->
        case select(lens, item) do
          %None{} -> acc
          selected -> [selected | acc]
        end
      end)

    many(Enum.reverse(selection))
  end

  def select(%Slice{}, invalid) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  defp pick_from_list(list, indices) do
    {result, _} =
      Enum.reduce(list, {[], 0}, fn element, {acc, i} ->
        if i in indices do
          {[single(element) | acc], i + 1}
        else
          {acc, i + 1}
        end
      end)

    Enum.reverse(result)
  end

  @doc """
  Transforms multiple elements in a collection based on the list of indices or
  keys specified.

  - For `%Enzyme.Single{}` applys the transform to the elements at the specified
    indices or keys, returning a `%Enzyme.Single{}` struct containing the results.

  - For `%Enzyme.Many{}`, applies the transform to the elements at the specified
    indices or keys for each value in the list, returning a `%Enzyme.Many{}`
    struct containing the results.

  ## Examples

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Single{value: {10, 20, 30}}, &(&1 * 10))
  %Enzyme.Single{value: {100, 200, 30}}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Many{values: [%Enzyme.Single{value: [10, 20, 30]}, %Enzyme.Single{value: [40, 50, 60]}]}, &(&1 * 10))
  %Enzyme.Many{values: [%Enzyme.Single{value: [100, 200, 30]}, %Enzyme.Single{value: [400, 500, 60]}]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Many{values: [%Enzyme.Single{value: {10, 20, 30}}, %Enzyme.Single{value: {40, 50, 60}}]}, &(&1 * 10))
  %Enzyme.Many{values: [%Enzyme.Single{value: {100, 200, 30}}, %Enzyme.Single{value: {400, 500, 60}}]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Single{value: {10, 20, 30}}, &(&1 * 10))
  %Enzyme.Single{value: {100, 200, 30}}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: [0, 1]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Single{value: [10, 20, 30]}, &(&1 * 10))
  %Enzyme.Single{value: [100, 200, 30]}
  ```

  ```
  iex> lens = %Enzyme.Slice{indices: ["a", "b"]}
  iex> Enzyme.Slice.transform(lens, %Enzyme.Single{value: %{"a" => 10, "b" => 20, "c" => 30}}, &(&1 * 10))
  %Enzyme.Single{value: %{"a" => 100, "b" => 200, "c" => 30}}
  ```
  """

  @spec transform(Slice.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()

  def transform(%Slice{}, %None{} = none, _fun) do
    none
  end

  def transform(%Slice{indices: indices}, %Single{value: list}, fun)
      when is_list(list) and is_transform(fun) do
    single(transform_list(list, indices, fun))
  end

  def transform(%Slice{indices: indices}, %Single{value: tuple}, fun)
      when is_tuple(tuple) and is_transform(fun) do
    tuple
    |> Tuple.to_list()
    |> transform_list(indices, fun)
    |> List.to_tuple()
    |> single()
  end

  def transform(%Slice{indices: keys}, %Single{value: map}, fun)
      when is_map(map) and is_transform(fun) do
    single(Map.new(map, fn {k, v} -> {k, if(k in keys, do: fun.(v), else: v)} end))
  end

  def transform(%Slice{} = lens, %Many{values: list}, fun) when is_transform(fun) do
    many(Enum.map(list, fn item -> transform(lens, item, fun) end))
  end

  def transform(%Slice{}, invalid, fun) when is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%Slice{}, wrapped, fun)
      when is_wrapped(wrapped) and not is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a transformation function of arity 1, got: #{inspect(fun)}"
  end

  defp transform_list(list, indices, fun)
       when is_list(indices) and is_list(list) and is_transform(fun) do
    {result, _} =
      Enum.reduce(list, {[], 0}, fn element, {acc, i} ->
        if i in indices do
          {[fun.(element) | acc], i + 1}
        else
          {[element | acc], i + 1}
        end
      end)

    Enum.reverse(result)
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
