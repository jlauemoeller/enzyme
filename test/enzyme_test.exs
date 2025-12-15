defmodule EnzymeTest do
  @moduledoc false
  use ExUnit.Case
  doctest Enzyme

  alias Enzyme.Sequence

  @data %{
    "name" => "Acme, Inc",
    "active" => true,
    "employee_count" => 150,
    "offices" => [
      %{
        "name" => "HQ",
        "tz" => "PST",
        "active" => true,
        "employee_count" => 100,
        "address" => [
          "Main Street 1",
          "Beverly Hills",
          "CA",
          "90210"
        ]
      },
      %{
        "name" => "East",
        "tz" => "EST",
        "active" => true,
        "employee_count" => 50,
        "address" => [
          "2142 Madison Ave",
          "New York",
          "NY",
          "10037"
        ]
      },
      %{
        "name" => "Closed",
        "tz" => "CST",
        "active" => false,
        "employee_count" => 0,
        "address" => [
          "123 Old Road",
          "Chicago",
          "IL",
          "60601"
        ]
      }
    ]
  }

  describe "select/2 with simple keys" do
    test "selects top-level string key" do
      assert Enzyme.select(@data, "name") == "Acme, Inc"
    end

    test "selects top-level boolean key" do
      assert Enzyme.select(@data, "active") == true
    end

    test "selects top-level integer key" do
      assert Enzyme.select(@data, "employee_count") == 150
    end

    test "selects nested key with dot notation" do
      assert Enzyme.select(@data, "offices.[0].name") == "HQ"
    end

    test "returns nil for missing key" do
      assert Enzyme.select(@data, "missing") == nil
    end
  end

  describe "select/2 with numeric indices [n]" do
    test "selects first element" do
      assert Enzyme.select(@data, "offices[0].name") == "HQ"
    end

    test "selects second element" do
      assert Enzyme.select(@data, "offices[1].name") == "East"
    end

    test "selects last element" do
      assert Enzyme.select(@data, "offices[2].name") == "Closed"
    end

    test "selects nested array element" do
      assert Enzyme.select(@data, "offices[0].address[0]") == "Main Street 1"
    end

    test "selects deeply nested element" do
      assert Enzyme.select(@data, "offices[1].address[3]") == "10037"
    end

    test "returns nil for out of bounds index" do
      assert Enzyme.select(@data, "offices[99]") == nil
    end
  end

  describe "select/2 with numeric slices [n,m]" do
    test "selects first two elements" do
      assert Enzyme.select(@data, "offices[0,1].name") == ["HQ", "East"]
    end

    test "selects specific indices" do
      assert Enzyme.select(@data, "offices[0,2].name") == ["HQ", "Closed"]
    end

    test "selects all three by indices" do
      assert Enzyme.select(@data, "offices[0,1,2].name") == ["HQ", "East", "Closed"]
    end

    test "selects nested array slices" do
      assert Enzyme.select(@data, "offices[0].address[0,1]") == ["Main Street 1", "Beverly Hills"]
    end

    test "selects multiple fields from multiple elements" do
      assert Enzyme.select(@data, "offices[0,1].tz") == ["PST", "EST"]
    end
  end

  describe "select/2 with wildcard [*]" do
    test "selects all elements" do
      assert Enzyme.select(@data, "offices[*].name") == ["HQ", "East", "Closed"]
    end

    test "selects specific index from all elements" do
      assert Enzyme.select(@data, "offices[*].address[2]") == ["CA", "NY", "IL"]
    end

    test "selects all from single element" do
      assert Enzyme.select(@data, "offices[0].address") == [
               "Main Street 1",
               "Beverly Hills",
               "CA",
               "90210"
             ]
    end

    test "selects all nested elements" do
      assert Enzyme.select(@data, "offices[*].address") == [
               ["Main Street 1", "Beverly Hills", "CA", "90210"],
               ["2142 Madison Ave", "New York", "NY", "10037"],
               ["123 Old Road", "Chicago", "IL", "60601"]
             ]
    end

    test "selects all from single element with trailing wildcard" do
      assert Enzyme.select(@data, "offices[*].address[*]") == [
               "Main Street 1",
               "Beverly Hills",
               "CA",
               "90210",
               "2142 Madison Ave",
               "New York",
               "NY",
               "10037",
               "123 Old Road",
               "Chicago",
               "IL",
               "60601"
             ]
    end
  end

  describe "select/2 with string key brackets [key]" do
    test "selects single string key" do
      assert Enzyme.select(@data, "offices[0][name]") == "HQ"
    end

    test "selects multiple string keys" do
      assert Enzyme.select(@data, "offices[0][name,tz]") == ["HQ", "PST"]
    end

    test "selects multiple keys from all elements" do
      assert Enzyme.select(@data, "offices[*][name,tz]") == [
               ["HQ", "PST"],
               ["East", "EST"],
               ["Closed", "CST"]
             ]
    end

    test "selects three keys" do
      assert Enzyme.select(@data, "offices[0][name,tz,active]") == ["HQ", "PST", true]
    end
  end

  describe "select/2 with filters [?expr] using ==" do
    test "filters by string equality" do
      assert Enzyme.select(@data, "offices[*][?@.tz == 'PST'].name") == ["HQ"]
    end

    test "filters by boolean equality" do
      assert Enzyme.select(@data, "offices[*][?@.active == true].name") == ["HQ", "East"]
    end

    test "filters by integer equality" do
      assert Enzyme.select(@data, "offices[*][?@.employee_count == 50].name") == ["East"]
    end

    test "filters with no matches returns empty list" do
      assert Enzyme.select(@data, "offices[*][?@.tz == 'MISSING'].name") == []
    end

    test "filters with double-quoted string" do
      assert Enzyme.select(@data, "offices[*][?@.tz == \"EST\"].name") == ["East"]
    end

    test "filters by false boolean" do
      assert Enzyme.select(@data, "offices[*][?@.active == false].name") == ["Closed"]
    end

    test "filters by zero integer" do
      assert Enzyme.select(@data, "offices[*][?@.employee_count == 0].name") == ["Closed"]
    end
  end

  describe "select/2 with filters [?expr] using !=" do
    test "filters by string inequality" do
      assert Enzyme.select(@data, "offices[*][?@.tz != 'PST'].name") == ["East", "Closed"]
    end

    test "filters by boolean inequality" do
      assert Enzyme.select(@data, "offices[*][?@.active != true].name") == ["Closed"]
    end

    test "filters by integer inequality" do
      assert Enzyme.select(@data, "offices[*][?@.employee_count != 0].name") == ["HQ", "East"]
    end

    test "filters excluding multiple values" do
      # Get offices that are not in EST
      assert Enzyme.select(@data, "offices[*][?@.tz != 'EST'].name") == ["HQ", "Closed"]
    end
  end

  describe "select/2 with filters [?expr] using ~~ (string equality)" do
    test "compares string to string" do
      assert Enzyme.select(@data, "offices[*][?@.tz ~~ 'PST'].name") == ["HQ"]
    end

    test "compares integer to string representation" do
      assert Enzyme.select(@data, "offices[*][?@.employee_count ~~ '100'].name") == ["HQ"]
    end

    test "compares boolean to string representation" do
      assert Enzyme.select(@data, "offices[*][?@.active ~~ 'true'].name") == ["HQ", "East"]
    end
  end

  describe "select/2 with filters [?expr] using !~ (string inequality)" do
    test "filters by string inequality" do
      assert Enzyme.select(@data, "offices[*][?@.tz !~ 'PST'].name") == ["East", "Closed"]
    end

    test "filters integer by string inequality" do
      assert Enzyme.select(@data, "offices[*][?@.employee_count !~ '0'].name") == ["HQ", "East"]
    end
  end

  describe "select/2 with stacked filters" do
    test "filters by two conditions (AND logic)" do
      # Active offices not in PST timezone
      assert Enzyme.select(@data, "offices[*][?@.active == true][?@.tz != 'PST'].name") == ["East"]
    end

    test "filters by three conditions" do
      # Active offices, not in PST, with more than 10 employees
      result =
        Enzyme.select(
          @data,
          "offices[*][?@.active == true][?@.tz != 'PST'][?@.employee_count != 0].name"
        )

      assert result == ["East"]
    end

    test "stacked filters that eliminate all results" do
      # Active offices in CST (none exist)
      assert Enzyme.select(@data, "offices[*][?@.active == true][?@.tz == 'CST'].name") == []
    end

    test "stacked filters on nested data" do
      # Get city from active offices in PST
      result = Enzyme.select(@data, "offices[*][?@.active == true][?@.tz == 'PST'].address[1]")
      assert result == ["Beverly Hills"]
    end
  end

  describe "select/2 with filter on self @" do
    test "filters array elements by self value in flat list" do
      # Filter a flat list of addresses
      assert Enzyme.select(@data, "offices[0].address[*][?@ == '90210']") == ["90210"]
    end

    test "filters with no matches returns empty" do
      assert Enzyme.select(@data, "offices[0].address[*][?@ == 'MISSING']") == []
    end

    test "filters with @ field access" do
      # Same as direct field access
      assert Enzyme.select(@data, "offices[*][?@.tz == 'PST'].name") == ["HQ"]
    end
  end

  describe "select/2 with complex paths" do
    test "combines wildcard, index, and filter" do
      # Get address line 0 for active offices
      result = Enzyme.select(@data, "offices[*][?@.active == true].address[0]")
      assert result == ["Main Street 1", "2142 Madison Ave"]
    end

    test "combines slice with filter" do
      # Get names from first two offices that are active
      result = Enzyme.select(@data, "offices[0,1][?@.active == true].name")
      assert result == ["HQ", "East"]
    end

    test "filter then select multiple keys" do
      result = Enzyme.select(@data, "offices[*][?@.tz == 'PST'][name,employee_count]")
      assert result == [["HQ", 100]]
    end
  end

  describe "transform/3 with simple paths" do
    test "transforms top-level key with function" do
      result = Enzyme.transform(@data, "name", &String.upcase/1)
      assert result["name"] == "ACME, INC"
    end

    test "transforms top-level key with value" do
      result = Enzyme.transform(@data, "name", "New Name")
      assert result["name"] == "New Name"
    end

    test "transforms nested key" do
      result = Enzyme.transform(@data, "offices[0].name", &String.downcase/1)
      assert get_in(result, ["offices", Access.at(0), "name"]) == "hq"
    end
  end

  describe "transform/3 with numeric indices" do
    test "transforms single indexed element" do
      result = Enzyme.transform(@data, "offices[0].employee_count", fn c -> c + 10 end)
      assert get_in(result, ["offices", Access.at(0), "employee_count"]) == 110
    end

    test "transforms deeply nested indexed element" do
      result = Enzyme.transform(@data, "offices[0].address[0]", &String.upcase/1)
      assert get_in(result, ["offices", Access.at(0), "address", Access.at(0)]) == "MAIN STREET 1"
    end
  end

  describe "transform/3 with numeric slices" do
    test "transforms multiple indexed elements" do
      result = Enzyme.transform(@data, "offices[0,1].name", &String.downcase/1)
      assert get_in(result, ["offices", Access.at(0), "name"]) == "hq"
      assert get_in(result, ["offices", Access.at(1), "name"]) == "east"
      # Third element unchanged
      assert get_in(result, ["offices", Access.at(2), "name"]) == "Closed"
    end
  end

  describe "transform/3 with wildcard [*]" do
    test "transforms all elements" do
      result = Enzyme.transform(@data, "offices[*].name", &String.upcase/1)
      assert get_in(result, ["offices", Access.at(0), "name"]) == "HQ"
      assert get_in(result, ["offices", Access.at(1), "name"]) == "EAST"
      assert get_in(result, ["offices", Access.at(2), "name"]) == "CLOSED"
    end

    test "transforms all nested elements" do
      result = Enzyme.transform(@data, "offices[*].address[*]", &String.upcase/1)

      assert get_in(result, ["offices", Access.at(0), "address"]) == [
               "MAIN STREET 1",
               "BEVERLY HILLS",
               "CA",
               "90210"
             ]
    end

    test "transforms specific index in all elements" do
      result = Enzyme.transform(@data, "offices[*].address[0]", &String.upcase/1)
      assert get_in(result, ["offices", Access.at(0), "address", Access.at(0)]) == "MAIN STREET 1"

      assert get_in(result, ["offices", Access.at(1), "address", Access.at(0)]) ==
               "2142 MADISON AVE"

      # Other addresses unchanged
      assert get_in(result, ["offices", Access.at(0), "address", Access.at(1)]) == "Beverly Hills"
    end
  end

  describe "transform/3 with string key brackets" do
    test "transforms single string key" do
      result = Enzyme.transform(@data, "offices[0][name]", &String.upcase/1)
      assert get_in(result, ["offices", Access.at(0), "name"]) == "HQ"
    end

    test "transforms multiple string keys" do
      result = Enzyme.transform(@data, "offices[0][name,tz]", &String.downcase/1)
      assert get_in(result, ["offices", Access.at(0), "name"]) == "hq"
      assert get_in(result, ["offices", Access.at(0), "tz"]) == "pst"
      # Other keys unchanged
      assert get_in(result, ["offices", Access.at(0), "active"]) == true
    end
  end

  describe "transform/3 with filters" do
    test "transforms only filtered elements" do
      result = Enzyme.transform(@data, "offices[*][?@.active == true].name", &String.upcase/1)
      # Active offices transformed
      assert get_in(result, ["offices", Access.at(0), "name"]) == "HQ"
      assert get_in(result, ["offices", Access.at(1), "name"]) == "EAST"
      # Inactive office unchanged
      assert get_in(result, ["offices", Access.at(2), "name"]) == "Closed"
    end

    test "transforms with filter by string" do
      result =
        Enzyme.transform(@data, "offices[*][?@.tz == 'PST'].employee_count", fn c -> c * 2 end)

      # HQ doubled
      assert get_in(result, ["offices", Access.at(0), "employee_count"]) == 200
      # Others unchanged
      assert get_in(result, ["offices", Access.at(1), "employee_count"]) == 50
      assert get_in(result, ["offices", Access.at(2), "employee_count"]) == 0
    end

    test "transforms with stacked filters" do
      result =
        Enzyme.transform(
          @data,
          "offices[*][?@.active == true][?@.tz != 'PST'].name",
          &String.downcase/1
        )

      # HQ unchanged (filtered out by tz)
      assert get_in(result, ["offices", Access.at(0), "name"]) == "HQ"
      # East transformed (active and not PST)
      assert get_in(result, ["offices", Access.at(1), "name"]) == "east"
      # Closed unchanged (filtered out by active)
      assert get_in(result, ["offices", Access.at(2), "name"]) == "Closed"
    end

    test "transforms with filter that matches nothing" do
      result = Enzyme.transform(@data, "offices[*][?@.tz == 'MISSING'].name", &String.upcase/1)
      # Everything unchanged
      assert get_in(result, ["offices", Access.at(0), "name"]) == "HQ"
      assert get_in(result, ["offices", Access.at(1), "name"]) == "East"
      assert get_in(result, ["offices", Access.at(2), "name"]) == "Closed"
    end
  end

  describe "transform/3 with value replacement" do
    test "replaces with constant value" do
      result = Enzyme.transform(@data, "offices[*].active", true)
      assert get_in(result, ["offices", Access.at(2), "active"]) == true
    end

    test "replaces filtered elements with value" do
      result = Enzyme.transform(@data, "offices[*][?@.active == false].active", true)
      # Inactive office now active
      assert get_in(result, ["offices", Access.at(2), "active"]) == true
      # Others still true
      assert get_in(result, ["offices", Access.at(0), "active"]) == true
    end
  end

  describe "Lens creation" do
    test "new/1 creates a Enzyme from path string" do
      lens = Enzyme.new("offices[*].name")
      assert %Sequence{lenses: selectors} = lens
      assert length(selectors) == 3
    end
  end

  describe "edge cases" do
    test "empty path looks up empty string key" do
      # Empty path parses to One{index: ""} which looks up key ""
      assert Enzyme.select(@data, "") == nil
      assert Enzyme.select(%{"" => "empty key value"}, "") == "empty key value"
    end

    test "whitespace in keys is trimmed" do
      assert Enzyme.select(@data, "  name  ") == "Acme, Inc"
      assert Enzyme.select(@data, "  offices  ") == @data["offices"]
    end

    test "whitespace in bracket expressions is trimmed" do
      assert Enzyme.select(@data, "offices[ 0 ].name") == "HQ"
      assert Enzyme.select(@data, "offices[ 0 , 1 ].name") == ["HQ", "East"]
    end

    test "filter with whitespace" do
      assert Enzyme.select(@data, "offices[*][? @.tz == 'PST' ].name") == ["HQ"]
    end

    test "chained missing keys return nil" do
      assert Enzyme.select(@data, "offices[0].nonexistent") == nil
    end
  end

  describe "select/2 with atom path separator :" do
    @struct_data %{
      user: %{
        name: "Alice",
        profile: %{
          age: 30,
          email: "alice@example.com"
        }
      }
    }

    @mixed_data %{
      "config" => %{
        settings: %{
          debug: true
        }
      }
    }

    test "selects single atom key" do
      assert Enzyme.select(@struct_data, ":user") == @struct_data.user
    end

    test "selects nested atom keys" do
      assert Enzyme.select(@struct_data, ":user:name") == "Alice"
    end

    test "selects deeply nested atom keys" do
      assert Enzyme.select(@struct_data, ":user:profile:age") == 30
    end

    test "selects mixed string:atom path" do
      assert Enzyme.select(@mixed_data, "config:settings:debug") == true
    end

    test "selects atom:string mixed path" do
      data = %{user: %{"name" => "Bob"}}
      assert Enzyme.select(data, ":user.name") == "Bob"
    end

    test "works with wildcards" do
      data = %{
        items: [
          %{name: "a", value: 1},
          %{name: "b", value: 2}
        ]
      }

      assert Enzyme.select(data, ":items[*]:name") == ["a", "b"]
    end

    test "works with filters" do
      data = %{
        items: [
          %{name: "a", active: true},
          %{name: "b", active: false}
        ]
      }

      assert Enzyme.select(data, ":items[*][?@:active == true]:name") == ["a"]
    end

    test "works with numeric indices" do
      data = %{items: [%{name: "first"}, %{name: "second"}]}
      assert Enzyme.select(data, ":items[0]:name") == "first"
    end
  end

  describe "transform/3 with atom path separator :" do
    test "transforms value at atom path" do
      data = %{user: %{name: "alice"}}
      result = Enzyme.transform(data, ":user:name", &String.upcase/1)
      assert result == %{user: %{name: "ALICE"}}
    end

    test "transforms values through wildcard with atom path" do
      data = %{items: [%{value: 1}, %{value: 2}]}
      result = Enzyme.transform(data, ":items[*]:value", &(&1 * 10))
      assert result == %{items: [%{value: 10}, %{value: 20}]}
    end

    test "transforms mixed string:atom path" do
      data = %{"config" => %{enabled: false}}
      result = Enzyme.transform(data, "config:enabled", fn _ -> true end)
      assert result == %{"config" => %{enabled: true}}
    end
  end
end
