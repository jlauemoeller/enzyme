defmodule Enzyme.Single do
  @moduledoc """
  A wrapper for a single value.
  """

  defstruct [:value]

  @type t :: %__MODULE__{
          value: any()
        }
end
