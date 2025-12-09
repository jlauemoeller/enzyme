defmodule Enzyme.PrismTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.Prism

  import Enzyme.Wraps

  alias Enzyme.Prism

  describe "Prism.new/2" do
    test "creates a prism with tag and pattern" do
      prism = Prism.new(:ok, [:value])
      assert %Prism{tag: :ok, pattern: [:value], rest: false} = prism
    end

    test "creates a rest prism with :..." do
      prism = Prism.new(:ok, :...)
      assert %Prism{tag: :ok, pattern: nil, rest: true} = prism
    end
  end

  describe "Prism.select/2" do
    test "returns None when input is None" do
      prism = Prism.new(:ok, [:value])
      assert Prism.select(prism, none()) == none()
    end

    test "extracts single value from matching tuple" do
      prism = Prism.new(:ok, [:value])
      assert Prism.select(prism, single({:ok, 5})) == single(5)
    end

    test "returns %None{} for non-matching tag" do
      prism = Prism.new(:ok, [:value])
      assert Prism.select(prism, single({:error, "oops"})) == none()
    end

    test "returns %None{} for wrong arity" do
      prism = Prism.new(:ok, [:value])
      assert Prism.select(prism, single({:ok, 1, 2})) == none()
    end

    test "returns %None{} for non-tuple" do
      prism = Prism.new(:ok, [:value])
      assert Prism.select(prism, single("not a tuple")) == none()
    end

    test "returns %None{} for tuple with correct tag but wrong arity" do
      prism = Prism.new(:ok, [:value])
      assert Prism.select(prism, single({:ok})) == none()
    end

    test "distributes over Many" do
      prism = Prism.new(:ok, [:value])

      assert Prism.select(
               prism,
               many([
                 single({:ok, 10}),
                 single({:error, "x"}),
                 single({:ok, 20}),
                 single({:ok, 30}),
                 single({:error, "y"})
               ])
             ) ==
               many([single(10), single(20), single(30)])
    end

    test "raises ArgumentError when input is not wrapped" do
      prism = Prism.new(:ok, [:value])

      assert_raise ArgumentError, fn ->
        Prism.select(prism, {:ok, 42})
      end
    end
  end

  describe "Prism.select/2 - multiple value extraction" do
    test "extracts multiple values as tuple" do
      prism = Prism.new(:rectangle, [:w, :h])
      assert Prism.select(prism, single({:rectangle, 3, 4})) == single({3, 4})
    end

    test "extracts three values as tuple" do
      prism = Prism.new(:point3d, [:x, :y, :z])
      assert Prism.select(prism, single({:point3d, 1, 2, 3})) == single({1, 2, 3})
    end
  end

  describe "Prism.select/2 - partial extraction with _" do
    test "ignores position marked with nil" do
      prism = Prism.new(:rectangle, [nil, :h])
      assert Prism.select(prism, single({:rectangle, 3, 4})) == single(4)
    end

    test "ignores first position" do
      prism = Prism.new(:point3d, [nil, :y, nil])
      assert Prism.select(prism, single({:point3d, 1, 2, 3})) == single(2)
    end

    test "extracts non-contiguous positions as tuple" do
      prism = Prism.new(:quad, [:a, nil, :c, nil])
      assert Prism.select(prism, single({:quad, 1, 2, 3, 4})) == single({1, 3})
    end
  end

  describe "Prism.select/2 - filter only (all nils)" do
    test "returns original tuple when all positions are nil" do
      prism = Prism.new(:ok, [nil])
      assert Prism.select(prism, single({:ok, 5})) == single({:ok, 5})
    end

    test "returns original tuple for multi-element filter" do
      prism = Prism.new(:rectangle, [nil, nil])
      assert Prism.select(prism, single({:rectangle, 3, 4})) == single({:rectangle, 3, 4})
    end

    test "returns nil for non-matching filter-only prism" do
      prism = Prism.new(:ok, [nil])
      assert Prism.select(prism, single({:error, "x"})) == none()
    end
  end

  describe "Prism.select/2 - rest pattern (...)" do
    test "extracts single element after tag" do
      prism = Prism.new(:ok, :...)
      assert Prism.select(prism, single({:ok, 5})) == single(5)
    end

    test "extracts multiple elements as tuple" do
      prism = Prism.new(:rectangle, :...)
      assert Prism.select(prism, single({:rectangle, 3, 4})) == single({3, 4})
    end

    test "extracts many elements as tuple" do
      prism = Prism.new(:data, :...)
      assert Prism.select(prism, single({:data, 1, 2, 3, 4})) == single({1, 2, 3, 4})
    end

    test "returns empty tuple for tag-only tuple" do
      prism = Prism.new(:empty, :...)
      assert Prism.select(prism, single({:empty})) == single({})
    end
  end

  describe "Prism.select/2 - list of tuples" do
    test "filters and extracts from list of tuples" do
      prism = Prism.new(:ok, [:value])

      result =
        Prism.select(
          prism,
          many([
            single({:ok, 1}),
            single({:error, "a"}),
            single({:ok, 2}),
            single({:error, "b"}),
            single({:ok, 3})
          ])
        )

      assert result == many([single(1), single(2), single(3)])
    end

    test "returns empty list when no matches" do
      prism = Prism.new(:ok, [:value])

      result =
        Prism.select(
          prism,
          many([
            single({:error, "a"}),
            single({:error, "b"})
          ])
        )

      assert result == many([])
    end

    test "extracts tuples from matching items" do
      prism = Prism.new(:rectangle, [:w, :h])

      result =
        Prism.select(
          prism,
          many([
            single({:circle, 5}),
            single({:rectangle, 3, 4}),
            single({:circle, 10}),
            single({:rectangle, 5, 6})
          ])
        )

      assert result == many([single({3, 4}), single({5, 6})])
    end
  end

  describe "Prism.transform/3 - basic transforms" do
    test "transforms matching tuple" do
      prism = Prism.new(:ok, [:value])
      assert Prism.transform(prism, single({:ok, 5}), &(&1 * 2)) == single({:ok, 10})
    end

    test "leaves non-matching tuple unchanged" do
      prism = Prism.new(:ok, [:value])
      assert Prism.transform(prism, single({:error, "x"}), &(&1 * 2)) == single({:error, "x"})
    end

    test "leaves wrong arity unchanged" do
      prism = Prism.new(:ok, [:value])
      assert Prism.transform(prism, single({:ok, 1, 2}), &(&1 * 2)) == single({:ok, 1, 2})
    end

    test "leaves non-tuple unchanged" do
      prism = Prism.new(:ok, [:value])

      assert Prism.transform(prism, single("not a tuple"), &String.upcase/1) ==
               single("not a tuple")
    end
  end

  describe "Prism.transform/3 - multiple value transforms" do
    test "transforms multiple extracted values" do
      prism = Prism.new(:rectangle, [:w, :h])
      # Transform receives {w, h}, should return {new_w, new_h}
      transform_fn = fn {w, h} -> {w * 2, h * 2} end

      assert Prism.transform(prism, single({:rectangle, 3, 4}), transform_fn) ==
               single({:rectangle, 6, 8})
    end

    test "transforms three values" do
      prism = Prism.new(:point3d, [:x, :y, :z])
      transform_fn = fn {x, y, z} -> {x + 1, y + 1, z + 1} end

      assert Prism.transform(prism, single({:point3d, 0, 0, 0}), transform_fn) ==
               single({:point3d, 1, 1, 1})
    end
  end

  describe "Prism.transform/3 - partial transforms with _" do
    test "transforms only extracted position" do
      prism = Prism.new(:rectangle, [nil, :h])
      # Only h is extracted, transform receives just h
      assert Prism.transform(prism, single({:rectangle, 3, 4}), &(&1 * 2)) ==
               single({:rectangle, 3, 8})
    end

    test "transforms non-contiguous positions" do
      prism = Prism.new(:quad, [:a, nil, :c, nil])
      # Transform receives {a, c}
      transform_fn = fn {a, c} -> {a * 10, c * 10} end

      assert Prism.transform(prism, single({:quad, 1, 2, 3, 4}), transform_fn) ==
               single({:quad, 10, 2, 30, 4})
    end
  end

  describe "Prism.transform/3 - filter only transforms" do
    test "transforms whole tuple when all positions are nil" do
      prism = Prism.new(:ok, [nil])
      # Transform receives the whole tuple
      transform_fn = fn {:ok, v} -> {:ok, v * 2} end
      assert Prism.transform(prism, single({:ok, 5}), transform_fn) == single({:ok, 10})
    end
  end

  describe "Prism.transform/3 - rest pattern transforms" do
    test "transforms single element after tag" do
      prism = Prism.new(:ok, :...)
      assert Prism.transform(prism, single({:ok, 5}), &(&1 * 2)) == single({:ok, 10})
    end

    test "transforms multiple elements as tuple" do
      prism = Prism.new(:rectangle, :...)
      transform_fn = fn {w, h} -> {w * 2, h * 2} end

      assert Prism.transform(prism, single({:rectangle, 3, 4}), transform_fn) ==
               single({:rectangle, 6, 8})
    end
  end

  describe "Prism.transform/3 - list transforms" do
    test "transforms matching tuples in list" do
      prism = Prism.new(:ok, [:value])

      result =
        Prism.transform(
          prism,
          many([single({:ok, 1}), single({:error, "x"}), single({:ok, 2})]),
          &(&1 * 10)
        )

      assert result == many([single({:ok, 10}), single({:error, "x"}), single({:ok, 20})])
    end

    test "transforms multiple extracted values in list" do
      prism = Prism.new(:rectangle, [:w, :h])
      transform_fn = fn {w, h} -> {w * 2, h * 2} end

      result =
        Prism.transform(
          prism,
          many([single({:circle, 5}), single({:rectangle, 3, 4}), single({:rectangle, 1, 2})]),
          transform_fn
        )

      assert result ==
               many([
                 single({:circle, 5}),
                 single({:rectangle, 6, 8}),
                 single({:rectangle, 2, 4})
               ])
    end
  end

  describe "Prism.transform/3 - wrapped values" do
    test "handles %Enzyme.Single{}" do
      prism = Prism.new(:ok, [:value])
      assert Prism.transform(prism, single({:ok, 5}), &(&1 * 2)) == single({:ok, 10})
    end

    test "handles %Enzyme.Many{}" do
      prism = Prism.new(:ok, [:value])

      result = Prism.transform(prism, many([single({:ok, 1}), single({:error, "x"})]), &(&1 * 10))
      assert result == many([single({:ok, 10}), single({:error, "x"})])
    end
  end

  describe "prism retagging - shorthand syntax" do
    test "retags single value extraction" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:ok, 42})) == single({:success, 42})
    end

    test "retags multiple value extraction" do
      prism = %Prism{
        tag: :rectangle,
        pattern: [:w, :h],
        rest: false,
        output_tag: :box,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:rectangle, 3, 4})) == single({:box, 3, 4})
    end

    test "retags rest pattern extraction" do
      prism = %Prism{
        tag: :old_tag,
        pattern: nil,
        rest: true,
        output_tag: :new_tag,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:old_tag, 1, 2, 3})) == single({:new_tag, 1, 2, 3})
    end

    test "retags single element rest pattern" do
      prism = %Prism{
        tag: :ok,
        pattern: nil,
        rest: true,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:ok, 42})) == single({:success, 42})
    end

    test "retags filter-only pattern (all nils)" do
      prism = %Prism{
        tag: :ok,
        pattern: [nil],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:ok, 42})) == single({:success, 42})
    end

    test "retags filter-only with multiple nils" do
      prism = %Prism{
        tag: :rectangle,
        pattern: [nil, nil],
        rest: false,
        output_tag: :box,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:rectangle, 3, 4})) == single({:box, 3, 4})
    end

    test "non-matching tuple returns nil with retag" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:error, "fail"})) == none()
    end
  end

  describe "prism retagging - explicit assembly" do
    test "reorders two values" do
      prism = %Prism{
        tag: :pair,
        pattern: [:a, :b],
        rest: false,
        output_tag: :swapped,
        output_pattern: [:b, :a]
      }

      assert Prism.select(prism, single({:pair, 1, 2})) == single({:swapped, 2, 1})
    end

    test "drops middle value from three" do
      prism = %Prism{
        tag: :point3d,
        pattern: [:x, :y, :z],
        rest: false,
        output_tag: :point2d,
        output_pattern: [:x, :z]
      }

      assert Prism.select(prism, single({:point3d, 1, 2, 3})) == single({:point2d, 1, 3})
    end

    test "duplicates a value" do
      prism = %Prism{
        tag: :data,
        pattern: [:value],
        rest: false,
        output_tag: :double,
        output_pattern: [:value, :value]
      }

      assert Prism.select(prism, single({:data, 42})) == single({:double, 42, 42})
    end

    test "extracts from non-contiguous positions and reorders" do
      prism = %Prism{
        tag: :quad,
        pattern: [:a, nil, :c, nil],
        rest: false,
        output_tag: :pair,
        output_pattern: [:c, :a]
      }

      assert Prism.select(prism, single({:quad, 1, 2, 3, 4})) == single({:pair, 3, 1})
    end

    test "single value to single value with new tag" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: [:value]
      }

      assert Prism.select(prism, single({:ok, 42})) == single({:success, 42})
    end
  end

  describe "prism retagging - transform with shorthand" do
    test "transforms and retags single value" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.transform(prism, single({:ok, 5}), &(&1 * 2)) == single({:success, 10})
    end

    test "transforms and retags multiple values" do
      prism = %Prism{
        tag: :rectangle,
        pattern: [:w, :h],
        rest: false,
        output_tag: :box,
        output_pattern: nil
      }

      transform_fn = fn {w, h} -> {w * 2, h * 2} end

      assert Prism.transform(prism, single({:rectangle, 3, 4}), transform_fn) ==
               single({:box, 6, 8})
    end

    test "transforms and retags rest pattern" do
      prism = %Prism{
        tag: :data,
        pattern: nil,
        rest: true,
        output_tag: :values,
        output_pattern: nil
      }

      transform_fn = fn {a, b} -> {a + 1, b + 1} end

      assert Prism.transform(prism, single({:data, 1, 2}), transform_fn) ==
               single({:values, 2, 3})
    end

    test "transforms and retags filter-only pattern" do
      prism = %Prism{
        tag: :ok,
        pattern: [nil],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      transform_fn = fn {:ok, v} -> {:ok, v * 2} end
      # Note: transform receives whole tuple for filter-only, but result is retagged
      assert Prism.transform(prism, single({:ok, 5}), transform_fn) == single({:success, 10})
    end

    test "leaves non-matching tuple unchanged" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.transform(prism, single({:error, "x"}), &(&1 * 2)) == single({:error, "x"})
    end
  end

  describe "prism retagging - transform with assembly" do
    test "transforms and reorders" do
      prism = %Prism{
        tag: :pair,
        pattern: [:a, :b],
        rest: false,
        output_tag: :swapped,
        output_pattern: [:b, :a]
      }

      transform_fn = fn {a, b} -> {a * 10, b * 10} end

      assert Prism.transform(prism, single({:pair, 1, 2}), transform_fn) ==
               single({:swapped, 20, 10})
    end

    test "transforms and drops value" do
      prism = %Prism{
        tag: :point3d,
        pattern: [:x, :y, :z],
        rest: false,
        output_tag: :point2d,
        output_pattern: [:x, :z]
      }

      transform_fn = fn {x, y, z} -> {x + 1, y + 1, z + 1} end

      assert Prism.transform(prism, single({:point3d, 0, 0, 0}), transform_fn) ==
               single({:point2d, 1, 1})
    end

    test "transforms and duplicates" do
      prism = %Prism{
        tag: :data,
        pattern: [:value],
        rest: false,
        output_tag: :double,
        output_pattern: [:value, :value]
      }

      assert Prism.transform(prism, single({:data, 5}), &(&1 * 2)) == single({:double, 10, 10})
    end

    test "transforms non-contiguous extraction with assembly" do
      prism = %Prism{
        tag: :quad,
        pattern: [:a, nil, :c, nil],
        rest: false,
        output_tag: :sum,
        output_pattern: [:c, :a]
      }

      transform_fn = fn {a, c} -> {a + 100, c + 100} end

      assert Prism.transform(prism, single({:quad, 1, 2, 3, 4}), transform_fn) ==
               single({:sum, 103, 101})
    end
  end

  describe "prism retagging - lists" do
    test "retags matching items in list with shorthand" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      result =
        Prism.select(
          prism,
          many([
            single({:ok, 1}),
            single({:error, "x"}),
            single({:ok, 2})
          ])
        )

      assert result == many([single({:success, 1}), single({:success, 2})])
    end

    test "retags and reorders in list" do
      prism = %Prism{
        tag: :pair,
        pattern: [:a, :b],
        rest: false,
        output_tag: :swapped,
        output_pattern: [:b, :a]
      }

      result =
        Prism.select(
          prism,
          many([
            single({:pair, 1, 2}),
            single({:triple, 1, 2, 3}),
            single({:pair, 3, 4})
          ])
        )

      assert result == many([single({:swapped, 2, 1}), single({:swapped, 4, 3})])
    end

    test "transforms and retags list items" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      result =
        Prism.transform(
          prism,
          many([
            single({:ok, 1}),
            single({:error, "x"}),
            single({:ok, 2})
          ]),
          &(&1 * 10)
        )

      assert result ==
               many([single({:success, 10}), single({:error, "x"}), single({:success, 20})])
    end

    test "transforms, reorders, and retags list items" do
      prism = %Prism{
        tag: :pair,
        pattern: [:a, :b],
        rest: false,
        output_tag: :swapped,
        output_pattern: [:b, :a]
      }

      transform_fn = fn {a, b} -> {a + 1, b + 1} end

      result =
        Prism.transform(
          prism,
          many([
            single({:pair, 1, 2}),
            single({:other, 99}),
            single({:pair, 3, 4})
          ]),
          transform_fn
        )

      assert result ==
               many([single({:swapped, 3, 2}), single({:other, 99}), single({:swapped, 5, 4})])
    end
  end

  describe "prism retagging - edge cases" do
    test "empty tuple rest pattern with retag" do
      prism = %Prism{
        tag: :empty,
        pattern: nil,
        rest: true,
        output_tag: :void,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:empty})) == single({:void})
    end

    test "retag preserves structure in partial extraction" do
      prism = %Prism{
        tag: :quad,
        pattern: [nil, :b, nil, :d],
        rest: false,
        output_tag: :pair,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:quad, 1, 2, 3, 4})) == single({:pair, 2, 4})
    end

    test "retag with transform on partial extraction" do
      prism = %Prism{
        tag: :triple,
        pattern: [nil, :b, nil],
        rest: false,
        output_tag: :data,
        output_pattern: nil
      }

      # Shorthand retag with partial extraction: replaces in-place but retags
      assert Prism.transform(prism, single({:triple, 1, 2, 3}), &(&1 * 10)) ==
               single({:data, 1, 20, 3})
    end

    test "assembly with single value input and output" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: [:value]
      }

      assert Prism.select(prism, single({:ok, 42})) == single({:success, 42})
    end

    test "wrapped tuple with retag" do
      prism = %Prism{
        tag: :ok,
        pattern: [:value],
        rest: false,
        output_tag: :success,
        output_pattern: nil
      }

      assert Prism.select(prism, single({:ok, 42})) == single({:success, 42})
    end
  end
end
