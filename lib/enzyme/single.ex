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
    "single(" <> inspect(value, limit: :infinity, pretty: true) <> ")"
  end
end
