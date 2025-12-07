defmodule Enzyme.PrismParserTest do
  @moduledoc false
  use ExUnit.Case

  alias Enzyme.All
  alias Enzyme.One
  alias Enzyme.Parser
  alias Enzyme.Prism
  alias Enzyme.Sequence

  describe "Parser.parse/1 - prism syntax" do
    test "parses simple prism with single extraction" do
      result = Parser.parse(":{:ok, v}")
      assert %Prism{tag: :ok, pattern: [:v], rest: false} = result
    end

    test "parses prism with multiple extractions" do
      result = Parser.parse(":{:rectangle, w, h}")
      assert %Prism{tag: :rectangle, pattern: [:w, :h], rest: false} = result
    end

    test "parses prism with ignored positions" do
      result = Parser.parse(":{:rectangle, _, h}")
      assert %Prism{tag: :rectangle, pattern: [nil, :h], rest: false} = result
    end

    test "parses prism with all ignored positions (filter only)" do
      result = Parser.parse(":{:ok, _}")
      assert %Prism{tag: :ok, pattern: [nil], rest: false} = result
    end

    test "parses prism with rest pattern" do
      result = Parser.parse(":{:ok, ...}")
      assert %Prism{tag: :ok, pattern: nil, rest: true} = result
    end

    test "parses prism with tag only (implicit rest)" do
      result = Parser.parse(":{:ok}")
      assert %Prism{tag: :ok, pattern: nil, rest: true} = result
    end

    test "parses prism with three extractions" do
      result = Parser.parse(":{:point3d, x, y, z}")
      assert %Prism{tag: :point3d, pattern: [:x, :y, :z], rest: false} = result
    end

    test "parses prism with mixed extractions and ignores" do
      result = Parser.parse(":{:quad, a, _, c, _}")
      assert %Prism{tag: :quad, pattern: [:a, nil, :c, nil], rest: false} = result
    end
  end

  describe "Parser.parse/1 - prism in paths" do
    test "parses prism after key" do
      result = Parser.parse("result:{:ok, v}")

      assert %Sequence{
               lenses: [
                 %One{index: "result"},
                 %Prism{tag: :ok, pattern: [:v]}
               ]
             } = result
    end

    test "parses prism with dot separator" do
      result = Parser.parse("data.:{:ok, v}")

      assert %Sequence{
               lenses: [
                 %One{index: "data"},
                 %Prism{tag: :ok, pattern: [:v]}
               ]
             } = result
    end

    test "parses prism after bracket expression" do
      result = Parser.parse("[0]:{:ok, v}")

      assert %Sequence{
               lenses: [
                 %One{index: 0},
                 %Prism{tag: :ok, pattern: [:v]}
               ]
             } = result
    end

    test "parses prism after wildcard" do
      result = Parser.parse("[*]:{:ok, v}")

      assert %Sequence{
               lenses: [
                 %All{},
                 %Prism{tag: :ok, pattern: [:v]}
               ]
             } = result
    end

    test "parses path continuing after prism" do
      result = Parser.parse(":{:ok, v}.name")

      assert %Sequence{
               lenses: [
                 %Prism{tag: :ok, pattern: [:v]},
                 %One{index: "name"}
               ]
             } = result
    end

    test "parses complex path with prism in middle" do
      result = Parser.parse("results[*]:{:ok, v}.user.name")

      assert %Sequence{
               lenses: [
                 %One{index: "results"},
                 %All{},
                 %Prism{tag: :ok, pattern: [:v]},
                 %One{index: "user"},
                 %One{index: "name"}
               ]
             } = result
    end

    test "parses multiple prisms in path" do
      result = Parser.parse(":{:ok, v}:{:success, data}")

      assert %Sequence{
               lenses: [
                 %Prism{tag: :ok, pattern: [:v]},
                 %Prism{tag: :success, pattern: [:data]}
               ]
             } = result
    end
  end

  describe "Parser.parse/1 - prism with whitespace" do
    test "handles whitespace in pattern" do
      result = Parser.parse(":{:rectangle,  w ,  h }")
      assert %Prism{tag: :rectangle, pattern: [:w, :h], rest: false} = result
    end

    test "handles whitespace around ..." do
      result = Parser.parse(":{:ok,  ... }")
      assert %Prism{tag: :ok, pattern: nil, rest: true} = result
    end
  end

  describe "Parser.parse/1 - prism error cases" do
    test "raises on missing tag" do
      assert_raise RuntimeError, ~r/Expected :atom/, fn ->
        Parser.parse(":{, v}")
      end
    end

    test "raises on empty pattern element" do
      assert_raise RuntimeError, ~r/Expected element name/, fn ->
        Parser.parse(":{:ok, , v}")
      end
    end

    test "raises on unclosed prism" do
      assert_raise RuntimeError, ~r/Expected }/, fn ->
        Parser.parse(":{:ok, v")
      end
    end
  end

  describe "Parser.parse/1 - prism retagging with shorthand" do
    test "parses prism with shorthand retag" do
      result = Parser.parse(":{:ok, value} -> :success")

      assert %Prism{tag: :ok, pattern: [:value], output_tag: :success, output_pattern: nil} =
               result
    end

    test "parses prism with shorthand retag and multiple values" do
      result = Parser.parse(":{:rectangle, w, h} -> :box")

      assert %Prism{tag: :rectangle, pattern: [:w, :h], output_tag: :box, output_pattern: nil} =
               result
    end

    test "parses rest pattern with shorthand retag" do
      result = Parser.parse(":{:old_tag, ...} -> :new_tag")
      assert %Prism{tag: :old_tag, rest: true, output_tag: :new_tag, output_pattern: nil} = result
    end

    test "parses filter-only with shorthand retag" do
      result = Parser.parse(":{:ok, _} -> :success")
      assert %Prism{tag: :ok, pattern: [nil], output_tag: :success, output_pattern: nil} = result
    end

    test "parses shorthand retag with whitespace" do
      result = Parser.parse(":{:ok, v}  ->  :success")
      assert %Prism{tag: :ok, pattern: [:v], output_tag: :success, output_pattern: nil} = result
    end

    test "parses shorthand retag without spaces around arrow" do
      result = Parser.parse(":{:ok, v}->:success")
      assert %Prism{tag: :ok, pattern: [:v], output_tag: :success, output_pattern: nil} = result
    end
  end

  describe "Parser.parse/1 - prism retagging with assembly" do
    test "parses prism with explicit assembly reordering" do
      result = Parser.parse(":{:pair, a, b} -> :{:swapped, b, a}")

      assert %Prism{tag: :pair, pattern: [:a, :b], output_tag: :swapped, output_pattern: [:b, :a]} =
               result
    end

    test "parses prism with assembly dropping value" do
      result = Parser.parse(":{:point3d, x, y, z} -> :{:point2d, x, z}")

      assert %Prism{
               tag: :point3d,
               pattern: [:x, :y, :z],
               output_tag: :point2d,
               output_pattern: [:x, :z]
             } = result
    end

    test "parses prism with assembly duplicating value" do
      result = Parser.parse(":{:data, value} -> :{:double, value, value}")

      assert %Prism{
               tag: :data,
               pattern: [:value],
               output_tag: :double,
               output_pattern: [:value, :value]
             } = result
    end

    test "parses prism with assembly from non-contiguous extraction" do
      result = Parser.parse(":{:quad, a, _, c, _} -> :{:pair, c, a}")

      assert %Prism{
               tag: :quad,
               pattern: [:a, nil, :c, nil],
               output_tag: :pair,
               output_pattern: [:c, :a]
             } = result
    end

    test "parses prism with single value assembly" do
      result = Parser.parse(":{:ok, value} -> :{:success, value}")

      assert %Prism{tag: :ok, pattern: [:value], output_tag: :success, output_pattern: [:value]} =
               result
    end

    test "parses assembly with whitespace" do
      result = Parser.parse(":{:pair, a, b}  ->  :{:swapped,  b,  a}")

      assert %Prism{tag: :pair, pattern: [:a, :b], output_tag: :swapped, output_pattern: [:b, :a]} =
               result
    end
  end

  describe "Parser.parse/1 - retagged prism in paths" do
    test "parses retagged prism after key" do
      result = Parser.parse("result:{:ok, v} -> :success")

      assert %Sequence{
               lenses: [
                 %One{index: "result"},
                 %Prism{tag: :ok, pattern: [:v], output_tag: :success}
               ]
             } = result
    end

    test "parses path continuing after retagged prism" do
      result = Parser.parse(":{:ok, v} -> :success.name")

      assert %Sequence{
               lenses: [
                 %Prism{tag: :ok, pattern: [:v], output_tag: :success},
                 %One{index: "name"}
               ]
             } = result
    end

    test "parses complex path with retagged prism" do
      result = Parser.parse("items[*]:{:ok, v} -> :success.value")

      assert %Sequence{
               lenses: [
                 %One{index: "items"},
                 %All{},
                 %Prism{tag: :ok, pattern: [:v], output_tag: :success},
                 %One{index: "value"}
               ]
             } = result
    end
  end
end
