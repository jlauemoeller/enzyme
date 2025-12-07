defmodule IsoTest do
  use ExUnit.Case, async: true

  alias Enzyme.Iso
  alias Enzyme.IsoRef

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

  describe "IsoRef.new/1" do
    test "creates a reference with name only" do
      ref = IsoRef.new(:pending)
      assert ref.name == :pending
    end
  end

  describe "Iso.select/2" do
    test "applies forward transformation to single value" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))
      assert Iso.select(iso, {:single, 5}) == {:single, 10}
    end

    test "applies forward transformation to each item in many" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))
      assert Iso.select(iso, {:many, [1, 2, 3]}) == {:many, [2, 4, 6]}
    end
  end

  describe "Iso.transform/3" do
    test "applies forward, transforms, then backward" do
      # Cents to dollars: forward divides by 100, backward multiplies by 100
      iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))

      # Transform adds $1 (in dollars space), stored back in cents
      result = Iso.transform(iso, {:single, 500}, &(&1 + 1))
      # 500 cents -> $5 -> $6 -> 600 cents
      assert result == {:single, 600}
    end

    test "transforms each item in many" do
      iso = Iso.new(&(&1 * 2), &div(&1, 2))

      result = Iso.transform(iso, {:many, [2, 4, 6]}, &(&1 + 10))
      # 2 -> 4 -> 14 -> 7
      # 4 -> 8 -> 18 -> 9
      # 6 -> 12 -> 22 -> 11
      assert result == {:many, [7, 9, 11]}
    end
  end
end
