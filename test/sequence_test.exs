defmodule Enzyme.SequenceTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.Sequence

  import Enzyme.Wraps

  alias Enzyme.All
  alias Enzyme.One
  alias Enzyme.Sequence

  # These tests use the internal Sequence.select/2 and Sequence.transform/3 functions
  # which return wrapped values. The public Enzyme.select/2 API unwraps results.

  describe "Sequence.select/2 (internal)" do
    test "empty sequence returns the collection unchanged" do
      seq = %Sequence{lenses: []}

      assert Sequence.select(seq, [1, 2, 3]) == [1, 2, 3]
      assert Sequence.select(seq, %{"a" => 1}) == %{"a" => 1}
    end

    test "single lens sequence behaves like the lens itself" do
      seq = %Sequence{lenses: [%One{index: 0}]}

      assert Sequence.select(seq, [10, 20, 30]) == single(10)
    end

    test "sequences two One lenses for nested access" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "name"}]}

      data = %{"user" => %{"name" => "Alice", "age" => 30}}
      assert Sequence.select(seq, data) == single("Alice")
    end

    test "sequences three One lenses for deeply nested access" do
      seq = %Sequence{
        lenses: [
          %One{index: "company"},
          %One{index: "ceo"},
          %One{index: "name"}
        ]
      }

      data = %{"company" => %{"ceo" => %{"name" => "Bob"}}}
      assert Sequence.select(seq, data) == single("Bob")
    end

    test "sequences One then All to get all nested values" do
      seq = %Sequence{lenses: [%One{index: "items"}, %All{}]}

      data = %{"items" => [1, 2, 3]}
      assert Sequence.select(seq, data) == many([1, 2, 3])
    end

    test "sequences All then One to get a field from each element" do
      seq = %Sequence{lenses: [%All{}, %One{index: "name"}]}

      data = [%{"name" => "Alice"}, %{"name" => "Bob"}]
      assert Sequence.select(seq, data) == many(["Alice", "Bob"])
    end

    test "sequences One, All, One for nested array field access" do
      seq = %Sequence{
        lenses: [
          %One{index: "users"},
          %All{},
          %One{index: "email"}
        ]
      }

      data = %{
        "users" => [
          %{"email" => "alice@example.com"},
          %{"email" => "bob@example.com"}
        ]
      }

      assert Sequence.select(seq, data) == many(["alice@example.com", "bob@example.com"])
    end

    test "returns none when intermediate key is missing" do
      seq = %Sequence{lenses: [%One{index: "missing"}, %One{index: "name"}]}

      data = %{"user" => %{"name" => "Alice"}}
      assert Sequence.select(seq, data) == none()
    end

    test "handles numeric indices in sequence" do
      seq = %Sequence{lenses: [%One{index: 0}, %One{index: 1}]}

      data = [[10, 20], [30, 40]]
      assert Sequence.select(seq, data) == single(20)
    end

    test "handles mixed key types in sequence" do
      seq = %Sequence{lenses: [%One{index: "data"}, %One{index: :value}]}

      data = %{"data" => %{value: 42}}
      assert Sequence.select(seq, data) == single(42)
    end
  end

  describe "Sequence.transform/3 (internal)" do
    test "empty sequence applies transform to entire collection" do
      seq = %Sequence{lenses: []}

      assert Sequence.transform(seq, [1, 2, 3], fn list -> Enum.map(list, &(&1 * 10)) end) ==
               [10, 20, 30]
    end

    test "single lens sequence transforms like the lens itself" do
      seq = %Sequence{lenses: [%One{index: 0}]}

      assert Sequence.transform(seq, [10, 20, 30], &(&1 * 10)) == [100, 20, 30]
    end

    test "sequences two One lenses for nested transformation" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "name"}]}

      data = %{"user" => %{"name" => "alice", "age" => 30}}
      result = Sequence.transform(seq, data, &String.upcase/1)

      assert result == %{"user" => %{"name" => "ALICE", "age" => 30}}
    end

    test "sequences One then All to transform all nested values" do
      seq = %Sequence{lenses: [%One{index: "items"}, %All{}]}

      data = %{"items" => [1, 2, 3]}
      result = Sequence.transform(seq, data, &(&1 * 10))

      assert result == %{"items" => [10, 20, 30]}
    end

    test "sequences All then One to transform a field in each element" do
      seq = %Sequence{lenses: [%All{}, %One{index: "count"}]}

      data = [%{"count" => 1}, %{"count" => 2}]
      result = Sequence.transform(seq, data, &(&1 * 10))

      assert result == [%{"count" => 10}, %{"count" => 20}]
    end

    test "sequences One, All, One for nested array field transformation" do
      seq = %Sequence{
        lenses: [
          %One{index: "users"},
          %All{},
          %One{index: "score"}
        ]
      }

      data = %{
        "users" => [
          %{"name" => "Alice", "score" => 85},
          %{"name" => "Bob", "score" => 90}
        ]
      }

      result = Sequence.transform(seq, data, &(&1 + 10))

      assert result == %{
               "users" => [
                 %{"name" => "Alice", "score" => 95},
                 %{"name" => "Bob", "score" => 100}
               ]
             }
    end

    test "leaves collection unchanged when intermediate key is missing" do
      seq = %Sequence{lenses: [%One{index: "missing"}, %One{index: "name"}]}

      data = %{"user" => %{"name" => "Alice"}}
      result = Sequence.transform(seq, data, &String.upcase/1)

      assert result == data
    end

    test "handles numeric indices in sequence transformation" do
      seq = %Sequence{lenses: [%One{index: 0}, %One{index: 1}]}

      data = [[10, 20], [30, 40]]
      result = Sequence.transform(seq, data, &(&1 * 10))

      assert result == [[10, 200], [30, 40]]
    end

    test "handles constant value replacement" do
      seq = %Sequence{lenses: [%One{index: "user"}, %One{index: "active"}]}

      data = %{"user" => %{"name" => "Alice", "active" => false}}
      result = Sequence.transform(seq, data, fn _ -> true end)

      assert result == %{"user" => %{"name" => "Alice", "active" => true}}
    end
  end

  describe "Sequence opts field" do
    test "stores opts for iso resolution" do
      seq = %Sequence{lenses: [%One{index: "value"}], opts: [custom: :iso]}

      assert seq.opts == [custom: :iso]
    end

    test "defaults to empty opts" do
      seq = %Sequence{lenses: [%One{index: "value"}]}

      assert seq.opts == []
    end
  end
end
