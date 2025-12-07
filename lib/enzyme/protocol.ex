defprotocol Enzyme.Protocol do
  @moduledoc """
  Protocol for lens operations.

  All lens types must implement `select/2` and `transform/3` to participate
  in lens composition and operations.
  """

  @doc """
  Selects elements from a collection based on the lens.

  Returns a wrapped value: `{:single, value}` or `{:many, list}`.
  """
  @spec select(t, any()) :: {:single, any()} | {:many, list()}
  def select(lens, collection)

  @doc """
  Transforms elements in a collection based on the lens.

  Returns a wrapped value: `{:single, value}` or `{:many, list}`.
  """
  @spec transform(t, any(), (any() -> any())) :: {:single, any()} | {:many, list()}
  def transform(lens, collection, fun)
end
