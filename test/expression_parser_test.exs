defmodule Enzyme.ExpressionParserTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.ExpressionParser

  alias Enzyme.Expression
  alias Enzyme.ExpressionParser
  alias Enzyme.IsoRef

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

          op_atom =
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
            end

          # For 'and' and 'or', operands are wrapped in Expression with :get operator
          # For comparison operators, operands are raw
          wrap_for_logical = op_atom in [:and, :or]

          left_operand_value =
            case unquote(left_type) do
              :string_field -> {:field, ["field"]}
              :atom_field -> {:field, [:field]}
              :string -> {:literal, "value"}
              :atom -> {:literal, :value}
              :boolean -> {:literal, true}
              :integer -> {:literal, 42}
              :float -> {:literal, 3.14}
            end

          right_operand_value =
            case unquote(right_type) do
              :string_field -> {:field, ["field"]}
              :atom_field -> {:field, [:field]}
              :string -> {:literal, "value"}
              :atom -> {:literal, :value}
              :boolean -> {:literal, true}
              :integer -> {:literal, 42}
              :float -> {:literal, 3.14}
            end

          expected = %Expression{
            left:
              if(wrap_for_logical,
                do: %Expression{left: left_operand_value, operator: :get, right: nil},
                else: left_operand_value
              ),
            operator: op_atom,
            right:
              if(wrap_for_logical,
                do: %Expression{left: right_operand_value, operator: :get, right: nil},
                else: right_operand_value
              )
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
          right: %Expression{
            left:
              case unquote(operand_type) do
                :string_field -> {:field, ["field"]}
                :atom_field -> {:field, [:field]}
                :string -> {:literal, "value"}
                :atom -> {:literal, :value}
                :boolean -> {:literal, true}
                :integer -> {:literal, 42}
                :float -> {:literal, 3.14}
              end,
            operator: :get,
            right: nil
          }
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

      assert pred.(%{"name" => "test"}, []) == true
      assert pred.(%{name: "other"}, []) == false
      assert pred.(%{name: "test"}, []) == false
    end

    test "atom field equality with string value" do
      expr = ExpressionParser.parse("@:name == 'test'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{name: "test"}, []) == true
      assert pred.(%{name: "other"}, []) == false
      assert pred.(%{"name" => "test"}, []) == false
    end

    test "string field equality with integer value" do
      expr = ExpressionParser.parse("@.count == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"count" => 42}, []) == true
      assert pred.(%{"count" => 41}, []) == false
    end

    test "atom field equality with integer value" do
      expr = ExpressionParser.parse("@:count == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{count: 42}, []) == true
      assert pred.(%{count: 41}, []) == false
    end

    test "string field equality with boolean value" do
      expr = ExpressionParser.parse("@.active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"active" => true}, []) == true
      assert pred.(%{"active" => false}, []) == false
    end

    test "atom field equality with boolean value" do
      expr = ExpressionParser.parse("@:active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}, []) == true
      assert pred.(%{active: false}, []) == false
    end

    test "string field equality with atom value" do
      expr = ExpressionParser.parse("@.status == :pending")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"status" => :pending}, []) == true
      assert pred.(%{"status" => :complete}, []) == false
    end

    test "atom field equality with atom value" do
      expr = ExpressionParser.parse("@:status == :pending")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{status: :pending}, []) == true
      assert pred.(%{status: :complete}, []) == false
    end

    test "@ (self) equality" do
      expr = ExpressionParser.parse("@ == 42")
      pred = ExpressionParser.compile(expr)

      assert pred.(42, []) == true
      assert pred.(41, []) == false
    end

    test "@ (self) with string comparison" do
      expr = ExpressionParser.parse("@ == 'hello'")
      pred = ExpressionParser.compile(expr)

      assert pred.("hello", []) == true
      assert pred.("world", []) == false
    end

    test "string field inequality operator" do
      expr = ExpressionParser.parse("@.status != 'closed'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"status" => "open"}, []) == true
      assert pred.(%{"status" => "closed"}, []) == false
    end

    test "atom field inequality operator" do
      expr = ExpressionParser.parse("@:status != 'closed'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{status: "open"}, []) == true
      assert pred.(%{status: "closed"}, []) == false
    end

    test "string field string equality operator converts to string" do
      expr = ExpressionParser.parse("@.value ~~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"value" => 42}, []) == true
      assert pred.(%{"value" => "42"}, []) == true
      assert pred.(%{"value" => 41}, []) == false
    end

    test "atom field string equality operator converts to string" do
      expr = ExpressionParser.parse("@:value ~~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{value: 42}, []) == true
      assert pred.(%{value: "42"}, []) == true
      assert pred.(%{value: 41}, []) == false
    end

    test "string field string inequality operator converts to string" do
      expr = ExpressionParser.parse("@.value !~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"value" => 42}, []) == false
      assert pred.(%{"value" => 41}, []) == true
    end

    test "atom field string inequality operator converts to string" do
      expr = ExpressionParser.parse("@:value !~ '42'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{value: 42}, []) == false
      assert pred.(%{value: 41}, []) == true
    end

    test "missing string field returns nil" do
      expr = ExpressionParser.parse("@.missing == nil")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"other" => "value"}, []) == true
    end

    test "missing atom field returns nil" do
      expr = ExpressionParser.parse("@:missing == nil")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{other: "value"}, []) == true
    end
  end

  describe "logical operators" do
    test "parses and evaluates 'and' operator" do
      expr = ExpressionParser.parse("@:active == true and @:role == 'admin'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true, role: "admin"}, []) == true
      assert pred.(%{active: true, role: "user"}, []) == false
      assert pred.(%{active: false, role: "admin"}, []) == false
      assert pred.(%{active: false, role: "user"}, []) == false
    end

    test "parses and evaluates 'or' operator" do
      expr = ExpressionParser.parse("@:role == 'admin' or @:role == 'superuser'")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{role: "admin"}, []) == true
      assert pred.(%{role: "superuser"}, []) == true
      assert pred.(%{role: "user"}, []) == false
    end

    test "parses and evaluates 'not' operator" do
      expr = ExpressionParser.parse("not @:active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}, []) == false
      assert pred.(%{active: false}, []) == true
    end

    test "parses chained 'and' operators (left associative)" do
      expr = ExpressionParser.parse("@:a == 1 and @:b == 2 and @:c == 3")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 2, c: 3}, []) == true
      assert pred.(%{a: 1, b: 2, c: 4}, []) == false
      assert pred.(%{a: 0, b: 2, c: 3}, []) == false
    end

    test "parses chained 'or' operators (left associative)" do
      expr = ExpressionParser.parse("@:a == 1 or @:b == 2 or @:c == 3")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 0, c: 0}, []) == true
      assert pred.(%{a: 0, b: 2, c: 0}, []) == true
      assert pred.(%{a: 0, b: 0, c: 3}, []) == true
      assert pred.(%{a: 0, b: 0, c: 0}, []) == false
    end

    test "'and' has higher precedence than 'or'" do
      # a or (b and c)
      expr = ExpressionParser.parse("@:a == 1 or @:b == 2 and @:c == 3")
      pred = ExpressionParser.compile(expr)

      # a=1 makes whole expression true regardless of b and c
      assert pred.(%{a: 1, b: 0, c: 0}, []) == true

      # a!=1, but b=2 and c=3 makes it true
      assert pred.(%{a: 0, b: 2, c: 3}, []) == true

      # a!=1, and b=2 but c!=3 makes it false
      assert pred.(%{a: 0, b: 2, c: 0}, []) == false
    end

    test "'not' has higher precedence than 'and'" do
      # (not a) and b
      expr = ExpressionParser.parse("not @:a == true and @:b == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: false, b: true}, []) == true
      assert pred.(%{a: true, b: true}, []) == false
      assert pred.(%{a: false, b: false}, []) == false
    end

    test "double not" do
      expr = ExpressionParser.parse("not not @:active == true")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}, []) == true
      assert pred.(%{active: false}, []) == false
    end
  end

  describe "parentheses grouping" do
    test "parentheses override default precedence" do
      # Without parens: a or (b and c)
      # With parens: (a or b) and c
      expr = ExpressionParser.parse("(@:a == 1 or @:b == 2) and @:c == 3")
      pred = ExpressionParser.compile(expr)

      # a=1 but c!=3 -> false (parens make 'or' evaluate first, then 'and' with c)
      assert pred.(%{a: 1, b: 0, c: 0}, []) == false

      # a=1 and c=3 -> true
      assert pred.(%{a: 1, b: 0, c: 3}, []) == true

      # b=2 and c=3 -> true
      assert pred.(%{a: 0, b: 2, c: 3}, []) == true
    end

    test "nested parentheses" do
      expr = ExpressionParser.parse("((@:a == 1 or @:b == 2) and @:c == 3)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 0, c: 3}, []) == true
      assert pred.(%{a: 1, b: 0, c: 0}, []) == false
    end

    test "parentheses with not" do
      # not (a or b) -- true only when both are false
      expr = ExpressionParser.parse("not (@:a == true or @:b == true)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: false, b: false}, []) == true
      assert pred.(%{a: true, b: false}, []) == false
      assert pred.(%{a: false, b: true}, []) == false
      assert pred.(%{a: true, b: true}, []) == false
    end

    test "complex expression with multiple levels" do
      expr = ExpressionParser.parse("(@:a == 1 and @:b == 2) or (@:c == 3 and @:d == 4)")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{a: 1, b: 2, c: 0, d: 0}, []) == true
      assert pred.(%{a: 0, b: 0, c: 3, d: 4}, []) == true
      assert pred.(%{a: 1, b: 0, c: 3, d: 0}, []) == false
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

      assert pred.(%{count: 7}, []) == true
      assert pred.(%{count: 5}, []) == false
      assert pred.(%{count: 10}, []) == false
    end

    test "complex filter expression" do
      expr = ExpressionParser.parse("@:active == true and (@:score >= 80 or @:role == 'admin')")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true, score: 90, role: "user"}, []) == true
      assert pred.(%{active: true, score: 70, role: "admin"}, []) == true
      assert pred.(%{active: true, score: 70, role: "user"}, []) == false
      assert pred.(%{active: false, score: 90, role: "admin"}, []) == false
    end
  end

  describe "chained field access" do
    test "parses chained string field access" do
      expr = ExpressionParser.parse("@.user.name == 'Alice'")

      assert %Expression{
               left: {:field, ["user", "name"]},
               operator: :eq,
               right: {:literal, "Alice"}
             } = expr
    end

    test "parses chained atom field access" do
      expr = ExpressionParser.parse("@:user:profile:name == 'Bob'")

      assert %Expression{
               left: {:field, [:user, :profile, :name]},
               operator: :eq,
               right: {:literal, "Bob"}
             } = expr
    end

    test "parses mixed string and atom field chain" do
      expr = ExpressionParser.parse("@.data:user.name == 'Charlie'")

      assert %Expression{
               left: {:field, ["data", :user, "name"]},
               operator: :eq,
               right: {:literal, "Charlie"}
             } = expr
    end

    test "parses chained field access with iso" do
      expr = ExpressionParser.parse("@.user.age::integer == 30")

      assert %Expression{
               left: {:field_with_isos, ["user", "age"], [%IsoRef{name: :integer}]},
               operator: :eq,
               right: {:literal, 30}
             } = expr
    end

    test "evaluates chained string field access" do
      expr = ExpressionParser.parse("@.user.name == 'Alice'")
      pred = ExpressionParser.compile(expr)

      data = %{"user" => %{"name" => "Alice", "age" => 30}}
      assert pred.(data, []) == true

      data2 = %{"user" => %{"name" => "Bob", "age" => 25}}
      assert pred.(data2, []) == false
    end

    test "evaluates chained atom field access" do
      expr = ExpressionParser.parse("@:user:profile:name == 'Charlie'")
      pred = ExpressionParser.compile(expr)

      data = %{user: %{profile: %{name: "Charlie", verified: true}}}
      assert pred.(data, []) == true

      data2 = %{user: %{profile: %{name: "Dana", verified: false}}}
      assert pred.(data2, []) == false
    end

    test "evaluates mixed chain" do
      expr = ExpressionParser.parse("@.config:settings.debug == true")
      pred = ExpressionParser.compile(expr)

      data = %{"config" => %{settings: %{"debug" => true}}}
      assert pred.(data, []) == true

      data2 = %{"config" => %{settings: %{"debug" => false}}}
      assert pred.(data2, []) == false
    end

    test "returns nil for missing intermediate field" do
      expr = ExpressionParser.parse("@.user.profile.name == nil")
      pred = ExpressionParser.compile(expr)

      data = %{"user" => %{"age" => 30}}
      assert pred.(data, []) == true
    end

    test "returns nil for non-map intermediate value" do
      expr = ExpressionParser.parse("@.user.name.first == 'Alice'")
      pred = ExpressionParser.compile(expr)

      data = %{"user" => %{"name" => "Alice"}}
      assert pred.(data, []) == false
    end

    test "evaluates deeply nested chain" do
      expr = ExpressionParser.parse("@.a.b.c.d.e == 'value'")
      pred = ExpressionParser.compile(expr)

      data = %{
        "a" => %{
          "b" => %{
            "c" => %{
              "d" => %{
                "e" => "value"
              }
            }
          }
        }
      }

      assert pred.(data, []) == true
    end

    test "parses chained field with multiple isos" do
      expr = ExpressionParser.parse("@.data.encoded::base64::integer > 18")

      assert %Expression{
               left:
                 {:field_with_isos, ["data", "encoded"],
                  [
                    %IsoRef{name: :base64},
                    %IsoRef{name: :integer}
                  ]},
               operator: :gt,
               right: {:literal, 18}
             } = expr
    end
  end

  describe "standalone operands without operators" do
    test "parses standalone field reference" do
      expr = ExpressionParser.parse("@.field")

      assert %Expression{
               left: {:field, ["field"]},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone self reference" do
      expr = ExpressionParser.parse("@")

      assert %Expression{
               left: {:self},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone literal true" do
      expr = ExpressionParser.parse("true")

      assert %Expression{
               left: {:literal, true},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone literal false" do
      expr = ExpressionParser.parse("false")

      assert %Expression{
               left: {:literal, false},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone literal nil" do
      expr = ExpressionParser.parse("nil")

      assert %Expression{
               left: {:literal, nil},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone field with iso" do
      expr = ExpressionParser.parse("@.count::integer")

      assert %Expression{
               left: {:field_with_isos, ["count"], [%IsoRef{name: :integer}]},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone chained field" do
      expr = ExpressionParser.parse("@.user.profile.verified")

      assert %Expression{
               left: {:field, ["user", "profile", "verified"]},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone atom field" do
      expr = ExpressionParser.parse("@:field")

      assert %Expression{
               left: {:field, [:field]},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone number" do
      expr = ExpressionParser.parse("42")

      assert %Expression{
               left: {:literal, 42},
               operator: :get,
               right: nil
             } = expr
    end

    test "parses standalone string" do
      expr = ExpressionParser.parse("'hello'")

      assert %Expression{
               left: {:literal, "hello"},
               operator: :get,
               right: nil
             } = expr
    end
  end

  describe "compile and evaluate standalone operands" do
    test "evaluates truthy field values" do
      expr = ExpressionParser.parse("@.active")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"active" => true}, []) == true
      assert pred.(%{"active" => 1}, []) == true
      assert pred.(%{"active" => "yes"}, []) == true
      assert pred.(%{"active" => []}, []) == true
      assert pred.(%{"active" => %{}}, []) == true
      assert pred.(%{"active" => 0}, []) == true
    end

    test "evaluates falsy field values" do
      expr = ExpressionParser.parse("@.active")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"active" => false}, []) == false
      assert pred.(%{"active" => nil}, []) == false
      assert pred.(%{"missing" => true}, []) == false
    end

    test "evaluates self reference with truthy values" do
      expr = ExpressionParser.parse("@")
      pred = ExpressionParser.compile(expr)

      assert pred.(true, []) == true
      assert pred.(1, []) == true
      assert pred.("string", []) == true
      assert pred.([], []) == true
      assert pred.(%{}, []) == true
      assert pred.(0, []) == true
    end

    test "evaluates self reference with falsy values" do
      expr = ExpressionParser.parse("@")
      pred = ExpressionParser.compile(expr)

      assert pred.(false, []) == false
      assert pred.(nil, []) == false
    end

    test "evaluates literal true" do
      expr = ExpressionParser.parse("true")
      pred = ExpressionParser.compile(expr)

      assert pred.("anything", []) == true
      assert pred.(%{}, []) == true
      assert pred.(nil, []) == true
    end

    test "evaluates literal false" do
      expr = ExpressionParser.parse("false")
      pred = ExpressionParser.compile(expr)

      assert pred.("anything", []) == false
      assert pred.(%{}, []) == false
      assert pred.(nil, []) == false
    end

    test "evaluates literal nil" do
      expr = ExpressionParser.parse("nil")
      pred = ExpressionParser.compile(expr)

      assert pred.("anything", []) == false
      assert pred.(%{}, []) == false
      assert pred.(nil, []) == false
    end

    test "evaluates chained fields" do
      expr = ExpressionParser.parse("@.user.profile.verified")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{"user" => %{"profile" => %{"verified" => true}}}, []) == true
      assert pred.(%{"user" => %{"profile" => %{"verified" => false}}}, []) == false
      assert pred.(%{"user" => %{"profile" => %{"verified" => nil}}}, []) == false
      assert pred.(%{"user" => %{"name" => "Alice"}}, []) == false
    end

    test "evaluates atom field" do
      expr = ExpressionParser.parse("@:active")
      pred = ExpressionParser.compile(expr)

      assert pred.(%{active: true}, []) == true
      assert pred.(%{active: false}, []) == false
      assert pred.(%{active: nil}, []) == false
      assert pred.(%{other: true}, []) == false
    end

    test "evaluates numeric literal" do
      expr = ExpressionParser.parse("42")
      pred = ExpressionParser.compile(expr)

      assert pred.("anything", []) == true
    end

    test "evaluates zero literal" do
      expr = ExpressionParser.parse("0")
      pred = ExpressionParser.compile(expr)

      # In Elixir, 0 is truthy (only nil and false are falsy)
      assert pred.("anything", []) == true
    end

    test "evaluates string literal" do
      expr = ExpressionParser.parse("'hello'")
      pred = ExpressionParser.compile(expr)

      assert pred.("anything", []) == true
    end

    test "evaluates empty string literal" do
      expr = ExpressionParser.parse("''")
      pred = ExpressionParser.compile(expr)

      # In Elixir, empty string is truthy
      assert pred.("anything", []) == true
    end
  end
end
