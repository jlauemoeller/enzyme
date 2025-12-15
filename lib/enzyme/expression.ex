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

  defimpl String.Chars, for: Enzyme.Expression do
    alias Enzyme.Expression
    alias Enzyme.IsoRef

    def to_string(%Enzyme.Expression{left: left, operator: operator, right: right}) do
      "#{format(left)} #{format(operator)} #{format(right)}"
    end

    defp format(:lt), do: "<"
    defp format(:lte), do: "<="
    defp format(:gt), do: ">"
    defp format(:gte), do: ">="
    defp format(:eq), do: "=="
    defp format(:neq), do: "!="
    defp format(:str_eq), do: "~~"
    defp format(:str_neq), do: "!~"
    defp format(:and), do: "and"
    defp format(:or), do: "or"
    defp format(:not), do: "not"
    defp format(%Expression{} = expr), do: "(#{String.Chars.to_string(expr)})"
    defp format(nil), do: "NIL"
    defp format({:field, names}), do: ".#{format_field_chain(names)}"

    defp format({:field_with_isos, names, isos}),
      do: ".#{format_field_chain(names)}::#{format_isos(isos)}"

    defp format({:self_with_isos, isos}), do: "@::#{format_isos(isos)}"

    defp format({:literal_with_isos, literal, isos}),
      do: "#{inspect(literal)}::#{format_isos(isos)}"

    defp format({:literal, value}), do: "#{value}"
    defp format({:self}), do: "@"
    defp format(value) when is_binary(value), do: value
    defp format(value) when is_atom(value), do: ":#{value}"

    defp format_isos(isos) when is_list(isos) do
      Enum.map_join(isos, "::", &format_iso/1)
    end

    defp format_iso(%IsoRef{name: name}), do: name

    defp format_field_chain(names) when is_list(names) do
      Enum.map_join(names, "", fn
        name when is_atom(name) -> ":#{name}"
        name when is_binary(name) -> ".#{name}"
      end)
    end
  end
end
