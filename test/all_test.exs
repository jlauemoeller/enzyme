defmodule Enzyme.AllTest do
  use ExUnit.Case
  doctest Enzyme.All

  alias Enzyme.All

  # These tests use the internal All.select/2 and All.transform/3 functions
  # which return wrapped values. The public Enzyme.select/2 API unwraps results.

  describe "All.select/2 (internal)" do
    test "returns empty collection when input collection is empty" do
      lens = %All{}

      assert All.select(lens, {:single, []}) == {:many, []}
      assert All.select(lens, {:many, [[]]}) == {:many, [[]]}
      assert All.select(lens, {}) == {:many, {}}
      assert All.select(lens, []) == {:many, []}
      assert All.select(lens, %{}) == {:many, []}
    end

    test "selects all values from map with atom keys" do
      lens = %All{}

      result = All.select(lens, %{a: 10, b: 20})
      assert {:many, values} = result
      assert Enum.sort(values) == [10, 20]
    end

    test "selects all values from map with mixed key types" do
      lens = %All{}

      result = All.select(lens, %{:atom_key => 10, "string_key" => 20})
      assert {:many, values} = result
      assert Enum.sort(values) == [10, 20]
    end
  end

  describe "All.transform/3 (internal)" do
    test "returns empty collection when input collection is empty" do
      lens = %All{}

      assert All.transform(lens, {:single, []}, &(&1 * 10)) == {:many, []}
      assert All.transform(lens, {:many, [[]]}, &(&1 * 10)) == {:many, [[]]}
      assert All.transform(lens, {}, &(&1 * 10)) == {:many, {}}
      assert All.transform(lens, [], &(&1 * 10)) == {:many, []}
      assert All.transform(lens, %{}, &(&1 * 10)) == {:many, %{}}
    end

    test "transforms all values in map with atom keys" do
      lens = %All{}

      assert All.transform(lens, %{a: 10, b: 20}, &(&1 * 10)) ==
               {:many, %{a: 100, b: 200}}
    end

    test "transforms all values in map with mixed key types" do
      lens = %All{}

      assert All.transform(lens, %{:atom_key => 10, "string_key" => 20}, &(&1 * 10)) ==
               {:many, %{:atom_key => 100, "string_key" => 200}}
    end
  end
end
