defmodule Enzyme.Expression do
  @moduledoc """
  Represents a parsed expression used in filter lenses.
  """

  defstruct [:left, :operator, :right]

  @type t :: %__MODULE__{
          left: any(),
          operator: atom(),
          right: any()
        }
end
