defmodule Enzyme.Types do
  @moduledoc """
  Common types used in the Enzyme library.
  """
  @type wrapped :: Enzyme.None.t() | Enzyme.Single.t() | Enzyme.Many.t()
  @type collection :: list() | map() | tuple()
  @type tracer :: {boolean(), number(), IO.device() | nil}
end
