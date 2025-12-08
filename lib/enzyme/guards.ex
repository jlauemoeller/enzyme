defmodule Enzyme.Guards do
  @moduledoc """
  Guard clauses for type checking in the Enzyme library.
  """

  @doc """
  Returns true if the value is an Enzyme lens struct.
  """

  defguard is_lens(value)
           when is_struct(value, Enzyme.All) or
                  is_struct(value, Enzyme.Filter) or
                  is_struct(value, Enzyme.Iso) or
                  is_struct(value, Enzyme.One) or
                  is_struct(value, Enzyme.Prism) or
                  is_struct(value, Enzyme.Sequence) or
                  is_struct(value, Enzyme.Slice)

  @doc """
  Returns true if the value is a collection (map, list, or tuple).
  """

  defguard is_collection(value) when is_map(value) or is_list(value) or is_tuple(value)

  @doc """
  Returns true if the value is a valid index (integer, binary, or atom).
  """

  defguard is_index(value) when is_integer(value) or is_binary(value) or is_atom(value)

  @doc """
  Returns true if the value is a transform function (arity 1).
  """
  defguard is_transform(value) when is_function(value, 1)

  @doc false
  defguard is_wrapped(value)
           when is_struct(value, Enzyme.Single) or
                  is_struct(value, Enzyme.Many) or
                  is_struct(value, Enzyme.None)
end
