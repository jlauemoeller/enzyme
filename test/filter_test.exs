defmodule Enzyme.FilterTest do
  use ExUnit.Case
  doctest Enzyme.Filter

  alias Enzyme.Filter

  # These tests use the internal Filter.select/2 and Filter.transform/3 functions
  # which return wrapped values. The public Enzyme.select/2 API unwraps results.

  describe "Filter.select/2 (internal)" do
    test "returns value when predicate matches for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, {:single, 20}) == {:single, 20}
    end

    test "returns nil when predicate does not match for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, {:single, 10}) == {:single, nil}
    end

    test "filters list based on predicate" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, {:many, [10, 20, 30, 5]}) == {:many, [20, 30]}
    end

    test "filters unwrapped list based on predicate" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, [10, 20, 30, 5]) == {:many, [20, 30]}
    end

    test "filters tuple based on predicate" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, {10, 20, 30, 5}) == {:many, {20, 30}}
    end

    test "returns empty list when no elements match" do
      lens = %Filter{predicate: fn x -> x > 100 end}

      assert Filter.select(lens, {:many, [10, 20, 30]}) == {:many, []}
    end

    test "returns all elements when all match" do
      lens = %Filter{predicate: fn x -> x > 0 end}

      assert Filter.select(lens, {:many, [10, 20, 30]}) == {:many, [10, 20, 30]}
    end

    test "filters maps based on field values" do
      lens = %Filter{predicate: fn item -> item.active end}

      result =
        Filter.select(lens, {:many, [%{active: true, name: "a"}, %{active: false, name: "b"}]})

      assert result == {:many, [%{active: true, name: "a"}]}
    end

    test "filters with complex predicates" do
      lens = %Filter{predicate: fn item -> item.score > 50 and item.active end}

      data = [
        %{active: true, score: 60},
        %{active: false, score: 70},
        %{active: true, score: 40}
      ]

      assert Filter.select(lens, {:many, data}) == {:many, [%{active: true, score: 60}]}
    end
  end

  describe "Filter.transform/3 (internal)" do
    test "transforms value when predicate matches for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, {:single, 20}, &(&1 * 10)) == {:single, 200}
    end

    test "returns value unchanged when predicate does not match for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, {:single, 10}, &(&1 * 10)) == {:single, 10}
    end

    test "transforms only matching elements in list" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, {:many, [10, 20, 30, 5]}, &(&1 * 10)) ==
               {:many, [10, 200, 300, 5]}
    end

    test "transforms only matching elements in unwrapped list" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, [10, 20, 30, 5], &(&1 * 10)) ==
               {:many, [10, 200, 300, 5]}
    end

    test "transforms only matching elements in tuple" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, {10, 20, 30, 5}, &(&1 * 10)) ==
               {:many, {10, 200, 300, 5}}
    end

    test "returns list unchanged when no elements match" do
      lens = %Filter{predicate: fn x -> x > 100 end}

      assert Filter.transform(lens, {:many, [10, 20, 30]}, &(&1 * 10)) ==
               {:many, [10, 20, 30]}
    end

    test "transforms all elements when all match" do
      lens = %Filter{predicate: fn x -> x > 0 end}

      assert Filter.transform(lens, {:many, [10, 20, 30]}, &(&1 * 10)) ==
               {:many, [100, 200, 300]}
    end

    test "transforms maps based on field values" do
      lens = %Filter{predicate: fn item -> item.active end}

      result =
        Filter.transform(
          lens,
          {:many, [%{active: true, n: 1}, %{active: false, n: 2}]},
          &Map.put(&1, :n, &1.n * 10)
        )

      assert result == {:many, [%{active: true, n: 10}, %{active: false, n: 2}]}
    end
  end
end
