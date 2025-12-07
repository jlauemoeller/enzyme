defmodule Enzyme.ParserTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme.Parser

  alias Enzyme.All
  alias Enzyme.Filter
  alias Enzyme.One
  alias Enzyme.Parser
  alias Enzyme.Sequence
  alias Enzyme.Slice

  describe "parse/1 with simple keys" do
    test "parses a single key" do
      assert Parser.parse("foo") == %One{index: "foo"}
    end

    test "parses a dotted path" do
      assert Parser.parse("foo.bar.baz") == %Sequence{
               lenses: [
                 %One{index: "foo"},
                 %One{index: "bar"},
                 %One{index: "baz"}
               ]
             }
    end

    test "parses numeric strings as string keys" do
      assert Parser.parse("123") == %One{index: "123"}
    end

    test "parses empty string as a key" do
      assert Parser.parse("") == %One{index: ""}
    end

    test "parses keys with special characters" do
      assert Parser.parse("foo-bar") == %One{index: "foo-bar"}
      assert Parser.parse("foo_bar") == %One{index: "foo_bar"}
    end

    test "trims whitespace from keys" do
      assert Parser.parse("  foo  ") == %One{index: "foo"}
    end

    test "trims whitespace from keys in dotted paths" do
      assert Parser.parse("  foo  .  bar  .  baz  ") == %Sequence{
               lenses: [
                 %One{index: "foo"},
                 %One{index: "bar"},
                 %One{index: "baz"}
               ]
             }
    end
  end

  describe "parse/1 with wildcard [*]" do
    test "parses bracket wildcard" do
      assert Parser.parse("[*]") == %All{}
    end

    test "parses wildcard in a path" do
      assert Parser.parse("foo.[*]") == %Sequence{lenses: [%One{index: "foo"}, %All{}]}
    end

    test "parses wildcard without dot before bracket" do
      assert Parser.parse("foo[*]") == %Sequence{lenses: [%One{index: "foo"}, %All{}]}
    end

    test "parses wildcard at the beginning of a path" do
      assert Parser.parse("[*].bar") == %Sequence{lenses: [%All{}, %One{index: "bar"}]}
    end

    test "parses multiple wildcards in a path" do
      assert Parser.parse("[*].[*].[*]") == %Sequence{lenses: [%All{}, %All{}, %All{}]}
    end

    test "parses multiple wildcards without dots" do
      assert Parser.parse("[*][*][*]") == %Sequence{lenses: [%All{}, %All{}, %All{}]}
    end
  end

  describe "parse/1 with numerical indices [...]" do
    test "parses single index as One" do
      assert Parser.parse("[0]") == %One{index: 0}
    end

    test "parses single index with larger number" do
      assert Parser.parse("[42]") == %One{index: 42}
    end

    test "parses negative index" do
      assert Parser.parse("[-1]") == %One{index: -1}
    end

    test "parses multiple indices as Slice" do
      assert Parser.parse("[0,1,2]") == %Slice{indices: [0, 1, 2]}
    end

    test "parses two indices as Slice" do
      assert Parser.parse("[0,1]") == %Slice{indices: [0, 1]}
    end

    test "parses numerical indices in a path with dot" do
      assert Parser.parse("foo.[0].bar") == %Sequence{
               lenses: [
                 %One{index: "foo"},
                 %One{index: 0},
                 %One{index: "bar"}
               ]
             }
    end

    test "parses numerical indices in a path without dot" do
      assert Parser.parse("foo[0].bar") == %Sequence{
               lenses: [
                 %One{index: "foo"},
                 %One{index: 0},
                 %One{index: "bar"}
               ]
             }
    end

    test "parses multiple numerical index expressions in a path" do
      assert Parser.parse("[0][1][2]") == %Sequence{
               lenses: [
                 %One{index: 0},
                 %One{index: 1},
                 %One{index: 2}
               ]
             }
    end

    test "parses slice in a path" do
      assert Parser.parse("data[0,1,2].value") == %Sequence{
               lenses: [
                 %One{index: "data"},
                 %Slice{indices: [0, 1, 2]},
                 %One{index: "value"}
               ]
             }
    end

    test "trims whitespace in numerical indices" do
      assert Parser.parse("[ 0 ]") == %One{index: 0}
      assert Parser.parse("[ 0 , 1 , 2 ]") == %Slice{indices: [0, 1, 2]}
    end

    test "raises on float in brackets" do
      assert_raise RuntimeError, ~r/Expected integer but found 1\.5/, fn ->
        Parser.parse("[1.5]")
      end
    end
  end

  describe "parse/1 with string key indices [name]" do
    test "parses single string key as One" do
      assert Parser.parse("[foo]") == %One{index: "foo"}
    end

    test "parses multiple string keys as Slice" do
      assert Parser.parse("[foo,bar]") == %Slice{indices: ["foo", "bar"]}
    end

    test "parses three string keys as Slice" do
      assert Parser.parse("[a,b,c]") == %Slice{indices: ["a", "b", "c"]}
    end

    test "trims whitespace from string keys" do
      assert Parser.parse("[ foo ]") == %One{index: "foo"}
    end

    test "trims whitespace from multiple string keys" do
      assert Parser.parse("[ foo , bar , baz ]") == %Slice{indices: ["foo", "bar", "baz"]}
    end

    test "parses string key indices in a path with dot" do
      assert Parser.parse("data.[name].value") == %Sequence{
               lenses: [
                 %One{index: "data"},
                 %One{index: "name"},
                 %One{index: "value"}
               ]
             }
    end

    test "parses string key indices in a path without dot" do
      assert Parser.parse("data[name].value") == %Sequence{
               lenses: [
                 %One{index: "data"},
                 %One{index: "name"},
                 %One{index: "value"}
               ]
             }
    end

    test "parses slice of string keys in a path" do
      assert Parser.parse("users[name,email].format") == %Sequence{
               lenses: [
                 %One{index: "users"},
                 %Slice{indices: ["name", "email"]},
                 %One{index: "format"}
               ]
             }
    end

    test "parses keys with dots inside brackets" do
      # [foo.bar] keeps the dot as part of the name
      assert Parser.parse("[foo.bar]") == %One{index: "foo.bar"}
    end
  end

  describe "parse/1 with atom indices [:...]" do
    test "parses single atom" do
      assert Parser.parse("[:foo]") == %One{index: :foo}
    end

    test "parses atom with underscores" do
      assert Parser.parse("[:my_atom]") == %One{index: :my_atom}
    end

    test "parses multiple atoms as Slice" do
      assert Parser.parse("[:a,:b]") == %Slice{indices: [:a, :b]}
    end

    test "parses three atoms as Slice" do
      assert Parser.parse("[:a,:b,:c]") == %Slice{indices: [:a, :b, :c]}
    end

    test "parses atom in a path with dot" do
      assert Parser.parse("data.[:key].value") == %Sequence{
               lenses: [
                 %One{index: "data"},
                 %One{index: :key},
                 %One{index: "value"}
               ]
             }
    end

    test "parses atom in a path without dot" do
      assert Parser.parse("data[:key].value") == %Sequence{
               lenses: [
                 %One{index: "data"},
                 %One{index: :key},
                 %One{index: "value"}
               ]
             }
    end

    test "trims whitespace around atom" do
      assert Parser.parse("[: foo ]") == %One{index: :foo}
    end

    test "trims whitespace around multiple atoms" do
      assert Parser.parse("[: a , : b ]") == %Slice{indices: [:a, :b]}
    end

    test "parses atom with numbers" do
      assert Parser.parse("[:atom123]") == %One{index: :atom123}
    end

    test "raises on empty atom" do
      assert_raise RuntimeError, ~r/Expected atom name after :/, fn ->
        Parser.parse("[:]")
      end
    end

    test "raises on whitespace-only atom" do
      assert_raise RuntimeError, ~r/Expected atom name after :/, fn ->
        Parser.parse("[:  ]")
      end
    end
  end

  describe "parse/1 with filter expressions [?...]" do
    test "parses simple filter expression" do
      result = Parser.parse("[?active == true]")
      assert %Filter{predicate: pred} = result
      assert pred.(%{active: true}) == true
      assert pred.(%{active: false}) == false
    end

    test "parses filter with string comparison" do
      result = Parser.parse("[?name == 'test']")
      assert %Filter{predicate: pred} = result
      assert pred.(%{name: "test"}) == true
      assert pred.(%{name: "other"}) == false
    end

    test "parses filter in a path" do
      result = Parser.parse("users[?active == true]")
      assert %Sequence{lenses: [%One{index: "users"}, %Filter{predicate: pred}]} = result
      assert pred.(%{active: true}) == true
    end

    test "parses filter after wildcard" do
      result = Parser.parse("[*][?score == 100]")
      assert %Sequence{lenses: [%All{}, %Filter{predicate: pred}]} = result
      assert pred.(%{score: 100}) == true
    end

    test "parses multiple filters (stacked)" do
      result = Parser.parse("[*][?active == true][?role == 'admin']")

      assert %Sequence{lenses: [%All{}, %Filter{predicate: pred1}, %Filter{predicate: pred2}]} =
               result

      assert pred1.(%{active: true}) == true
      assert pred2.(%{role: "admin"}) == true
    end

    test "parses filter with self reference" do
      result = Parser.parse("[?@ == 42]")
      assert %Filter{predicate: pred} = result
      assert pred.(42) == true
      assert pred.(41) == false
    end

    test "parses filter with string equality operator" do
      result = Parser.parse("[?type ~~ 'book']")
      assert %Filter{predicate: pred} = result
      assert pred.(%{type: "book"}) == true
      assert pred.(%{type: :book}) == true
    end

    test "parses filter with inequality" do
      result = Parser.parse("[?status != 'closed']")
      assert %Filter{predicate: pred} = result
      assert pred.(%{status: "open"}) == true
      assert pred.(%{status: "closed"}) == false
    end

    test "raises on empty filter expression" do
      assert_raise RuntimeError, ~r/Expected filter expression after/, fn ->
        Parser.parse("[?]")
      end
    end
  end

  describe "parse/1 with complex paths" do
    test "combines wildcards and numerical indices" do
      assert Parser.parse("[*][0]") == %Sequence{lenses: [%All{}, %One{index: 0}]}
    end

    test "combines wildcards and string key indices" do
      assert Parser.parse("[*][name]") == %Sequence{lenses: [%All{}, %One{index: "name"}]}
    end

    test "combines all index types" do
      result = Parser.parse("data[*][0][name]")

      assert %Sequence{
               lenses: [
                 %One{index: "data"},
                 %All{},
                 %One{index: 0},
                 %One{index: "name"}
               ]
             } = result
    end

    test "parses deeply nested path" do
      assert Parser.parse("a.b.c.d.e") == %Sequence{
               lenses: [
                 %One{index: "a"},
                 %One{index: "b"},
                 %One{index: "c"},
                 %One{index: "d"},
                 %One{index: "e"}
               ]
             }
    end

    test "parses path with mixed slices" do
      assert Parser.parse("[0,1][a,b]") == %Sequence{
               lenses: [
                 %Slice{indices: [0, 1]},
                 %Slice{indices: ["a", "b"]}
               ]
             }
    end

    test "parses realistic JSON path" do
      assert Parser.parse("users[0].profile[name,email]") == %Sequence{
               lenses: [
                 %One{index: "users"},
                 %One{index: 0},
                 %One{index: "profile"},
                 %Slice{indices: ["name", "email"]}
               ]
             }
    end

    test "parses path selecting all items then specific field" do
      assert Parser.parse("items[*].price") == %Sequence{
               lenses: [
                 %One{index: "items"},
                 %All{},
                 %One{index: "price"}
               ]
             }
    end

    test "parses path with atom key" do
      assert Parser.parse("map[:key].value") == %Sequence{
               lenses: [
                 %One{index: "map"},
                 %One{index: :key},
                 %One{index: "value"}
               ]
             }
    end

    test "combines multiple wildcards" do
      assert Parser.parse("[*][*][*][*]") == %Sequence{
               lenses: [
                 %All{},
                 %All{},
                 %All{},
                 %All{}
               ]
             }
    end
  end

  describe "parse/1 error cases for numerical indices" do
    test "raises on non-integer in brackets starting with digit" do
      assert_raise RuntimeError, ~r/Expected integer but found 0abc/, fn ->
        Parser.parse("[0abc]")
      end
    end

    test "raises on mixed integers and non-integers in brackets" do
      assert_raise RuntimeError, ~r/Expected integer but found x/, fn ->
        Parser.parse("[0,x,2]")
      end
    end

    test "raises on float in brackets" do
      assert_raise RuntimeError, ~r/Expected integer but found 1\.5/, fn ->
        Parser.parse("[1.5]")
      end
    end

    test "raises on invalid integer format" do
      assert_raise RuntimeError, ~r/Expected integer but found 1abc/, fn ->
        Parser.parse("[1abc]")
      end
    end

    test "raises on unclosed bracket" do
      assert_raise RuntimeError, ~r/Expected \] at end of index list/, fn ->
        Parser.parse("[0")
      end
    end
  end

  describe "parse/1 error cases for string key indices" do
    test "raises on empty name in multiple names" do
      assert_raise RuntimeError, ~r/Expected name but found empty string/, fn ->
        Parser.parse("[foo, ,bar]")
      end
    end

    test "raises on only whitespace names" do
      assert_raise RuntimeError, ~r/Expected name but found empty string/, fn ->
        Parser.parse("[  ,  ]")
      end
    end

    test "raises on unclosed bracket" do
      assert_raise RuntimeError, ~r/Expected \] at end of key list/, fn ->
        Parser.parse("[foo")
      end
    end
  end

  describe "parse/1 error cases for empty brackets" do
    test "raises on empty brackets" do
      assert_raise RuntimeError, ~r/Empty brackets not allowed/, fn ->
        Parser.parse("[]")
      end
    end
  end

  describe "parse/1 with atom path separator :" do
    test "parses leading : as atom key" do
      assert Parser.parse(":foo") == %One{index: :foo}
    end

    test "parses :a:b as atom:atom" do
      assert Parser.parse(":a:b") == %Sequence{
               lenses: [
                 %One{index: :a},
                 %One{index: :b}
               ]
             }
    end

    test "parses a:b as string:atom" do
      assert Parser.parse("a:b") == %Sequence{
               lenses: [
                 %One{index: "a"},
                 %One{index: :b}
               ]
             }
    end

    test "parses :a.b as atom.string" do
      assert Parser.parse(":a.b") == %Sequence{
               lenses: [
                 %One{index: :a},
                 %One{index: "b"}
               ]
             }
    end

    test "parses a.b:c as string.string:atom" do
      assert Parser.parse("a.b:c") == %Sequence{
               lenses: [
                 %One{index: "a"},
                 %One{index: "b"},
                 %One{index: :c}
               ]
             }
    end

    test "parses :user:profile:settings as all atoms" do
      assert Parser.parse(":user:profile:settings") == %Sequence{
               lenses: [
                 %One{index: :user},
                 %One{index: :profile},
                 %One{index: :settings}
               ]
             }
    end

    test "parses mixed separators in complex path" do
      assert Parser.parse("data:items[*]:name") == %Sequence{
               lenses: [
                 %One{index: "data"},
                 %One{index: :items},
                 %All{},
                 %One{index: :name}
               ]
             }
    end

    test "parses atom path after bracket" do
      assert Parser.parse("[0]:name") == %Sequence{
               lenses: [
                 %One{index: 0},
                 %One{index: :name}
               ]
             }
    end

    test "parses atom path with iso" do
      result = Parser.parse(":user:age::integer")

      assert %Sequence{
               lenses: [
                 %One{index: :user},
                 %One{index: :age},
                 %Enzyme.IsoRef{name: :integer}
               ]
             } = result
    end

    test "parses string:atom with iso" do
      result = Parser.parse("count:value::integer")

      assert %Sequence{
               lenses: [
                 %One{index: "count"},
                 %One{index: :value},
                 %Enzyme.IsoRef{name: :integer}
               ]
             } = result
    end

    test "parses iso followed by atom separator" do
      result = Parser.parse("data::json:field")

      assert %Sequence{
               lenses: [
                 %One{index: "data"},
                 %Enzyme.IsoRef{name: :json},
                 %One{index: :field}
               ]
             } = result
    end

    test "parses atom key with underscores" do
      assert Parser.parse(":my_key:other_key") == %Sequence{
               lenses: [
                 %One{index: :my_key},
                 %One{index: :other_key}
               ]
             }
    end

    test "parses atom key with numbers" do
      assert Parser.parse(":key1:key2") == %Sequence{
               lenses: [
                 %One{index: :key1},
                 %One{index: :key2}
               ]
             }
    end

    test "does not confuse : with :: (iso)" do
      result = Parser.parse(":a::integer")

      assert %Sequence{
               lenses: [
                 %One{index: :a},
                 %Enzyme.IsoRef{name: :integer}
               ]
             } = result
    end

    test "does not confuse : with :{ (prism)" do
      result = Parser.parse(":data:{:ok, v}")

      assert %Sequence{
               lenses: [
                 %One{index: :data},
                 %Enzyme.Prism{tag: :ok}
               ]
             } = result
    end
  end

  describe "parse/1 edge cases" do
    test "parses consecutive dots as empty string keys" do
      assert Parser.parse("a..b") == %Sequence{
               lenses: [
                 %One{index: "a"},
                 %One{index: ""},
                 %One{index: "b"}
               ]
             }
    end

    test "parses path starting with dot" do
      assert Parser.parse(".foo") == %Sequence{
               lenses: [
                 %One{index: ""},
                 %One{index: "foo"}
               ]
             }
    end

    test "parses path ending with dot" do
      assert Parser.parse("foo.") == %Sequence{
               lenses: [
                 %One{index: "foo"},
                 %One{index: ""}
               ]
             }
    end

    test "handles brackets followed by more path" do
      assert Parser.parse("[0].foo[1]") == %Sequence{
               lenses: [
                 %One{index: 0},
                 %One{index: "foo"},
                 %One{index: 1}
               ]
             }
    end

    test "handles string keys followed by more path" do
      assert Parser.parse("[a].foo[b]") == %Sequence{
               lenses: [
                 %One{index: "a"},
                 %One{index: "foo"},
                 %One{index: "b"}
               ]
             }
    end
  end
end
