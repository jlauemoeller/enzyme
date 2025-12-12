defmodule Enzyme.Many do
  @moduledoc """
  A wrapper for multiple values.
  """

  defstruct [:values]

  @type t :: %__MODULE__{
          values: list(any())
        }
end

defimpl String.Chars, for: Enzyme.Many do
  def to_string(%Enzyme.Many{values: values}) do
    "many(" <> Enum.map_join(values, ", ", &String.Chars.to_string/1) <> ")"
  end
end

defimpl Inspect, for: Enzyme.Many do
  import Inspect.Algebra

  def inspect(%Enzyme.Many{values: values}, opts) do
    doc = to_doc(values, opts)
    concat(["many(", doc, ")"])
  end
end
