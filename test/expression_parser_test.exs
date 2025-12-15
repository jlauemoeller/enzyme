defmodule Enzyme.ExpressionParserTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.ExpressionParser

  alias Enzyme.Expression
  alias Enzyme.ExpressionParser

  @binary_operators %{
    "==" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    "!=" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    "<" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    ">" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    "<=" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    ">=" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    "~~" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    "!~" => [:boolean, :integer, :float, :string, :atom, :string_field, :atom_field],
    "and" => [:boolean, :string_field, :atom_field],
    "or" => [:boolean, :string_field, :atom_field]
  }

  @unary_operators %{
    "not" => [:boolean, :string_field, :atom_field]
  }

  Enum.each(@binary_operators, fn {operator, types} ->
    for left_type <- types do
      for right_type <- types do
        test_name = "parses #{left_type} #{operator} #{right_type}"

        test test_name do
          left_operand =
            case unquote(left_type) do
              :string_field -> "@.field"
              :atom_field -> "@:field"
              :string -> "'value'"
              :atom -> ":value"
              :boolean -> "true"
              :integer -> "42"
              :float -> "3.14"
            end

          right_operand =
            case unquote(right_type) do
              :string_field -> "@.field"
              :atom_field -> "@:field"
              :string -> "'value'"
              :atom -> ":value"
              :boolean -> "true"
              :integer -> "42"
              :float -> "3.14"
            end

          expression = "#{left_operand} #{unquote(operator)} #{right_operand}"

          expected = %Expression{
            left:
              case unquote(left_type) do
                :string_field -> {:field, "field"}
                :atom_field -> {:field, :field}
                :string -> {:literal, "value"}
                :atom -> {:literal, :value}
                :boolean -> {:literal, true}
                :integer -> {:literal, 42}
                :float -> {:literal, 3.14}
              end,
            operator:
              case unquote(operator) do
                "==" -> :eq
                "!=" -> :neq
                "<" -> :lt
                "<=" -> :lte
                ">" -> :gt
                ">=" -> :gte
                "~~" -> :str_eq
                "!~" -> :str_neq
                "and" -> :and
                "or" -> :or
              end,
            right:
              case unquote(right_type) do
                :string_field -> {:field, "field"}
                :atom_field -> {:field, :field}
                :string -> {:literal, "value"}
                :atom -> {:literal, :value}
                :boolean -> {:literal, true}
                :integer -> {:literal, 42}
                :float -> {:literal, 3.14}
              end
          }

          assert ExpressionParser.parse(expression) == expected,
                 "Failed to parse expression: #{expression}"
        end
      end
    end
  end)

  Enum.each(@unary_operators, fn {operator, types} ->
    for operand_type <- types do
      test_name = "parses #{operator} #{operand_type}"

      test test_name do
        operand =
          case unquote(operand_type) do
            :string_field -> "@.field"
            :atom_field -> "@:field"
            :string -> "'value'"
            :atom -> ":value"
            :boolean -> "true"
            :integer -> "42"
            :float -> "3.14"
          end

        expression = "#{unquote(operator)} #{operand}"

        expected = %Expression{
          left: nil,
          operator:
            case unquote(operator) do
              "not" -> :not
            end,
          right:
            case unquote(operand_type) do
              :string_field -> {:field, "field"}
              :atom_field -> {:field, :field}
              :string -> {:literal, "value"}
              :atom -> {:literal, :value}
              :boolean -> {:literal, true}
              :integer -> {:literal, 42}
              :float -> {:literal, 3.14}
            end
        }

        assert ExpressionParser.parse(expression) == expected
      end
    end
  end)

  describe "parse/1 syntax error cases" do
    test "raises on invalid operator" do
      assert_raise RuntimeError, ~r/Unexpected characters after expression/, fn ->
        ExpressionParser.parse("@.field & 10")
      end
    end

    test "raises on unterminated string" do
      assert_raise RuntimeError, ~r/Unterminated string/, fn ->
        ExpressionParser.parse("@.field == 'value")
      end
    end

    test "raises on right unterminated string" do
      assert_raise RuntimeError, ~r/Unterminated string/, fn ->
        ExpressionParser.parse("'value == @.field")
      end
    end

    test "raises on left unterminated string" do
      assert_raise RuntimeError, ~r/Unterminated string/, fn ->
        ExpressionParser.parse("@.value == 'field")
      end
    end
  end

  describe "compile/1 and predicate evaluation" do
    test "string field equality with string value" do
      expr = ExpressionParser.parse("@.name == 'test'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"name" => "test"}) == true
      assert pred.(%{name: "other"}) == false
      assert pred.(%{name: "test"}) == false
    end

    test "atom field equality with string value" do
      expr = ExpressionParser.parse("@:name == 'test'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{name: "test"}) == true
      assert pred.(%{name: "other"}) == false
      assert pred.(%{"name" => "test"}) == false
    end

    test "string field equality with integer value" do
      expr = ExpressionParser.parse("@.count == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"count" => 42}) == true
      assert pred.(%{"count" => 41}) == false
    end

    test "atom field equality with integer value" do
      expr = ExpressionParser.parse("@:count == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{count: 42}) == true
      assert pred.(%{count: 41}) == false
    end

    test "string field equality with boolean value" do
      expr = ExpressionParser.parse("@.active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"active" => true}) == true
      assert pred.(%{"active" => false}) == false
    end

    test "atom field equality with boolean value" do
      expr = ExpressionParser.parse("@:active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}) == true
      assert pred.(%{active: false}) == false
    end

    test "string field equality with atom value" do
      expr = ExpressionParser.parse("@.status == :pending")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"status" => :pending}) == true
      assert pred.(%{"status" => :complete}) == false
    end

    test "atom field equality with atom value" do
      expr = ExpressionParser.parse("@:status == :pending")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{status: :pending}) == true
      assert pred.(%{status: :complete}) == false
    end

    test "@ (self) equality" do
      expr = ExpressionParser.parse("@ == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(42) == true
      assert pred.(41) == false
    end

    test "@ (self) with string comparison" do
      expr = ExpressionParser.parse("@ == 'hello'")
      pred = ExpressionParser.compile(expr)

      assert pred.("hello") == true
      assert pred.("world") == false
    end

    test "string field inequality operator" do
      expr = ExpressionParser.parse("@.status != 'closed'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"status" => "open"}) == true
      assert pred.(%{"status" => "closed"}) == false
    end

    test "atom field inequality operator" do
      expr = ExpressionParser.parse("@:status != 'closed'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{status: "open"}) == true
      assert pred.(%{status: "closed"}) == false
    end

    test "string field string equality operator converts to string" do
      expr = ExpressionParser.parse("@.value ~~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"value" => 42}) == true
      assert pred.(%{"value" => "42"}) == true
      assert pred.(%{"value" => 41}) == false
    end

    test "atom field string equality operator converts to string" do
      expr = ExpressionParser.parse("@:value ~~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{value: 42}) == true
      assert pred.(%{value: "42"}) == true
      assert pred.(%{value: 41}) == false
    end

    test "string field string inequality operator converts to string" do
      expr = ExpressionParser.parse("@.value !~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"value" => 42}) == false
      assert pred.(%{"value" => 41}) == true
    end

    test "atom field string inequality operator converts to string" do
      expr = ExpressionParser.parse("@:value !~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{value: 42}) == false
      assert pred.(%{value: 41}) == true
    end

    test "missing string field returns nil" do
      expr = ExpressionParser.parse("@.missing == nil")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"other" => "value"}) == true
    end

    test "missing atom field returns nil" do
      expr = ExpressionParser.parse("@:missing == nil")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{other: "value"}) == true
    end
  end

  describe "logical operators" do
    test "parses and evaluates 'and' operator" do
      expr = ExpressionParser.parse("@:active == true and @:role == 'admin'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true, role: "admin"}) == true
      assert pred.(%{active: true, role: "user"}) == false
      assert pred.(%{active: false, role: "admin"}) == false
      assert pred.(%{active: false, role: "user"}) == false
    end

    test "parses and evaluates 'or' operator" do
      expr = ExpressionParser.parse("@:role == 'admin' or @:role == 'superuser'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{role: "admin"}) == true
      assert pred.(%{role: "superuser"}) == true
      assert pred.(%{role: "user"}) == false
    end

    test "parses and evaluates 'not' operator" do
      expr = ExpressionParser.parse("not @:active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}) == false
      assert pred.(%{active: false}) == true
    end

    test "parses chained 'and' operators (left associative)" do
      expr = ExpressionParser.parse("@:a == 1 and @:b == 2 and @:c == 3")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 2, c: 3}) == true
      assert pred.(%{a: 1, b: 2, c: 4}) == false
      assert pred.(%{a: 0, b: 2, c: 3}) == false
    end

    test "parses chained 'or' operators (left associative)" do
      expr = ExpressionParser.parse("@:a == 1 or @:b == 2 or @:c == 3")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 0, c: 0}) == true
      assert pred.(%{a: 0, b: 2, c: 0}) == true
      assert pred.(%{a: 0, b: 0, c: 3}) == true
      assert pred.(%{a: 0, b: 0, c: 0}) == false
    end

    test "'and' has higher precedence than 'or'" do
      # a or (b and c)
      expr = ExpressionParser.parse("@:a == 1 or @:b == 2 and @:c == 3")
      pred = ExpressionParser.compile(expr)

      # a=1 makes whole expression true regardless of b and c
      assert pred.(%{a: 1, b: 0, c: 0}) == true

      # a!=1, but b=2 and c=3 makes it true
      assert pred.(%{a: 0, b: 2, c: 3}) == true

      # a!=1, and b=2 but c!=3 makes it false
      assert pred.(%{a: 0, b: 2, c: 0}) == false
    end

    test "'not' has higher precedence than 'and'" do
      # (not a) and b
      expr = ExpressionParser.parse("not @:a == true and @:b == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: false, b: true}) == true
      assert pred.(%{a: true, b: true}) == false
      assert pred.(%{a: false, b: false}) == false
    end

    test "double not" do
      expr = ExpressionParser.parse("not not @:active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}) == true
      assert pred.(%{active: false}) == false
    end
  end

  describe "parentheses grouping" do
    test "parentheses override default precedence" do
      # Without parens: a or (b and c)
      # With parens: (a or b) and c
      expr = ExpressionParser.parse("(@:a == 1 or @:b == 2) and @:c == 3")
      pred = ExpressionParser.compile(expr)

      # a=1 but c!=3 -> false (parens make 'or' evaluate first, then 'and' with c)
      assert pred.(%{a: 1, b: 0, c: 0}) == false

      # a=1 and c=3 -> true
      assert pred.(%{a: 1, b: 0, c: 3}) == true

      # b=2 and c=3 -> true
      assert pred.(%{a: 0, b: 2, c: 3}) == true
    end

    test "nested parentheses" do
      expr = ExpressionParser.parse("((@:a == 1 or @:b == 2) and @:c == 3)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 0, c: 3}) == true
      assert pred.(%{a: 1, b: 0, c: 0}) == false
    end

    test "parentheses with not" do
      # not (a or b) -- true only when both are false
      expr = ExpressionParser.parse("not (@:a == true or @:b == true)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: false, b: false}) == true
      assert pred.(%{a: true, b: false}) == false
      assert pred.(%{a: false, b: true}) == false
      assert pred.(%{a: true, b: true}) == false
    end

    test "complex expression with multiple levels" do
      expr = ExpressionParser.parse("(@:a == 1 and @:b == 2) or (@:c == 3 and @:d == 4)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 2, c: 0, d: 0}) == true
      assert pred.(%{a: 0, b: 0, c: 3, d: 4}) == true
      assert pred.(%{a: 1, b: 0, c: 3, d: 0}) == false
    end

    test "raises on unclosed parenthesis" do
      assert_raise RuntimeError, ~r/Expected closing '\)'/, fn ->
        ExpressionParser.parse("(@:a == 1 and @:b == 2")
      end
    end
  end

  describe "logical operators with comparison operators" do
    test "works with all comparison operators" do
      expr = ExpressionParser.parse("@:count > 5 and @:count < 10")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{count: 7}) == true
      assert pred.(%{count: 5}) == false
      assert pred.(%{count: 10}) == false
    end

    test "complex filter expression" do
      expr = ExpressionParser.parse("@:active == true and (@:score >= 80 or @:role == 'admin')")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true, score: 90, role: "user"}) == true
      assert pred.(%{active: true, score: 70, role: "admin"}) == true
      assert pred.(%{active: true, score: 70, role: "user"}) == false
      assert pred.(%{active: false, score: 90, role: "admin"}) == false
    end
  end
end
