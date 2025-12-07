defmodule Enzyme.OneTest do
  use ExUnit.Case
  doctest Enzyme.One

  alias Enzyme.One

  # These tests use the internal One.select/2 and One.transform/3 functions
  # which return wrapped values. The public Enzyme.select/2 API unwraps results.

  describe "One.select/2 (internal)" do
    test "returns nil when index is not found in list" do
      lens = %One{index: 10}

      assert One.select(lens, {:single, [10, 20]}) == {:single, nil}

      assert One.select(lens, {:many, [[10, 20], [30, 40]]}) == {:many, [nil, nil]}

      assert One.select(lens, {:single, {10, 20}}) == {:single, nil}

      assert One.select(lens, {:many, [{10, 20}, {30, 40}]}) == {:many, [nil, nil]}

      assert One.select(lens, {10, 20}) == {:single, nil}

      assert One.select(lens, [10, 20]) == {:single, nil}

      assert One.select(lens, ten: 10, twenty: 20) == {:single, nil}

      assert One.select(lens, %{"a" => 10, "b" => 20}) == {:single, nil}
    end

    test "selects value from map with atom key" do
      lens = %One{index: :b}

      assert One.select(lens, %{a: 10, b: 20}) == {:single, 20}

      assert One.select(lens, {:single, %{a: 10, b: 20}}) == {:single, 20}

      assert One.select(lens, {:many, [%{a: 10, b: 20}, %{a: 30, b: 40}]}) == {:many, [20, 40]}
    end

    test "returns nil when atom key is not found in map" do
      lens = %One{index: :missing}

      assert One.select(lens, %{a: 10, b: 20}) == {:single, nil}
    end

    test "distinguishes between atom and string keys" do
      atom_lens = %One{index: :key}
      string_lens = %One{index: "key"}

      # Map with atom key
      assert One.select(atom_lens, %{key: 10}) == {:single, 10}
      assert One.select(string_lens, %{key: 10}) == {:single, nil}

      # Map with string key
      assert One.select(atom_lens, %{"key" => 20}) == {:single, nil}
      assert One.select(string_lens, %{"key" => 20}) == {:single, 20}
    end
  end

  describe "One.transform/3 (internal)" do
    test "returns collection unchanged when index is not found" do
      lens = %One{index: 10}

      assert One.transform(lens, {:single, [10, 20]}, &(&1 * 10)) == {:single, [10, 20]}

      assert One.transform(lens, {:many, [[10, 20], [30, 40]]}, &(&1 * 10)) ==
               {:many, [[10, 20], [30, 40]]}

      assert One.transform(lens, {:single, {10, 20}}, &(&1 * 10)) == {:single, {10, 20}}

      assert One.transform(lens, {:many, [{10, 20}, {30, 40}]}, &(&1 * 10)) ==
               {:many, [{10, 20}, {30, 40}]}

      assert One.transform(lens, {10, 20}, &(&1 * 10)) == {:single, {10, 20}}

      assert One.transform(lens, [10, 20], &(&1 * 10)) == {:single, [10, 20]}

      assert One.transform(lens, [ten: 10, twenty: 20], &(&1 * 10)) ==
               {:single, [ten: 10, twenty: 20]}

      assert One.transform(lens, %{"a" => 10, "b" => 20}, &(&1 * 10)) ==
               {:single, %{"a" => 10, "b" => 20}}
    end

    test "transforms value in map with atom key" do
      lens = %One{index: :b}

      assert One.transform(lens, %{a: 10, b: 20}, &(&1 * 10)) ==
               {:single, %{a: 10, b: 200}}

      assert One.transform(lens, {:single, %{a: 10, b: 20}}, &(&1 * 10)) ==
               {:single, %{a: 10, b: 200}}

      assert One.transform(lens, {:many, [%{a: 10, b: 20}, %{a: 30, b: 40}]}, &(&1 * 10)) ==
               {:many, [%{a: 10, b: 200}, %{a: 30, b: 400}]}
    end

    test "returns map unchanged when atom key is not found" do
      lens = %One{index: :missing}

      assert One.transform(lens, %{a: 10, b: 20}, &(&1 * 10)) ==
               {:single, %{a: 10, b: 20}}
    end

    test "distinguishes between atom and string keys when transforming" do
      atom_lens = %One{index: :key}
      string_lens = %One{index: "key"}

      # Transform map with atom key using atom lens
      assert One.transform(atom_lens, %{key: 10, other: 5}, &(&1 * 10)) ==
               {:single, %{key: 100, other: 5}}

      # Transform map with atom key using string lens (no match)
      assert One.transform(string_lens, %{key: 10, other: 5}, &(&1 * 10)) ==
               {:single, %{key: 10, other: 5}}

      # Transform map with string key using string lens
      assert One.transform(string_lens, %{"key" => 10, "other" => 5}, &(&1 * 10)) ==
               {:single, %{"key" => 100, "other" => 5}}

      # Transform map with string key using atom lens (no match)
      assert One.transform(atom_lens, %{"key" => 10, "other" => 5}, &(&1 * 10)) ==
               {:single, %{"key" => 10, "other" => 5}}
    end
  end
end
