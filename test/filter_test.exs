defmodule Enzyme.FilterTest do
  @moduledoc false

  use ExUnit.Case
  doctest Enzyme.Filter

  import Enzyme.Wraps

  alias Enzyme.Filter

  describe "Filter.select/2" do
    test "returns None when input is None" do
      lens = %Filter{predicate: fn _ -> true end}
      assert Filter.select(lens, none()) == none()
    end

    test "returns value when predicate matches for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, single(20)) == single(20)
    end

    test "returns None when predicate does not match for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, single(10)) == none()
    end

    test "returns matching elements from single list" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(
               lens,
               many([single(10), single(20), single(30)])
             ) == many([single(20), single(30)])
    end

    test "returns empty collection when no elements match in list" do
      lens = %Filter{predicate: fn x -> x > 100 end}

      assert Filter.select(lens, many([single(10), single(20), single(30)])) == many([])
    end

    test "returns matching elements from single tuple" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, single({10, 20, 30})) ==
               many([single(20), single(30)])
    end

    test "returns empty collection when no elements match in tuple" do
      lens = %Filter{predicate: fn x -> x > 100 end}

      assert Filter.select(lens, single({10, 20, 30})) == many([])
    end

    test "returns entire map if single map matches" do
      lens = %Filter{predicate: fn %{active: a} -> a end}

      assert Filter.select(
               lens,
               single(%{active: true, name: "a"})
             ) == single(%{active: true, name: "a"})
    end

    test "returns matching maps from many maps based on field values" do
      lens = %Filter{predicate: fn %{active: a} -> a end}

      assert Filter.select(
               lens,
               many([
                 single(%{active: true, name: "a"}),
                 single(%{active: false, name: "b"})
               ])
             ) == many([single(%{active: true, name: "a"})])
    end

    test "returns empty collection when no maps match based on field values" do
      lens = %Filter{predicate: fn %{active: a} -> a end}

      assert Filter.select(
               lens,
               many([
                 single(%{active: false, name: "a"}),
                 single(%{active: false, name: "b"})
               ])
             ) == many([])
    end

    test "returns matching elements from many singles" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(
               lens,
               many([single(10), single(20), single(30)])
             ) == many([single(20), single(30)])
    end

    test "returns empty collection when no elements match in many singles" do
      lens = %Filter{predicate: fn x -> x > 100 end}

      assert Filter.select(lens, many([single(10), single(20), single(30)])) ==
               many([])
    end

    test "distributes over %Many{}" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(
               lens,
               many([
                 many([single(10), single(20)]),
                 many([single(30), single(5)])
               ])
             ) ==
               many([
                 many([single(20)]),
                 many([single(30)])
               ])
    end

    test "returns %None{} if wrapped value is not a collection" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.select(lens, single(1)) == none()
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert_raise ArgumentError, fn ->
        Filter.select(lens, 123)
      end
    end
  end

  describe "Filter.transform/3" do
    test "transforms value when predicate matches for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, single(20), &(&1 * 10)) == single(200)
    end

    test "returns value unchanged when predicate does not match for single" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(lens, single(10), &(&1 * 10)) == single(10)
    end

    test "distributes over %Many{} and only transforms matching items" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert Filter.transform(
               lens,
               many([single(10), single(20), single(30)]),
               &(&1 * 10)
             ) == many([single(10), single(200), single(300)])
    end

    test "raises ArgumentError when input is not wrapped" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert_raise ArgumentError, fn ->
        Filter.transform(lens, 123, &(&1 * 10))
      end
    end

    test "raises ArgumentError when transform is not a function" do
      lens = %Filter{predicate: fn x -> x > 15 end}

      assert_raise ArgumentError, fn ->
        Filter.transform(lens, single(20), 123)
      end
    end
  end
end
