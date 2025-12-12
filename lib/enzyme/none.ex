defmodule Enzyme.None do
  @moduledoc """
  A wrapper for no value.
  """

  defstruct []

  @type t :: %__MODULE__{}
end

defimpl String.Chars, for: Enzyme.None do
  def to_string(%Enzyme.None{}), do: "none"
end

defimpl Inspect, for: Enzyme.None do
  import Inspect.Algebra

  def inspect(%Enzyme.None{}, _opts) do
    concat(["none()"])
  end
end
