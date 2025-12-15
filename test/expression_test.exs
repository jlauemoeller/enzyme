defmodule Enzyme.ExpressionTest do
  @moduledoc false

  use ExUnit.Case
  doctest Enzyme.Expression

  alias Enzyme.Expression
  alias Enzyme.ExpressionParser

  # describe "String.Chars implementation" do
  #   test "formats simple field expression" do
  #     %Expression{} = expr = ExpressionParser.parse("@.name") |> IO.inspect()
  #     assert to_string(expr) == ".:name"
  #   end
  # end
end
