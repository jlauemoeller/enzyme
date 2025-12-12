defprotocol Enzyme.Protocol do
  @moduledoc """
  Protocol for lens operations.

  All lens types must implement `select/2` and `transform/3` to participate
  in lens composition and operations.
  """

  @doc """
  Selects elements from a collection based on the lens.

  Returns a wrapped value: `%Enzyme.Single{}` or `%Enzyme.Many{}`.
  """
  def select(lens, collection)
  def select(lens, collection, tracer)

  @doc """
  Transforms elements in a collection based on the lens.

  Returns a wrapped value: `%Enzyme.Single{}` or `%Enzyme.Many{}`.
  """
  def transform(lens, collection, fun)
  def transform(lens, collection, fun, tracer)
end
