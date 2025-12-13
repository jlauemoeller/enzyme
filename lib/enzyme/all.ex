defmodule Enzyme.All do
  @moduledoc """
  A selector that selects all elements from a collection.
  """

  defstruct []

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.All
  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.Single
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
  %Enzyme.Many{values: [%Enzyme.Single{value: 10}, %Enzyme.Single{value: 20}]}
  ```
  """

  @default_tracer {false, 0, :stdio}

  @spec select(All.t(), Types.wrapped()) :: Types.wrapped()
  @spec select(All.t(), Types.wrapped(), Types.tracer()) :: Types.wrapped()

  def select(lens, data, tracer \\ @default_tracer)

  def select(%All{}, %None{} = none, _tracer) do
    none
  end

  def select(%All{}, %Single{value: list}, _tracer) when is_list(list) do
    many(Enum.map(list, &single(&1)))
  end

  def select(%All{}, %Single{value: tuple}, _tracer) when is_tuple(tuple) do
    many(Enum.map(Tuple.to_list(tuple), &single(&1)))
  end

  def select(%All{}, %Single{value: map}, _tracer) when is_map(map) do
    many(Enum.map(Map.values(map), &single(&1)))
  end

  def select(%All{}, %Single{} = single, _tracer) do
    single
  end

  def select(%All{} = lens, %Many{values: list}, tracer) when is_list(list) do
    result =
      Enum.reduce(list, [], fn item, acc ->
        case select(lens, item, tracer) do
          %None{} ->
            acc

          %Single{} ->
            [item | acc]

          %Many{} = many ->
            Enum.reduce(many.values, acc, fn v, a -> [v | a] end)
        end
      end)

    many(Enum.reverse(result))
  end

  def select(%All{}, invalid, _tracer) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
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
  iex> Enzyme.All.transform(lens, %Enzyme.Single{value: 10}, &(&1 * 10))
  %Enzyme.Single{value: 100}
  ```

  ```
  iex> lens = %Enzyme.All{}
  iex> Enzyme.All.transform(lens, %Enzyme.Many{values: [%Enzyme.Single{value: 10}, %Enzyme.Single{value: 20}]}, &(&1 * 10))
  %Enzyme.Many{values: [%Enzyme.Single{value: 100}, %Enzyme.Single{value: 200}]}
  ```
  """

  @spec transform(All.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()
  @spec transform(All.t(), Types.wrapped(), (any() -> any()), Types.tracer()) :: Types.wrapped()

  def transform(lens, data, fun, tracer \\ @default_tracer)

  def transform(%All{}, %None{} = none, fun, _tracer) when is_transform(fun) do
    none
  end

  def transform(%All{}, %Single{value: list}, fun, _tracer)
      when is_list(list) and is_transform(fun) do
    single(Enum.map(list, fn item -> fun.(item) end))
  end

  def transform(%All{}, %Single{value: tuple}, fun, _tracer)
      when is_tuple(tuple) and is_transform(fun) do
    single(Enum.map(Tuple.to_list(tuple), fn item -> fun.(item) end))
  end

  def transform(%All{}, %Single{value: map}, fun, _tracer)
      when is_map(map) and is_transform(fun) do
    single(Map.new(map, fn {k, v} -> {k, fun.(v)} end))
  end

  def transform(%All{}, %Single{value: value}, fun, _tracer)
      when is_transform(fun) do
    single(fun.(value))
  end

  def transform(%All{}, %Many{values: list}, fun, tracer)
      when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> transform(%All{}, item, fun, tracer) end))
  end

  def transform(%All{}, invalid, fun, _tracer) when is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%All{}, _invalid, fun, _tracer) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a function of arity 1, got: #{inspect(fun)}"
  end
end

defimpl Enzyme.Protocol, for: Enzyme.All do
  alias Enzyme.Types
  alias Enzyme.All

  @spec select(All.t(), Types.wrapped()) :: any()
  @spec select(All.t(), Types.wrapped(), Types.tracer()) :: any()
  def select(lens, collection), do: All.select(lens, collection)
  def select(lens, collection, tracer), do: All.select(lens, collection, tracer)

  @spec transform(All.t(), Types.wrapped(), (any() -> any())) :: any()
  @spec transform(All.t(), Types.wrapped(), (any() -> any()), Types.tracer()) :: any()
  def transform(lens, collection, fun), do: All.transform(lens, collection, fun)
  def transform(lens, collection, fun, tracer), do: All.transform(lens, collection, fun, tracer)
end

defimpl String.Chars, for: Enzyme.All do
  def to_string(%Enzyme.All{}), do: "[*]"
end
