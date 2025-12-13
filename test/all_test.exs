defmodule Enzyme.AllTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.All

  import Enzyme.Wraps

  alias Enzyme.All
  alias Enzyme.Many

  describe "All.select/2" do
    test "returns %None{} when input is %None{}" do
      lens = %All{}

      assert All.select(lens, none()) == none()
    end

    test "lifts individual values in a %Single{} list to wrapped values" do
      lens = %All{}

      assert All.select(lens, single([10, 20, 30])) ==
               many([single(10), single(20), single(30)])
    end

    test "lifts individual values in a %Single{} tuple to wrapped values" do
      lens = %All{}

      assert All.select(lens, single({10, 20, 30})) ==
               many([single(10), single(20), single(30)])
    end

    test "lifts individual values in a %Single{} map to wrapped values" do
      lens = %All{}

      %Many{values: actual_values} = All.select(lens, single(%{a: 10, b: 20, c: 30}))
      %Many{values: expect_values} = many([single(10), single(20), single(30)])

      assert Enum.sort(actual_values) == Enum.sort(expect_values)
    end

    test "distributes over %Many{}" do
      lens = %All{}

      assert All.select(
               lens,
               many([
                 single([10, 20]),
                 single([30, 40])
               ])
             ) ==
               many([
                 single(10),
                 single(20),
                 single(30),
                 single(40)
               ])
    end

    test "Returns input when input is a %Single{} with a non-collection value" do
      lens = %All{}
      assert All.select(lens, single(1)) == single(1)
    end

    test "returns empty collection when input collection is empty" do
      lens = %All{}

      assert All.select(lens, single([])) == many([])
      assert All.select(lens, many([])) == many([])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %All{}

      assert_raise ArgumentError, fn ->
        All.select(lens, 123)
      end
    end
  end

  describe "All.transform/3" do
    test "returns %None{} when input is %None{}" do
      lens = %All{}

      assert All.transform(lens, none(), &(&1 * 10)) == none()
    end

    test "transforms a %Single{} scalar value" do
      lens = %All{}

      assert All.transform(lens, single(10), &(&1 * 10)) == single(100)
    end

    test "transforms a %Single{} list value" do
      lens = %All{}

      assert All.transform(lens, single([1, 2, 3]), &(&1 * 10)) == single([10, 20, 30])
    end

    test "transforms a %Single{} tuple value" do
      lens = %All{}

      assert All.transform(lens, single({1, 2, 3}), &(&1 * 10)) == single([10, 20, 30])
    end

    test "transforms a %Single{} map value" do
      lens = %All{}

      assert All.transform(lens, single(%{a: 1, b: 2, c: 3}), &(&1 * 10)) ==
               single(%{a: 10, b: 20, c: 30})
    end

    test "distributes over %Many{}" do
      lens = %All{}

      assert All.transform(
               lens,
               many([
                 single(10),
                 single(20)
               ]),
               &(&1 * 10)
             ) ==
               many([
                 single(100),
                 single(200)
               ])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %All{}

      assert_raise ArgumentError, fn ->
        All.transform(lens, 123, &(&1 * 10))
      end
    end

    test "raises ArgumentError when transform is not a function of arity 1" do
      lens = %All{}

      assert_raise ArgumentError, fn ->
        All.transform(lens, single(10), 123)
      end
    end
  end
end
