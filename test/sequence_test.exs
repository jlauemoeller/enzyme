defmodule Enzyme.SequenceTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.Sequence

  import Enzyme.Wraps

  alias Enzyme.One
  alias Enzyme.Sequence

  describe "Sequence.select/2" do
    test "returns none when input is none" do
      seq = %Sequence{lenses: [%One{index: "key"}]}
      assert Sequence.select(seq, none()) == none()
    end

    test "returns collection when sequence is empty" do
      seq = %Sequence{lenses: []}
      assert Sequence.select(seq, single([1, 2, 3])) == single([1, 2, 3])
    end

    test "returns result of applying lenses in sequence to single value" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "name"}]}

      data = %{"user" => %{"name" => "alice", "age" => 30}}
      assert Sequence.select(seq, single(data)) == single("alice")
    end

    test "returns result of applying lenses in sequence to many values" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "name"}]}

      data = [
        single(%{"user" => %{"name" => "alice", "age" => 30}}),
        single(%{"user" => %{"name" => "bob", "age" => 25}})
      ]

      assert Sequence.select(seq, many(data)) ==
               many([single("alice"), single("bob")])
    end

    test "raises ArgumentError when input is not wrapped" do
      seq = %Sequence{lenses: [%One{index: "key"}]}

      assert_raise ArgumentError, fn ->
        Sequence.select(seq, 123)
      end
    end
  end

  describe "Sequence.transform" do
    test "returns none when input is none" do
      seq = %Sequence{lenses: [%One{index: "key"}]}
      assert Sequence.transform(seq, none(), & &1) == none()
    end

    test "empty sequence applies transform to entire collection" do
      seq = %Sequence{lenses: []}

      assert Sequence.transform(seq, single([1, 2, 3]), fn list -> Enum.map(list, &(&1 * 10)) end) ==
               single([10, 20, 30])
    end

    test "works with a single lens in the sequence" do
      seq = %Sequence{lenses: [%One{index: 0}]}

      assert Sequence.transform(seq, single([10]), &(&1 * 10)) == single([100])
    end

    test "works with multiple lenses in sequence" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "name"}]}

      data = %{"user" => %{"name" => "alice", "age" => 30}}
      result = Sequence.transform(seq, single(data), &String.upcase/1)
      assert result == single(%{"user" => %{"name" => "ALICE", "age" => 30}})
    end

    test "distributes over many values" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "age"}]}

      data = [
        single(%{"user" => %{"name" => "alice", "age" => 30}}),
        single(%{"user" => %{"name" => "bob", "age" => 25}})
      ]

      result = Sequence.transform(seq, many(data), &(&1 + 10))

      assert result ==
               many([
                 single(%{"user" => %{"name" => "alice", "age" => 40}}),
                 single(%{"user" => %{"name" => "bob", "age" => 35}})
               ])
    end

    test "raises ArgumentError when input is not wrapped" do
      seq = %Sequence{lenses: [%One{index: "key"}]}

      assert_raise ArgumentError, fn ->
        Sequence.transform(seq, 123, & &1)
      end
    end

    test "raises ArgumentError when transform is not a function" do
      seq = %Sequence{lenses: [%One{index: "key"}]}

      assert_raise ArgumentError, fn ->
        Sequence.transform(seq, single([1, 2, 3]), :not_a_function)
      end
    end
  end
end
