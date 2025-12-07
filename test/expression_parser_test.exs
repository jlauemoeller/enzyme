defmodule Enzyme.ExpressionParserTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.ExpressionParser

  alias Enzyme.Expression
  alias Enzyme.ExpressionParser

  describe "parse/1" do
    test "parses field == string literal (single quotes)" do
      assert ExpressionParser.parse("field == 'value'") == %Expression{
               left: {:field, "field"},
               operator: :eq,
               right: {:literal, "value"}
             }
    end

    test "parses field == string literal (double quotes)" do
      assert ExpressionParser.parse("field == \"value\"") == %Expression{
               left: {:field, "field"},
               operator: :eq,
               right: {:literal, "value"}
             }
    end

    test "parses @ == literal" do
      assert ExpressionParser.parse("@ == 42") == %Expression{
               left: {:self},
               operator: :eq,
               right: {:literal, 42}
             }
    end

    test "parses @.field == literal" do
      assert ExpressionParser.parse("@.name == 'test'") == %Expression{
               left: {:field, "name"},
               operator: :eq,
               right: {:literal, "test"}
             }
    end

    test "parses field == integer" do
      assert ExpressionParser.parse("count == 42") == %Expression{
               left: {:field, "count"},
               operator: :eq,
               right: {:literal, 42}
             }
    end

    test "parses field == negative integer" do
      assert ExpressionParser.parse("count == -5") == %Expression{
               left: {:field, "count"},
               operator: :eq,
               right: {:literal, -5}
             }
    end

    test "parses field == float" do
      assert ExpressionParser.parse("score == 3.14") == %Expression{
               left: {:field, "score"},
               operator: :eq,
               right: {:literal, 3.14}
             }
    end

    test "parses field == boolean true" do
      assert ExpressionParser.parse("active == true") == %Expression{
               left: {:field, "active"},
               operator: :eq,
               right: {:literal, true}
             }
    end

    test "parses field == boolean false" do
      assert ExpressionParser.parse("active == false") == %Expression{
               left: {:field, "active"},
               operator: :eq,
               right: {:literal, false}
             }
    end

    test "parses field == nil" do
      assert ExpressionParser.parse("value == nil") == %Expression{
               left: {:field, "value"},
               operator: :eq,
               right: {:literal, nil}
             }
    end

    test "parses field == atom" do
      assert ExpressionParser.parse("status == :active") == %Expression{
               left: {:field, "status"},
               operator: :eq,
               right: {:literal, :active}
             }
    end

    test "parses != operator" do
      assert ExpressionParser.parse("field != 'value'") == %Expression{
               left: {:field, "field"},
               operator: :neq,
               right: {:literal, "value"}
             }
    end

    test "parses ~~ operator" do
      assert ExpressionParser.parse("type ~~ 'Book'") == %Expression{
               left: {:field, "type"},
               operator: :str_eq,
               right: {:literal, "Book"}
             }
    end

    test "parses !~ operator" do
      assert ExpressionParser.parse("status !~ 'closed'") == %Expression{
               left: {:field, "status"},
               operator: :str_neq,
               right: {:literal, "closed"}
             }
    end

    test "parses < operator" do
      assert ExpressionParser.parse("count < 10") == %Expression{
               left: {:field, "count"},
               operator: :lt,
               right: {:literal, 10}
             }
    end

    test "parses <= operator" do
      assert ExpressionParser.parse("count <= 10") == %Expression{
               left: {:field, "count"},
               operator: :lte,
               right: {:literal, 10}
             }
    end

    test "parses > operator" do
      assert ExpressionParser.parse("count > 10") == %Expression{
               left: {:field, "count"},
               operator: :gt,
               right: {:literal, 10}
             }
    end

    test "parses >= operator" do
      assert ExpressionParser.parse("count >= 10") == %Expression{
               left: {:field, "count"},
               operator: :gte,
               right: {:literal, 10}
             }
    end

    test "handles whitespace" do
      assert ExpressionParser.parse("  field   ==   'value'  ") == %Expression{
               left: {:field, "field"},
               operator: :eq,
               right: {:literal, "value"}
             }
    end

    test "parses atom == atom" do
      assert ExpressionParser.parse(":key == :value") == %Expression{
               left: {:literal, :key},
               operator: :eq,
               right: {:literal, :value}
             }
    end

    test "raises on invalid operator" do
      assert_raise RuntimeError, ~r/Expected comparison operator/, fn ->
        ExpressionParser.parse("field & 10")
      end
    end

    test "raises on unterminated string" do
      assert_raise RuntimeError, ~r/Unterminated string/, fn ->
        ExpressionParser.parse("field == 'value")
      end
    end
  end

  describe "compile/1 and predicate evaluation" do
    test "field equality with string value" do
      expr = ExpressionParser.parse("name == 'test'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{name: "test"}) == true
      assert pred.(%{name: "other"}) == false
      assert pred.(%{"name" => "test"}) == true
    end

    test "field equality with integer value" do
      expr = ExpressionParser.parse("count == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{count: 42}) == true
      assert pred.(%{count: 41}) == false
    end

    test "field equality with boolean value" do
      expr = ExpressionParser.parse("active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}) == true
      assert pred.(%{active: false}) == false
    end

    test "field equality with atom value" do
      expr = ExpressionParser.parse("status == :pending")
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

    test "inequality operator" do
      expr = ExpressionParser.parse("status != 'closed'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{status: "open"}) == true
      assert pred.(%{status: "closed"}) == false
    end

    test "string equality operator converts to string" do
      expr = ExpressionParser.parse("value ~~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{value: 42}) == true
      assert pred.(%{value: "42"}) == true
      assert pred.(%{value: 41}) == false
    end

    test "string inequality operator converts to string" do
      expr = ExpressionParser.parse("value !~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{value: 42}) == false
      assert pred.(%{value: 41}) == true
    end

    test "missing field returns nil" do
      expr = ExpressionParser.parse("missing == nil")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{other: "value"}) == true
    end

    test "prefers atom keys over string keys" do
      expr = ExpressionParser.parse("name == 'atom_value'")
      pred = ExpressionParser.compile(expr)

      # When both exist, atom key wins
      assert pred.(%{"name" => "string_value", name: "atom_value"}) == true
    end
  end

  describe "logical operators" do
    test "parses and evaluates 'and' operator" do
      expr = ExpressionParser.parse("active == true and role == 'admin'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true, role: "admin"}) == true
      assert pred.(%{active: true, role: "user"}) == false
      assert pred.(%{active: false, role: "admin"}) == false
      assert pred.(%{active: false, role: "user"}) == false
    end

    test "parses and evaluates 'or' operator" do
      expr = ExpressionParser.parse("role == 'admin' or role == 'superuser'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{role: "admin"}) == true
      assert pred.(%{role: "superuser"}) == true
      assert pred.(%{role: "user"}) == false
    end

    test "parses and evaluates 'not' operator" do
      expr = ExpressionParser.parse("not active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}) == false
      assert pred.(%{active: false}) == true
    end

    test "parses chained 'and' operators (left associative)" do
      expr = ExpressionParser.parse("a == 1 and b == 2 and c == 3")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 2, c: 3}) == true
      assert pred.(%{a: 1, b: 2, c: 4}) == false
      assert pred.(%{a: 0, b: 2, c: 3}) == false
    end

    test "parses chained 'or' operators (left associative)" do
      expr = ExpressionParser.parse("a == 1 or b == 2 or c == 3")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 0, c: 0}) == true
      assert pred.(%{a: 0, b: 2, c: 0}) == true
      assert pred.(%{a: 0, b: 0, c: 3}) == true
      assert pred.(%{a: 0, b: 0, c: 0}) == false
    end

    test "'and' has higher precedence than 'or'" do
      # a or (b and c)
      expr = ExpressionParser.parse("a == 1 or b == 2 and c == 3")
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
      expr = ExpressionParser.parse("not a == true and b == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: false, b: true}) == true
      assert pred.(%{a: true, b: true}) == false
      assert pred.(%{a: false, b: false}) == false
    end

    test "double not" do
      expr = ExpressionParser.parse("not not active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}) == true
      assert pred.(%{active: false}) == false
    end
  end

  describe "parentheses grouping" do
    test "parentheses override default precedence" do
      # Without parens: a or (b and c)
      # With parens: (a or b) and c
      expr = ExpressionParser.parse("(a == 1 or b == 2) and c == 3")
      pred = ExpressionParser.compile(expr)

      # a=1 but c!=3 -> false (parens make 'or' evaluate first, then 'and' with c)
      assert pred.(%{a: 1, b: 0, c: 0}) == false

      # a=1 and c=3 -> true
      assert pred.(%{a: 1, b: 0, c: 3}) == true

      # b=2 and c=3 -> true
      assert pred.(%{a: 0, b: 2, c: 3}) == true
    end

    test "nested parentheses" do
      expr = ExpressionParser.parse("((a == 1 or b == 2) and c == 3)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 0, c: 3}) == true
      assert pred.(%{a: 1, b: 0, c: 0}) == false
    end

    test "parentheses with not" do
      # not (a or b) -- true only when both are false
      expr = ExpressionParser.parse("not (a == true or b == true)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: false, b: false}) == true
      assert pred.(%{a: true, b: false}) == false
      assert pred.(%{a: false, b: true}) == false
      assert pred.(%{a: true, b: true}) == false
    end

    test "complex expression with multiple levels" do
      expr = ExpressionParser.parse("(a == 1 and b == 2) or (c == 3 and d == 4)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 2, c: 0, d: 0}) == true
      assert pred.(%{a: 0, b: 0, c: 3, d: 4}) == true
      assert pred.(%{a: 1, b: 0, c: 3, d: 0}) == false
    end

    test "raises on unclosed parenthesis" do
      assert_raise RuntimeError, ~r/Expected closing '\)'/, fn ->
        ExpressionParser.parse("(a == 1 and b == 2")
      end
    end
  end

  describe "logical operators with comparison operators" do
    test "works with all comparison operators" do
      expr = ExpressionParser.parse("count > 5 and count < 10")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{count: 7}) == true
      assert pred.(%{count: 5}) == false
      assert pred.(%{count: 10}) == false
    end

    test "complex filter expression" do
      expr = ExpressionParser.parse("active == true and (score >= 80 or role == 'admin')")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true, score: 90, role: "user"}) == true
      assert pred.(%{active: true, score: 70, role: "admin"}) == true
      assert pred.(%{active: true, score: 70, role: "user"}) == false
      assert pred.(%{active: false, score: 90, role: "admin"}) == false
    end
  end
end
