defmodule Enzyme.SliceTest do
  @moduledoc false

  use ExUnit.Case
  doctest Enzyme.Slice

  import Enzyme.Wraps

  alias Enzyme.Slice

  describe "Slice.select/2" do
    test "returns %None{} when input is %None{}" do
      lens = %Slice{indices: [0, 1]}
      assert Slice.select(lens, none()) == none()
    end

    test "returns selected elements from single list by indices" do
      lens = %Slice{indices: [0, 2]}

      assert Slice.select(lens, single([10, 20, 30, 40])) ==
               many([single(10), single(30)])
    end

    test "returns selected elements from many lists by indices" do
      lens = %Slice{indices: [0, 2]}

      assert Slice.select(lens, many([single([10, 20, 30]), single([40, 50, 60])])) ==
               many([many([single(10), single(30)]), many([single(40), single(60)])])
    end

    test "returns selected elements from single tuple by indices" do
      lens = %Slice{indices: [1, 3]}

      assert Slice.select(lens, single({10, 20, 30, 40})) ==
               many([single(20), single(40)])
    end

    test "returns selected elements from many tuples by indices" do
      lens = %Slice{indices: [1, 3]}

      assert Slice.select(lens, many([single({10, 20, 30, 40}), single({50, 60, 70, 80})])) ==
               many([many([single(20), single(40)]), many([single(60), single(80)])])
    end

    test "returns selected elements from single map by keys" do
      lens = %Slice{indices: ["a", "c"]}

      assert Slice.select(lens, single(%{"a" => 10, "b" => 20, "c" => 30})) ==
               many([single(10), single(30)])
    end

    test "returns selected elements from many maps by keys" do
      lens = %Slice{indices: ["a", "c"]}

      assert Slice.select(
               lens,
               many([
                 single(%{"a" => 10, "b" => 20, "c" => 30}),
                 single(%{"a" => 40, "b" => 50, "c" => 60})
               ])
             ) ==
               many([many([single(10), single(30)]), many([single(40), single(60)])])
    end

    test "returns empty collection when no indices are found in single list" do
      lens = %Slice{indices: [10, 11]}
      assert Slice.select(lens, single([10, 20])) == many([])
    end

    test "returns empty collection when no indices are found in single tuple" do
      lens = %Slice{indices: [10, 11]}
      assert Slice.select(lens, single({10, 20})) == many([])
    end

    test "returns empty collection when no keys are found in single map" do
      lens = %Slice{indices: ["missing", "also_missing"]}
      assert Slice.select(lens, single(%{"a" => 10, "b" => 20})) == many([])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %Slice{indices: [0, 1]}

      assert_raise ArgumentError, fn ->
        Slice.select(lens, 123)
      end
    end
  end

  describe "Slice.transform/3" do
    test "transforms %None{} to %None{}" do
      lens = %Slice{indices: [0, 1]}
      assert Slice.transform(lens, none(), &(&1 * 10)) == none()
    end

    test "returns collection unchanged when indices are not found" do
      lens = %Slice{indices: [10, 11]}

      assert Slice.transform(lens, single([10, 20]), &(&1 * 10)) ==
               single([10, 20])

      assert Slice.transform(lens, many([single([10, 20]), single([30, 40])]), &(&1 * 10)) ==
               many([single([10, 20]), single([30, 40])])

      assert Slice.transform(lens, single({10, 20}), &(&1 * 10)) ==
               single({10, 20})

      assert Slice.transform(lens, many([single({10, 20}), single({30, 40})]), &(&1 * 10)) ==
               many([single({10, 20}), single({30, 40})])

      assert Slice.transform(lens, single({10, 20}), &(&1 * 10)) ==
               single({10, 20})

      assert Slice.transform(lens, single(%{"a" => 10, "b" => 20}), &(&1 * 10)) ==
               single(%{"a" => 10, "b" => 20})
    end

    test "transforms selected elements in single list" do
      lens = %Slice{indices: [0, 2]}

      assert Slice.transform(lens, single([10, 20, 30, 40]), &(&1 * 10)) ==
               single([100, 20, 300, 40])
    end

    test "transforms selected elements in single tuple" do
      lens = %Slice{indices: [1, 3]}

      assert Slice.transform(lens, single({10, 20, 30, 40}), &(&1 * 10)) ==
               single({10, 200, 30, 400})
    end

    test "transforms selected elements in single map" do
      lens = %Slice{indices: ["a", "c"]}

      assert Slice.transform(lens, single(%{"a" => 10, "b" => 20, "c" => 30}), &(&1 * 10)) ==
               single(%{"a" => 100, "b" => 20, "c" => 300})
    end

    test "distributes over many lists" do
      lens = %Slice{indices: [0, 2]}

      assert Slice.transform(
               lens,
               many([single([10, 20, 30]), single([40, 50, 60])]),
               &(&1 * 10)
             ) ==
               many([single([100, 20, 300]), single([400, 50, 600])])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %Slice{indices: [0, 1]}

      assert_raise ArgumentError, fn ->
        Slice.transform(lens, 123, &(&1 * 10))
      end
    end

    test "raises ArgumentError when transform is not a function" do
      lens = %Slice{indices: [0, 1]}

      assert_raise ArgumentError, fn ->
        Slice.transform(lens, single([1, 2, 3]), :not_a_function)
      end
    end
  end
end
