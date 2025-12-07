defmodule FilterIsoTest do
  use ExUnit.Case, async: true

  alias Enzyme.Iso

  describe "filter with builtin isos" do
    test "filter with ::integer iso and equality" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => "42"},
          %{"name" => "b", "count" => "7"},
          %{"name" => "c", "count" => "42"}
        ]
      }

      result = Enzyme.select(data, "items[*][?count::integer == 42].name", [])
      assert result == ["a", "c"]
    end

    test "filter with ::float iso and equality" do
      data = %{
        "items" => [
          %{"name" => "a", "price" => "9.99"},
          %{"name" => "b", "price" => "15.50"},
          %{"name" => "c", "price" => "9.99"}
        ]
      }

      result = Enzyme.select(data, "items[*][?price::float == 9.99].name", [])
      assert result == ["a", "c"]
    end

    test "filter with inequality comparison" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => "10"},
          %{"name" => "b", "count" => "20"},
          %{"name" => "c", "count" => "10"}
        ]
      }

      result = Enzyme.select(data, "items[*][?count::integer != 10].name", [])
      assert result == ["b"]
    end

    test "filter with ::atom iso" do
      data = %{
        "items" => [
          %{"name" => "a", "status" => "active"},
          %{"name" => "b", "status" => "inactive"},
          %{"name" => "c", "status" => "active"}
        ]
      }

      result = Enzyme.select(data, "items[*][?status::atom == :active].name", [])
      assert result == ["a", "c"]
    end
  end

  describe "filter with chained isos" do
    test "filter with ::base64::integer chain" do
      forty_two = Base.encode64("42")
      seven = Base.encode64("7")

      data = %{
        "items" => [
          %{"name" => "a", "code" => forty_two},
          %{"name" => "b", "code" => seven},
          %{"name" => "c", "code" => forty_two}
        ]
      }

      result = Enzyme.select(data, "items[*][?code::base64::integer == 42].name", [])
      assert result == ["a", "c"]
    end
  end

  describe "filter with custom isos" do
    test "filter with custom iso provided at runtime" do
      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))

      data = %{
        "items" => [
          %{"name" => "cheap", "price" => 999},
          %{"name" => "exact", "price" => 1000},
          %{"name" => "expensive", "price" => 1599}
        ]
      }

      # Filter items where price in dollars == 10.0 (1000 cents)
      result = Enzyme.select(data, "items[*][?price::cents == 10.0].name", cents: cents_iso)
      assert result == ["exact"]
    end

    test "filter with custom iso resolved at parse time" do
      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("items[*][?price::cents == 15.99].name", cents: cents_iso)

      data = %{
        "items" => [
          %{"name" => "cheap", "price" => 999},
          %{"name" => "match", "price" => 1599}
        ]
      }

      result = Enzyme.select(data, lens)
      assert result == ["match"]
    end
  end

  describe "filter with self reference and iso" do
    test "self reference with ::integer iso" do
      data = %{"codes" => ["42", "7", "100"]}

      result = Enzyme.select(data, "codes[*][?@::integer == 42]", [])
      assert result == ["42"]
    end

    test "self reference with chained isos" do
      target = Base.encode64("42")
      data = %{"values" => [Base.encode64("50"), target, Base.encode64("99")]}

      result = Enzyme.select(data, "values[*][?@::base64::integer == 42]", [])
      assert result == [target]
    end
  end

  describe "filter iso resolution" do
    test "unresolved iso raises at runtime" do
      data = %{"items" => [%{"value" => 42}]}

      assert_raise ArgumentError, ~r/Iso 'unknown' is not resolved/, fn ->
        Enzyme.select(data, "items[*][?value::unknown == 10]", [])
      end
    end

    test "isos resolved at parse time are locked in" do
      iso1 = Iso.new(&(&1 * 2), &div(&1, 2))

      # Iso provided at parse time - gets baked into the lens
      lens = Enzyme.new("items[*][?value::custom == 60].name", custom: iso1)

      data = %{
        "items" => [
          # 30 * 2 = 60 ✓
          %{"name" => "a", "value" => 30},
          # 6 * 2 = 12 ✗
          %{"name" => "b", "value" => 6},
          # 20 * 2 = 40 ✗
          %{"name" => "c", "value" => 20}
        ]
      }

      # Uses the baked-in iso (doubles values) -> matches "a"
      result = Enzyme.select(data, lens, [])
      assert result == ["a"]
    end

    test "IsoRef can be resolved at runtime" do
      iso = Iso.new(&(&1 * 10), &div(&1, 10))

      # No iso provided at parse time - creates IsoRef
      lens = Enzyme.new("items[*][?value::custom == 60].name")

      data = %{
        "items" => [
          # 30 * 10 = 300 ✗
          %{"name" => "a", "value" => 30},
          # 6 * 10 = 60 ✓
          %{"name" => "b", "value" => 6},
          # 20 * 10 = 200 ✗
          %{"name" => "c", "value" => 20}
        ]
      }

      # Provides iso at runtime -> matches "b" (6*10=60)
      result = Enzyme.select(data, lens, custom: iso)
      assert result == ["b"]
    end
  end

  describe "filter with iso and transform" do
    test "transform filtered elements" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => "5"},
          %{"name" => "b", "count" => "15"},
          %{"name" => "c", "count" => "5"}
        ]
      }

      # Double the name of items where count == 15
      result =
        Enzyme.transform(
          data,
          "items[*][?count::integer == 15].name",
          &String.duplicate(&1, 2),
          []
        )

      assert result == %{
               "items" => [
                 %{"name" => "a", "count" => "5"},
                 %{"name" => "bb", "count" => "15"},
                 %{"name" => "c", "count" => "5"}
               ]
             }
    end
  end

  describe "filter iso edge cases" do
    test "filter with no matches returns empty list" do
      data = %{"items" => [%{"value" => "1"}, %{"value" => "2"}]}

      result = Enzyme.select(data, "items[*][?value::integer == 999].value", [])
      assert result == []
    end

    test "filter with all matches" do
      data = %{"items" => [%{"value" => "42"}, %{"value" => "42"}]}

      result = Enzyme.select(data, "items[*][?value::integer == 42].value", [])
      assert result == ["42", "42"]
    end

    test "multiple stacked filters with isos" do
      data = %{
        "items" => [
          %{"count" => "10", "status" => "active"},
          %{"count" => "20", "status" => "active"},
          %{"count" => "10", "status" => "inactive"},
          %{"count" => "30", "status" => "inactive"}
        ]
      }

      # Items where count == 10 AND status::atom == :active
      result =
        Enzyme.select(data, "items[*][?count::integer == 10][?status::atom == :active]", [])

      assert result == [%{"count" => "10", "status" => "active"}]
    end

    test "iso with string equality operator" do
      data = %{
        "items" => [
          %{"name" => "a", "code" => "42"},
          %{"name" => "b", "code" => "7"}
        ]
      }

      # Using ~~ string equality with iso
      result = Enzyme.select(data, "items[*][?code::integer ~~ '42'].name", [])
      assert result == ["a"]
    end
  end

  describe "filter with isos on right-side operands" do
    test "string literal with iso" do
      data = %{
        "items" => [
          %{"name" => "a", "value" => 42},
          %{"name" => "b", "value" => 7},
          %{"name" => "c", "value" => 42}
        ]
      }

      # Compare integer field to string literal converted to integer
      result = Enzyme.select(data, "items[*][?value == '42'::integer].name", [])
      assert result == ["a", "c"]
    end

    test "numeric literal with iso (identity for demonstration)" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => "42"},
          %{"name" => "b", "count" => "7"},
          %{"name" => "c", "count" => "42"}
        ]
      }

      # Integer literal converted to string via custom iso
      str_iso = Iso.new(&Integer.to_string/1, &String.to_integer/1)
      result = Enzyme.select(data, "items[*][?count == 42::to_str].name", to_str: str_iso)
      assert result == ["a", "c"]
    end

    test "both sides with isos" do
      data = %{
        "items" => [
          %{"name" => "a", "left" => "10", "right" => "10"},
          %{"name" => "b", "left" => "20", "right" => "10"},
          %{"name" => "c", "left" => "10", "right" => "20"}
        ]
      }

      # Both sides converted to integers for comparison
      result = Enzyme.select(data, "items[*][?left::integer == right::integer].name", [])
      assert result == ["a"]
    end

    test "chained isos on right-side literal" do
      # Target: base64 of "42"
      target = Base.encode64("42")

      data = %{
        "items" => [
          %{"name" => "a", "code" => target},
          %{"name" => "b", "code" => Base.encode64("7")},
          %{"name" => "c", "code" => target}
        ]
      }

      # Compare: field (base64→string) == literal (already string)
      # Both get decoded from base64 to plain string for comparison
      result = Enzyme.select(data, "items[*][?code::base64 == '42'].name", [])
      assert result == ["a", "c"]
    end

    test "comparison operators with iso on right side" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => 5},
          %{"name" => "b", "count" => 15},
          %{"name" => "c", "count" => 25}
        ]
      }

      # Count > '10' converted to integer
      result = Enzyme.select(data, "items[*][?count > '10'::integer].name", [])
      assert result == ["b", "c"]
    end

    test "logical operators with iso on right side" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => 5, "active" => true},
          %{"name" => "b", "count" => 15, "active" => true},
          %{"name" => "c", "count" => 15, "active" => false}
        ]
      }

      # count >= '10'::integer AND active == true
      result =
        Enzyme.select(data, "items[*][?count >= '10'::integer and active == true].name", [])

      assert result == ["b"]
    end

    test "boolean literal with iso (unusual but supported)" do
      data = %{
        "items" => [
          %{"name" => "a", "flag" => "true"},
          %{"name" => "b", "flag" => "false"}
        ]
      }

      # Convert boolean literal to string for comparison
      bool_to_str = Iso.new(&Atom.to_string/1, &String.to_atom/1)

      result =
        Enzyme.select(data, "items[*][?flag == true::bool_str].name", bool_str: bool_to_str)

      assert result == ["a"]
    end

    test "atom literal with iso" do
      data = %{
        "items" => [
          %{"name" => "a", "status" => "active"},
          %{"name" => "b", "status" => "inactive"}
        ]
      }

      # Compare string field to atom literal converted to string
      atom_to_str = Iso.new(&Atom.to_string/1, &String.to_atom/1)

      result =
        Enzyme.select(data, "items[*][?status == :active::atom_str].name", atom_str: atom_to_str)

      assert result == ["a"]
    end

    test "transform with iso on right side in filter" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => 5},
          %{"name" => "b", "count" => 15},
          %{"name" => "c", "count" => 25}
        ]
      }

      # Uppercase names where count > '10' converted to integer
      result =
        Enzyme.transform(data, "items[*][?count > '10'::integer].name", &String.upcase/1, [])

      assert result == %{
               "items" => [
                 %{"name" => "a", "count" => 5},
                 %{"name" => "B", "count" => 15},
                 %{"name" => "C", "count" => 25}
               ]
             }
    end

    test "unresolved iso on right side raises at runtime" do
      data = %{"items" => [%{"value" => 42}]}

      assert_raise ArgumentError, ~r/Iso 'unknown' is not resolved/, fn ->
        Enzyme.select(data, "items[*][?value == '10'::unknown]", [])
      end
    end
  end

  describe "parser integration" do
    test "expression parser stores unresolved isos" do
      expr = Enzyme.ExpressionParser.parse("field::custom == 42")

      assert Enzyme.ExpressionParser.has_unresolved_isos?(expr)
    end

    test "expression parser always creates IsoRef (resolution at runtime)" do
      iso = Iso.new(& &1, & &1)
      expr = Enzyme.ExpressionParser.parse("field::custom == 42", custom: iso)

      # Even with opts, isos are stored as IsoRef (resolved at runtime)
      assert Enzyme.ExpressionParser.has_unresolved_isos?(expr)
    end

    test "expression parser handles builtin iso names" do
      expr = Enzyme.ExpressionParser.parse("field::integer == 42")

      # Builtin isos are not resolved at parse time, only at runtime
      assert Enzyme.ExpressionParser.has_unresolved_isos?(expr)
    end

    test "expression parser detects isos on right side" do
      expr = Enzyme.ExpressionParser.parse("field == '42'::integer")

      assert Enzyme.ExpressionParser.has_unresolved_isos?(expr)
    end

    test "expression parser detects isos on both sides" do
      expr = Enzyme.ExpressionParser.parse("left::integer == right::float")

      assert Enzyme.ExpressionParser.has_unresolved_isos?(expr)
    end
  end
end
