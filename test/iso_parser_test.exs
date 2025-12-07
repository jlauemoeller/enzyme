defmodule IsoParserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Enzyme.All
  alias Enzyme.Iso
  alias Enzyme.IsoRef
  alias Enzyme.One
  alias Enzyme.Sequence

  describe "parsing :: syntax" do
    test "parses simple key with iso" do
      lens = Enzyme.new("value::integer")
      assert %Sequence{lenses: [%One{index: "value"}, %IsoRef{name: :integer}]} = lens
    end

    test "parses nested path with iso" do
      lens = Enzyme.new("user.age::integer")

      assert %Sequence{lenses: [%One{index: "user"}, %One{index: "age"}, %IsoRef{name: :integer}]} =
               lens
    end

    test "parses iso after bracket index" do
      lens = Enzyme.new("items[0]::integer")

      assert %Sequence{lenses: [%One{index: "items"}, %One{index: 0}, %IsoRef{name: :integer}]} =
               lens
    end

    test "parses iso after wildcard" do
      lens = Enzyme.new("items[*]::integer")
      assert %Sequence{lenses: [%One{index: "items"}, %All{}, %IsoRef{name: :integer}]} = lens
    end

    test "parses chained isos" do
      lens = Enzyme.new("data::base64::integer")

      assert %Sequence{
               lenses: [
                 %One{index: "data"},
                 %IsoRef{name: :base64},
                 %IsoRef{name: :integer}
               ]
             } = lens
    end

    test "parses iso at start of path" do
      lens = Enzyme.new("value::atom")
      assert %Sequence{lenses: [%One{index: "value"}, %IsoRef{name: :atom}]} = lens
    end

    test "parses path continuing after iso" do
      lens = Enzyme.new("config::json.debug")

      assert %Sequence{
               lenses: [
                 %One{index: "config"},
                 %IsoRef{name: :json},
                 %One{index: "debug"}
               ]
             } = lens
    end

    test "parses complex path with multiple isos" do
      lens = Enzyme.new("data::base64::json.items[*].count::integer")

      assert %Sequence{
               lenses: [
                 %One{index: "data"},
                 %IsoRef{name: :base64},
                 %IsoRef{name: :json},
                 %One{index: "items"},
                 %All{},
                 %One{index: "count"},
                 %IsoRef{name: :integer}
               ]
             } = lens
    end
  end

  describe "iso storage in lens" do
    test "stores opts in Sequence when provided" do
      custom_iso = Iso.new(& &1, & &1)
      lens = Enzyme.new("value::custom", custom: custom_iso)

      # IsoRef in lenses, iso stored in opts
      assert %Sequence{lenses: [%One{}, %IsoRef{name: :custom}], opts: opts} = lens
      assert %Iso{} = Keyword.get(opts, :custom)
    end

    test "leaves iso as IsoRef when not in opts" do
      lens = Enzyme.new("value::custom")

      assert %Sequence{lenses: [%One{}, %IsoRef{name: :custom}], opts: []} = lens
    end

    test "leaves builtin as IsoRef (resolved at runtime)" do
      lens = Enzyme.new("value::integer")

      assert %Sequence{lenses: [%One{}, %IsoRef{name: :integer}]} = lens
    end

    test "stores custom iso in opts, all refs remain as IsoRef" do
      custom_iso = Iso.new(&String.upcase/1, &String.downcase/1)
      lens = Enzyme.new("name::custom.data::integer", custom: custom_iso)

      assert %Sequence{
               lenses: [
                 %One{index: "name"},
                 %IsoRef{name: :custom},
                 %One{index: "data"},
                 %IsoRef{name: :integer}
               ],
               opts: opts
             } = lens

      assert %Iso{} = Keyword.get(opts, :custom)
    end
  end

  describe "iso name parsing" do
    test "parses simple iso names" do
      lens = Enzyme.new("x::integer")
      assert %Sequence{lenses: [_, %IsoRef{name: :integer}]} = lens
    end

    test "parses snake_case iso names" do
      lens = Enzyme.new("x::my_custom_iso")
      assert %Sequence{lenses: [_, %IsoRef{name: :my_custom_iso}]} = lens
    end

    test "parses iso names with numbers" do
      lens = Enzyme.new("x::base64")
      assert %Sequence{lenses: [_, %IsoRef{name: :base64}]} = lens
    end
  end

  describe "edge cases" do
    test "iso immediately after bracket" do
      lens = Enzyme.new("[0]::integer")
      assert %Sequence{lenses: [%One{index: 0}, %IsoRef{name: :integer}]} = lens
    end

    test "iso after string key in bracket" do
      lens = Enzyme.new("[key]::integer")
      assert %Sequence{lenses: [%One{index: "key"}, %IsoRef{name: :integer}]} = lens
    end

    test "iso after atom key in bracket" do
      lens = Enzyme.new("[:key]::integer")
      assert %Sequence{lenses: [%One{index: :key}, %IsoRef{name: :integer}]} = lens
    end

    test "multiple consecutive isos" do
      lens = Enzyme.new("x::a::b::c")

      refs =
        lens.lenses
        |> Enum.filter(fn
          %IsoRef{} -> true
          _ -> false
        end)

      assert length(refs) == 3
      assert Enum.map(refs, & &1.name) == [:a, :b, :c]
    end
  end
end
