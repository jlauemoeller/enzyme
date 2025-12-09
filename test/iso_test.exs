defmodule IsoTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Enzyme.Wraps

  alias Enzyme.Iso

  describe "Iso.new/2" do
    test "creates an iso with forward and backward functions" do
      iso = Iso.new(&String.upcase/1, &String.downcase/1)
      assert is_function(iso.forward, 1)
      assert is_function(iso.backward, 1)
    end

    test "forward and backward functions work correctly" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))
      assert iso.forward.(5) == 10
      assert iso.backward.(10) == 5
    end
  end

  describe "Iso.select/2" do
    test "returns %None{} if input is %None{}" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))
      assert Iso.select(iso, none()) == none()
    end

    test "applies forward transformation to single value" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))
      assert Iso.select(iso, single(5)) == single(10)
    end

    test "applies forward transformation to each item in many" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))

      assert Iso.select(iso, many([single(1), single(2), single(3)])) ==
               many([single(2), single(4), single(6)])
    end

    test "raises ArgumentError when input is not wrapped" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))

      assert_raise ArgumentError, fn ->
        Iso.select(iso, 123)
      end
    end
  end

  describe "Iso.transform/3" do
    test "transforms %None{} to %None{}" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))
      assert Iso.transform(iso, none(), &(&1 + 10)) == none()
    end

    test "transforms %Single{} value" do
      iso = Iso.new(&String.to_integer/1, &to_string/1)

      result = Iso.transform(iso, single("5"), &(&1 + 10))
      assert result == single("15")
    end

    test "distributes ober %Many{}" do
      iso = Iso.new(&String.to_integer/1, &to_string/1)

      result = Iso.transform(iso, many([single("1"), single("2"), single("3")]), &(&1 * 10))
      assert result == many([single("10"), single("20"), single("30")])
    end

    test "raises ArgumentError when input is not wrapped" do
      iso = Iso.new(&String.to_integer/1, &to_string/1)

      assert_raise ArgumentError, fn ->
        Iso.transform(iso, "123", &(&1 + 10))
      end
    end

    test "raises ArgumentError when transform function is invalid" do
      iso = Iso.new(&String.to_integer/1, &to_string/1)

      assert_raise ArgumentError, fn ->
        Iso.transform(iso, single("123"), "not_a_function")
      end
    end
  end
end
