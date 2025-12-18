defmodule Enzyme.FilterFunctionCallTest do
  use ExUnit.Case
  doctest Enzyme

  describe "filter with zero-arity function calls" do
    test "filter with zero-arg function returning value" do
      data = [
        %{"created" => ~D[2024-01-01]},
        %{"created" => ~D[2024-12-01]}
      ]

      result =
        Enzyme.select(
          data,
          "[*][?@.created > cutoff()]",
          cutoff: fn -> ~D[2024-06-01] end
        )

      assert length(result) == 1
      assert hd(result)["created"] == ~D[2024-12-01]
    end

    test "filter with zero-arg function in standalone position" do
      data = [
        %{"value" => 42},
        %{"value" => 7}
      ]

      result =
        Enzyme.select(
          data,
          "[*][?ready()]",
          ready: fn -> true end
        )

      assert length(result) == 2
    end
  end

  describe "filter with single-argument function calls" do
    test "filter with boolean predicate function" do
      data = [
        %{"status" => {:confirmed, "A123"}},
        %{"status" => {:pending, "B456"}},
        %{"status" => {:confirmed, "C789"}}
      ]

      confirmed? = fn
        {:confirmed, _} -> true
        _ -> false
      end

      result = Enzyme.select(data, "[*][?confirmed?(@.status)]", confirmed?: confirmed?)

      assert length(result) == 2
      assert Enum.all?(result, fn item -> elem(item["status"], 0) == :confirmed end)
    end

    test "filter with function returning comparable value" do
      data = [
        %{"value" => 42},
        %{"value" => 7},
        %{"value" => 100}
      ]

      double = fn x -> x * 2 end

      result = Enzyme.select(data, "[*][?double(@.value) > 50]", double: double)

      assert length(result) == 2
      assert Enum.all?(result, fn item -> item["value"] * 2 > 50 end)
    end
  end

  describe "filter with multi-argument function calls" do
    test "filter with two-argument function" do
      data = [
        %{"min" => 10, "max" => 20},
        %{"min" => 30, "max" => 25},
        %{"min" => 5, "max" => 15}
      ]

      valid_range? = fn min, max -> min < max end

      result =
        Enzyme.select(
          data,
          "[*][?valid_range?(@.min, @.max)]",
          valid_range?: valid_range?
        )

      assert length(result) == 2
    end

    test "filter with three-argument function" do
      data = [
        %{"value" => 5},
        %{"value" => 50},
        %{"value" => 150}
      ]

      in_range? = fn value, min, max -> value >= min and value <= max end

      result =
        Enzyme.select(
          data,
          "[*][?in_range?(@.value, 0, 100)]",
          in_range?: in_range?
        )

      assert length(result) == 2
      assert Enum.map(result, & &1["value"]) |> Enum.sort() == [5, 50]
    end

    test "filter with mixed literal types as arguments" do
      data = [
        %{"name" => "alice", "age" => 30, "active" => true},
        %{"name" => "bob", "age" => 25, "active" => false}
      ]

      check = fn name, age, active -> name == "alice" and age > 25 and active end

      result =
        Enzyme.select(
          data,
          "[*][?check(@.name, @.age, @.active)]",
          check: check
        )

      assert length(result) == 1
      assert hd(result)["name"] == "alice"
    end
  end

  describe "filter with function calls and isos" do
    test "function with iso on argument" do
      data = [
        %{"count" => "42"},
        %{"count" => "7"},
        %{"count" => "100"}
      ]

      even? = fn x -> rem(x, 2) == 0 end

      result = Enzyme.select(data, "[*][?even?(@.count::integer)]", even?: even?)

      assert length(result) == 2
      assert Enum.map(result, & &1["count"]) |> Enum.sort() == ["100", "42"]
    end

    test "function with chained isos on argument" do
      data = [
        %{"value" => Base.encode64("42")},
        %{"value" => Base.encode64("7")}
      ]

      large? = fn x -> x > 10 end

      result =
        Enzyme.select(
          data,
          "[*][?large?(@.value::base64::integer)]",
          large?: large?
        )

      assert length(result) == 1
    end

    test "function with multiple arguments having isos" do
      data = [
        %{"a" => "10", "b" => "20"},
        %{"a" => "30", "b" => "25"}
      ]

      greater? = fn a, b -> a > b end

      result =
        Enzyme.select(
          data,
          "[*][?greater?(@.a::integer, @.b::integer)]",
          greater?: greater?
        )

      assert length(result) == 1
      assert hd(result)["a"] == "30"
    end
  end

  describe "filter with function calls in logical expressions" do
    test "function call with 'and'" do
      data = [
        %{"status" => {:confirmed, "A"}, "amount" => 100},
        %{"status" => {:confirmed, "B"}, "amount" => 50},
        %{"status" => {:pending, "C"}, "amount" => 100}
      ]

      confirmed? = fn
        {:confirmed, _} -> true
        _ -> false
      end

      result =
        Enzyme.select(
          data,
          "[*][?confirmed?(@.status) and @.amount > 75]",
          confirmed?: confirmed?
        )

      assert length(result) == 1
      assert hd(result)["status"] == {:confirmed, "A"}
    end

    test "multiple function calls with 'and'" do
      data = [
        %{"x" => 10, "y" => 20},
        %{"x" => -5, "y" => 25},
        %{"x" => 30, "y" => -10}
      ]

      positive? = fn x -> x > 0 end

      result =
        Enzyme.select(
          data,
          "[*][?positive?(@.x) and positive?(@.y)]",
          positive?: positive?
        )

      assert length(result) == 1
      assert hd(result)["x"] == 10
    end

    test "function call with 'or'" do
      data = [
        %{"a" => 200},
        %{"a" => 50},
        %{"a" => 150}
      ]

      large? = fn x -> x > 100 end

      result =
        Enzyme.select(
          data,
          "[*][?large?(@.a) or @.a < 60]",
          large?: large?
        )

      assert length(result) == 3
    end

    test "function call with 'not'" do
      data = [%{"n" => 1}, %{"n" => 2}, %{"n" => 3}]

      even? = fn x -> rem(x, 2) == 0 end

      result =
        Enzyme.select(
          data,
          "[*][?not even?(@.n)]",
          even?: even?
        )

      assert length(result) == 2
      assert Enum.map(result, & &1["n"]) |> Enum.sort() == [1, 3]
    end

    test "complex logical expression with functions" do
      data = [
        %{"a" => 10, "b" => 20, "c" => 30},
        %{"a" => 5, "b" => 15, "c" => 25},
        %{"a" => 20, "b" => 10, "c" => 5}
      ]

      gt = fn a, b -> a > b end

      result =
        Enzyme.select(
          data,
          "[*][?gt(@.a, 7) and (gt(@.b, 12) or gt(@.c, 28))]",
          gt: gt
        )

      assert length(result) == 1
      assert hd(result)["a"] == 10
    end
  end

  describe "filter with function calls on both sides of comparison" do
    test "function on left side of comparison" do
      data = [
        %{"items" => [10, 20, 30]},
        %{"items" => [1, 2, 3]}
      ]

      sum = fn list -> Enum.sum(list) end

      result =
        Enzyme.select(
          data,
          "[*][?sum(@.items) > 50]",
          sum: sum
        )

      assert length(result) == 1
      assert Enum.sum(hd(result)["items"]) > 50
    end

    test "function on right side of comparison" do
      data = [%{"value" => 50}, %{"value" => 150}]

      max_allowed = fn -> 100 end

      result =
        Enzyme.select(
          data,
          "[*][?@.value < max_allowed()]",
          max_allowed: max_allowed
        )

      assert length(result) == 1
      assert hd(result)["value"] == 50
    end

    test "functions on both sides of comparison" do
      data = [
        %{"a" => [1, 2, 3], "b" => [4, 5]},
        %{"a" => [10], "b" => [1, 2, 3]}
      ]

      sum = fn list -> Enum.sum(list) end

      result =
        Enzyme.select(
          data,
          "[*][?sum(@.a) > sum(@.b)]",
          sum: sum
        )

      assert length(result) == 1
    end
  end

  describe "filter function call edge cases" do
    test "function returning nil" do
      data = [%{"x" => 1}, %{"x" => 2}]

      always_nil = fn _ -> nil end

      result =
        Enzyme.select(
          data,
          "[*][?always_nil(@.x)]",
          always_nil: always_nil
        )

      assert result == []
    end

    test "function returning false" do
      data = [%{"x" => 1}]

      always_false = fn _ -> false end

      result =
        Enzyme.select(
          data,
          "[*][?always_false(@.x)]",
          always_false: always_false
        )

      assert result == []
    end

    test "function with missing argument field" do
      data = [%{"other" => 42}]

      check = fn
        nil -> false
        _ -> true
      end

      result =
        Enzyme.select(
          data,
          "[*][?check(@.missing)]",
          check: check
        )

      assert result == []
    end

    test "function that raises" do
      data = [%{"x" => 1}]

      boom = fn _ -> raise "oops" end

      assert_raise RuntimeError, "oops", fn ->
        Enzyme.select(data, "[*][?boom(@.x)]", boom: boom)
      end
    end

    test "function with self reference" do
      data = [1, 2, 3, 4, 5]

      even? = fn x -> rem(x, 2) == 0 end

      result = Enzyme.select(data, "[*][?even?(@)]", even?: even?)

      assert result == [2, 4]
    end
  end

  describe "filter function call errors" do
    test "undefined function raises" do
      data = [%{"x" => 1}]

      assert_raise ArgumentError, ~r/Function 'missing' not provided/, fn ->
        Enzyme.select(data, "[*][?missing(@.x)]")
      end
    end

    test "non-function value raises" do
      data = [%{"x" => 1}]

      assert_raise ArgumentError, ~r/Expected function for 'foo'/, fn ->
        Enzyme.select(data, "[*][?foo(@.x)]", foo: 42)
      end
    end

    test "parse error for bare identifier" do
      data = [%{"x" => 1}]

      assert_raise RuntimeError, ~r/Expected operand but found identifier 'x'/, fn ->
        Enzyme.select(data, "[*][?x > 0]")
      end
    end
  end

  describe "transform with function call filters" do
    test "transform elements filtered by function" do
      data = [
        %{"status" => {:confirmed, "A"}, "name" => "alice"},
        %{"status" => {:pending, "B"}, "name" => "bob"}
      ]

      confirmed? = fn
        {:confirmed, _} -> true
        _ -> false
      end

      result =
        Enzyme.transform(
          data,
          "[*][?confirmed?(@.status)].name",
          &String.upcase/1,
          confirmed?: confirmed?
        )

      assert result == [
               %{"status" => {:confirmed, "A"}, "name" => "ALICE"},
               %{"status" => {:pending, "B"}, "name" => "bob"}
             ]
    end

    test "transform with function and comparison" do
      data = [
        %{"items" => [1, 2, 3], "name" => "a"},
        %{"items" => [10, 20], "name" => "b"}
      ]

      total = fn items -> Enum.sum(items) end

      result =
        Enzyme.transform(
          data,
          "[*][?total(@.items) > 10].name",
          &String.upcase/1,
          total: total
        )

      assert result == [
               %{"items" => [1, 2, 3], "name" => "a"},
               %{"items" => [10, 20], "name" => "B"}
             ]
    end
  end

  describe "integration with real-world scenarios" do
    test "orders with tuple status filtering" do
      # Ensure atoms exist
      _ = :premium
      _ = :basic
      _ = :tier

      orders = [
        %{
          "id" => "ORD-001",
          "status" => {:confirmed, 12_345},
          "customer" => %{"name" => "Alice", "tier" => :premium},
          "shipping" => %{"method" => "express"}
        },
        %{
          "id" => "ORD-002",
          "status" => {:pending, 67_890},
          "customer" => %{"name" => "Bob", "tier" => :premium},
          "shipping" => %{"method" => "express"}
        },
        %{
          "id" => "ORD-003",
          "status" => {:confirmed, 11_111},
          "customer" => %{"name" => "Carol", "tier" => :basic},
          "shipping" => %{"method" => "standard"}
        }
      ]

      confirmed? = fn
        {:confirmed, _} -> true
        _ -> false
      end

      result =
        Enzyme.select(
          orders,
          "[*][?@.customer.tier == :premium][?@.shipping.method == 'express'][?confirmed?(@.status)].customer.name",
          confirmed?: confirmed?
        )

      assert result == ["Alice"]
    end

    test "complex calculation in filter" do
      products = [
        %{"name" => "A", "items" => [%{"price" => 10, "qty" => 2}, %{"price" => 5, "qty" => 3}]},
        %{"name" => "B", "items" => [%{"price" => 100, "qty" => 1}]},
        %{"name" => "C", "items" => [%{"price" => 5, "qty" => 2}]}
      ]

      total_value = fn items ->
        Enum.reduce(items, 0, fn item, acc -> acc + item["price"] * item["qty"] end)
      end

      result =
        Enzyme.select(
          products,
          "[*][?total_value(@.items) > 30].name",
          total_value: total_value
        )

      assert Enum.sort(result) == ["A", "B"]
    end
  end
end
