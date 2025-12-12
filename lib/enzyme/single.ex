defmodule Enzyme.Single do
  @moduledoc """
  A wrapper for a single value.
  """

  defstruct [:value]

  @type t :: %__MODULE__{
          value: any()
        }
end

defimpl String.Chars, for: Enzyme.Single do
  def to_string(%Enzyme.Single{value: value}) do
    "single(" <> String.Chars.to_string(value) <> ")"
  end
end

defimpl Inspect, for: Enzyme.Single do
  import Inspect.Algebra

  def inspect(%Enzyme.Single{value: value}, opts) do
    doc = to_doc(value, opts)
    concat(["single(", doc, ")"])
  end
end
