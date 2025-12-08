defmodule Enzyme.Iso do
  @moduledoc """
  An isomorphism lens for bidirectional value transformations.

  Isos allow you to view and transform data through a conversion layer.
  The `forward` function converts from the stored representation to a
  working representation, and the `backward` function converts back.

  ## Path Syntax

  Use `::` to reference an iso by name in path expressions:

      # Using a builtin iso
      Enzyme.select(%{"count" => "42"}, "count::integer")
      # => 42

      # Using a custom iso
      cents_iso = Enzyme.Iso.new(&(&1 / 100), &(trunc(&1 * 100)))
      Enzyme.select(%{"price" => 1999}, "price::cents", cents: cents_iso)
      # => 19.99

  ## Resolution Priority

  Isos are resolved in this order (highest to lowest priority):

  1. Runtime opts passed to `Enzyme.select/3` or `Enzyme.transform/4`
  2. Compile-time opts passed to `Enzyme.new/2`
  3. Built-in isos (see `Enzyme.Iso.Builtins`)

  ## Examples

      # Define a custom iso
      celsius_fahrenheit = Enzyme.Iso.new(
        fn c -> c * 9/5 + 32 end,   # celsius to fahrenheit
        fn f -> (f - 32) * 5/9 end  # fahrenheit to celsius
      )

      # Data stored in Celsius
      data = %{"temp" => 20}

      # Select returns Fahrenheit
      Enzyme.select(data, "temp::celsius_fahrenheit",
        celsius_fahrenheit: celsius_fahrenheit)
      # => 68.0

      # Transform works in Fahrenheit, stores in Celsius
      Enzyme.transform(data, "temp::celsius_fahrenheit", &(&1 + 10),
        celsius_fahrenheit: celsius_fahrenheit)
      # => %{"temp" => 25.555...}

  ## Chaining Isos

  Multiple isos can be chained:

      # Data is base64-encoded JSON
      data = %{"config" => Base.encode64(~s({"debug": true}))}

      Enzyme.select(data, "config::base64::json")
      # => %{"debug" => true}

  """

  defstruct [:forward, :backward]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Iso
  alias Enzyme.Types

  @type t :: %Iso{
          forward: (any() -> any()),
          backward: (any() -> any())
        }

  @doc """
  Creates a new iso with bidirectional functions.

  ## Parameters

  - `forward` - Function converting from stored to working representation
  - `backward` - Function converting from working back to stored representation

  ## Examples

      Enzyme.Iso.new(
        fn cents -> cents / 100 end,
        fn dollars -> trunc(dollars * 100) end)

  """

  @spec new((any() -> any()), (any() -> any())) :: Iso.t()
  def new(forward, backward)
      when is_function(forward, 1) and is_function(backward, 1) do
    %Iso{forward: forward, backward: backward}
  end

  @doc """
  Selects by applying the forward transformation.
  """

  @spec select(Iso.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()

  def select(%Iso{} = iso, %Enzyme.Single{value: value}) do
    select(iso, value)
  end

  def select(%Iso{} = iso, %Enzyme.Many{values: collection}) when is_list(collection) do
    many(Enum.map(collection, fn item -> unwrap(select(iso, item)) end))
  end

  def select(%Iso{forward: fwd}, value) do
    single(fwd.(value))
  end

  @doc """
  Transforms by applying forward, the transform function, then backward.
  """

  @spec transform(Iso.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()

  def transform(%Iso{} = iso, %Enzyme.Single{value: value}, fun) when is_transform(fun) do
    transform(iso, value, fun)
  end

  def transform(%Iso{} = iso, %Enzyme.Many{values: collection}, fun)
      when is_list(collection) and is_transform(fun) do
    many(Enum.map(collection, fn item -> unwrap(transform(iso, item, fun)) end))
  end

  def transform(%Iso{forward: fwd, backward: bwd}, value, fun) when is_transform(fun) do
    working = fwd.(value)
    transformed = fun.(working)
    result = bwd.(transformed)
    single(result)
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Iso do
  alias Enzyme.Types
  alias Enzyme.Iso

  @spec select(Iso.t(), Types.collection() | Types.wrapped()) :: any()
  def select(lens, collection), do: Iso.select(lens, collection)

  @spec transform(Iso.t(), Types.collection() | Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: Iso.transform(lens, collection, fun)
end
