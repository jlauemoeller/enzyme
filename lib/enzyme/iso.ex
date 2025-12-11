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
  alias Enzyme.Many
  alias Enzyme.None
  alias Enzyme.Single
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
  Selects values through the forward function of the isomorphism.

  - For `%Enzyme.Single{value: value}`, it applies the `forward` function to `value`
    and returns a new `%Enzyme.Single{}` with the transformed value.

  - For `%Enzyme.Many{values: list}`, it applies the `forward` function to each
    item's value and returns a new `%Enzyme.Many{}` with the transformed values.
  """

  @spec select(Iso.t(), Types.wrapped()) :: Types.wrapped()

  def select(%Iso{}, %None{} = none) do
    none
  end

  def select(%Iso{} = iso, %Single{value: value}) do
    single(iso.forward.(value))
  end

  def select(%Iso{} = iso, %Many{values: list}) when is_list(list) do
    many(Enum.map(list, fn item -> select(iso, item) end))
  end

  def select(%Iso{}, invalid) do
    raise ArgumentError,
          "#{__MODULE__}.select/2 expected a wrapped value, got: #{inspect(invalid)}"
  end

  @doc """
  Transforms by applying forward, the transform function, then backward, and then
  returning the wrapped result.

  - For `%Enzyme.Single{value: value}`, it applies the `forward` function to `value`,
    then the `fun`, then the `backward` function, and returns a new
    `%Enzyme.Single{}` with the transformed value.

  - For `%Enzyme.Many{values: list}`, it applies the `forward` function to each
    item's value, then the `fun`, then the `backward` function, and returns a new
    `%Enzyme.Many{}` with the transformed values.
  """

  @spec transform(Iso.t(), Types.wrapped(), (any() -> any())) :: Types.wrapped()

  def transform(%Iso{}, %None{} = none, _fun) do
    none
  end

  def transform(%Iso{} = iso, %Enzyme.Single{value: value}, fun) when is_transform(fun) do
    single(iso.backward.(fun.(iso.forward.(value))))
  end

  def transform(%Iso{} = iso, %Enzyme.Many{values: list}, fun)
      when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> transform(iso, item, fun) end))
  end

  def transform(%Iso{}, invalid, fun) when is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a wrapped value, got: #{inspect(invalid)}"
  end

  def transform(%Iso{}, wrapped, fun)
      when is_wrapped(wrapped) and not is_transform(fun) do
    raise ArgumentError,
          "#{__MODULE__}.transform/3 expected a transformation function of arity 1, got: #{inspect(fun)}"
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Iso do
  alias Enzyme.Types
  alias Enzyme.Iso

  @spec select(Iso.t(), Types.wrapped()) :: any()
  def select(lens, collection), do: Iso.select(lens, collection)

  @spec transform(Iso.t(), Types.wrapped(), (any() -> any())) :: any()
  def transform(lens, collection, fun), do: Iso.transform(lens, collection, fun)
end

defimpl String.Chars, for: Enzyme.Iso do
  def to_string(%Enzyme.Iso{}), do: "::iso"
end
