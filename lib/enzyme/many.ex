defmodule Enzyme.Many do
  @moduledoc """
  A wrapper for multiple values.
  """

  defstruct [:values]

  @type t :: %__MODULE__{
          values: list(any())
        }
end
