defmodule Enzyme.IsoRef do
  @moduledoc false

  @doc """
  A reference to an iso by name, used in parsed path expressions.

  IsoRef represents an unresolved iso reference that appears in path syntax
  like `::cents` or `::integer`. At resolution time, the reference is looked
  up in opts or builtins and replaced with an actual `Enzyme.Iso` struct.

  ## Example

  When parsing `"price::cents"`, the parser creates:

      %Sequence{lenses: [
        %One{index: "price"},
        %IsoRef{name: :cents}
      ]}

  At resolution time (during select/transform), the IsoRef is replaced
  with the actual Iso from opts or builtins.
  """

  defstruct [:name]

  @type t :: %__MODULE__{name: atom()}

  @doc """
  Creates a new iso reference with the given name.

  ## Examples

      IsoRef.new(:cents)
      #=> %IsoRef{name: :cents}

  """
  @spec new(atom()) :: t()
  def new(name) when is_atom(name) do
    %__MODULE__{name: name}
  end
end
