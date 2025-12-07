defmodule Enzyme.SliceTest do
  use ExUnit.Case
  doctest Enzyme.Slice

  alias Enzyme.Slice

  # These tests use the internal Slice.select/2 and Slice.transform/3 functions
  # which return wrapped values. The public Enzyme.select/2 API unwraps results.

  describe "Slice.select/2 (internal)" do
    test "returns nothing when indices are not found in list" do
      lens = %Slice{indices: [10, 11]}

      assert Slice.select(lens, {:single, [10, 20]}) ==
               {:many, []}

      assert Slice.select(lens, {:many, [[10, 20], [30, 40]]}) ==
               {:many, [[], []]}

      assert Slice.select(lens, {:single, {10, 20}}) ==
               {:many, {}}

      assert Slice.select(lens, {:many, [{10, 20}, {30, 40}]}) ==
               {:many, [{}, {}]}

      assert Slice.select(lens, {10, 20}) ==
               {:many, {}}

      assert Slice.select(lens, [10, 20]) ==
               {:many, []}

      assert Slice.select(lens, %{"a" => 10, "b" => 20}) ==
               {:many, []}
    end

    test "selects values from map with atom keys" do
      lens = %Slice{indices: [:a, :b]}

      assert Slice.select(lens, %{a: 10, b: 20, c: 30}) ==
               {:many, [10, 20]}

      assert Slice.select(lens, {:single, %{a: 10, b: 20, c: 30}}) ==
               {:many, [10, 20]}

      assert Slice.select(lens, {:many, [%{a: 10, b: 20}, %{a: 30, b: 40}]}) ==
               {:many, [[10, 20], [30, 40]]}
    end

    test "returns empty when atom keys are not found in map" do
      lens = %Slice{indices: [:missing, :also_missing]}

      assert Slice.select(lens, %{a: 10, b: 20}) ==
               {:many, []}
    end

    test "distinguishes between atom and string keys" do
      atom_lens = %Slice{indices: [:a, :b]}
      string_lens = %Slice{indices: ["a", "b"]}

      # Map with atom keys
      assert Slice.select(atom_lens, %{a: 10, b: 20}) == {:many, [10, 20]}
      assert Slice.select(string_lens, %{a: 10, b: 20}) == {:many, []}

      # Map with string keys
      assert Slice.select(atom_lens, %{"a" => 10, "b" => 20}) == {:many, []}
      assert Slice.select(string_lens, %{"a" => 10, "b" => 20}) == {:many, [10, 20]}
    end
  end

  describe "Slice.transform/3 (internal)" do
    test "returns collection unchanged when indices are not found" do
      lens = %Slice{indices: [10, 11]}

      assert Slice.transform(lens, {:single, [10, 20]}, &(&1 * 10)) ==
               {:many, [10, 20]}

      assert Slice.transform(lens, {:many, [[10, 20], [30, 40]]}, &(&1 * 10)) ==
               {:many, [[10, 20], [30, 40]]}

      assert Slice.transform(lens, {:single, {10, 20}}, &(&1 * 10)) ==
               {:many, {10, 20}}

      assert Slice.transform(lens, {:many, [{10, 20}, {30, 40}]}, &(&1 * 10)) ==
               {:many, [{10, 20}, {30, 40}]}

      assert Slice.transform(lens, {10, 20}, &(&1 * 10)) ==
               {:many, {10, 20}}

      assert Slice.transform(lens, [10, 20], &(&1 * 10)) ==
               {:many, [10, 20]}

      assert Slice.transform(lens, %{"a" => 10, "b" => 20}, &(&1 * 10)) ==
               {:many, %{"a" => 10, "b" => 20}}
    end

    test "transforms values in map with atom keys" do
      lens = %Slice{indices: [:a, :b]}

      assert Slice.transform(lens, %{a: 10, b: 20, c: 30}, &(&1 * 10)) ==
               {:many, %{a: 100, b: 200, c: 30}}

      assert Slice.transform(lens, {:single, %{a: 10, b: 20, c: 30}}, &(&1 * 10)) ==
               {:many, %{a: 100, b: 200, c: 30}}

      assert Slice.transform(lens, {:many, [%{a: 10, b: 20}, %{a: 30, b: 40}]}, &(&1 * 10)) ==
               {:many, [%{a: 100, b: 200}, %{a: 300, b: 400}]}
    end

    test "returns map unchanged when atom keys are not found" do
      lens = %Slice{indices: [:missing, :also_missing]}

      assert Slice.transform(lens, %{a: 10, b: 20}, &(&1 * 10)) ==
               {:many, %{a: 10, b: 20}}
    end

    test "distinguishes between atom and string keys when transforming" do
      atom_lens = %Slice{indices: [:a, :b]}
      string_lens = %Slice{indices: ["a", "b"]}

      # Transform map with atom keys using atom lens
      assert Slice.transform(atom_lens, %{a: 10, b: 20, c: 30}, &(&1 * 10)) ==
               {:many, %{a: 100, b: 200, c: 30}}

      # Transform map with atom keys using string lens (no match)
      assert Slice.transform(string_lens, %{a: 10, b: 20, c: 30}, &(&1 * 10)) ==
               {:many, %{a: 10, b: 20, c: 30}}

      # Transform map with string keys using string lens
      assert Slice.transform(string_lens, %{"a" => 10, "b" => 20, "c" => 30}, &(&1 * 10)) ==
               {:many, %{"a" => 100, "b" => 200, "c" => 30}}

      # Transform map with string keys using atom lens (no match)
      assert Slice.transform(atom_lens, %{"a" => 10, "b" => 20, "c" => 30}, &(&1 * 10)) ==
               {:many, %{"a" => 10, "b" => 20, "c" => 30}}
    end
  end
end
