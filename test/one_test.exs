defmodule Enzyme.OneTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.One

  import Enzyme.Wraps

  alias Enzyme.One

  describe "One.select/2" do
    test "returns %None{} when input is %None{}" do
      lens = %One{index: 0}
      assert One.select(lens, none()) == none()
    end

    test "returns %None{} when input is %Single{} with a scalar value" do
      lens = %One{index: 0}
      assert One.select(lens, single(123)) == none()
    end

    test "returns value from list by index when index is valid" do
      lens = %One{index: 1}

      assert One.select(lens, single([10, 20])) == single(20)
    end

    test "returns value from keyword list by atom index when index is valid" do
      lens = %One{index: :a}

      assert One.select(lens, single(a: 10, b: 20)) == single(10)
    end

    test "returns element from end of list if index is less than zero" do
      lens = %One{index: -1}

      assert One.select(lens, single([10, 20])) == single(20)
    end

    test "returns %None{} if index is outside list bounds" do
      lens = %One{index: 5}

      assert One.select(lens, single([10, 20])) == none()
    end

    test "returns value from tuple by index when index is valid" do
      lens = %One{index: 0}

      assert One.select(lens, single({10, 20})) == single(10)
    end

    test "returns %None{} if index is less than zero" do
      lens = %One{index: -1}

      assert One.select(lens, single({10, 20})) == none()
    end

    test "returns %None{} if index is outside tuple bounds" do
      lens = %One{index: 5}

      assert One.select(lens, single({10, 20})) == none()
    end

    test "returns value from map by key when key is present" do
      lens = %One{index: "b"}

      assert One.select(lens, single(%{"a" => 10, "b" => 20})) == single(20)
    end

    test "returns %None{} if key is not present in map" do
      lens = %One{index: "missing"}

      assert One.select(lens, single(%{"a" => 10, "b" => 20})) == none()
    end

    test "reaches into collection" do
      lens = %One{index: 1}

      assert One.select(lens, many([single([10, 20]), single([30, 40])])) ==
               many([single(20), single(40)])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %One{index: 0}

      assert_raise ArgumentError, fn ->
        One.select(lens, 10)
      end
    end
  end

  describe "One.transform/3 (internal)" do
    test "transforms %None{} to %None{}" do
      lens = %One{index: 0}
      assert One.transform(lens, none(), &(&1 * 10)) == none()
    end

    test "transforms list element by index" do
      lens = %One{index: 1}

      assert One.transform(lens, single([10, 20]), &(&1 * 10)) == single([10, 200])
    end

    test "transforms keyword list element by atom index" do
      lens = %One{index: :b}

      assert One.transform(lens, single(a: 10, b: 20), &(&1 * 10)) == single(a: 10, b: 200)
    end

    test "transforms tuple element by index" do
      lens = %One{index: 0}

      assert One.transform(lens, single({10, 20}), &(&1 * 10)) == single({100, 20})
    end

    test "transforms map value by key" do
      lens = %One{index: "a"}

      assert One.transform(lens, single(%{"a" => 10, "b" => 20}), &(&1 * 10)) ==
               single(%{"a" => 100, "b" => 20})
    end

    test "distributes over many" do
      lens = %One{index: 0}

      assert One.transform(lens, many([single([1, 2]), single([3, 4])]), &(&1 * 10)) ==
               many([single([10, 2]), single([30, 4])])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %One{index: 0}

      assert_raise ArgumentError, fn ->
        One.transform(lens, [10, 20], &(&1 * 10))
      end
    end

    test "raises ArgumentError when transform function is invalid" do
      lens = %One{index: 0}

      assert_raise ArgumentError, fn ->
        One.transform(lens, single([10, 20]), "not_a_function")
      end
    end
  end
end
