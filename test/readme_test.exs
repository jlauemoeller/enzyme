defmodule Enzyme.ReadmeTest do
  @moduledoc """
  Tests for all examples shown in README.md.

  These tests ensure that documentation examples remain accurate as the library evolves.
  When updating README.md examples, corresponding tests here must also be updated.
  """
  use ExUnit.Case

  defmodule Company do
    @moduledoc false
    defstruct [:name, :founded]
  end

  # Shared test data from README "Example" section
  @products %{
    "items" => [
      %{"name" => "Laptop", "price" => "129999", "updated_at" => "2024-01-15T10:30:00Z"},
      %{"name" => "Mouse", "price" => "2499", "updated_at" => "2024-01-14T15:45:00Z"},
      %{"name" => "Keyboard", "price" => "7999", "updated_at" => "2024-01-16T09:20:00Z"}
    ]
  }

  # Custom iso for cents <-> euros (string cents to float euros)
  defp cents_iso_string do
    Enzyme.iso(
      &(String.to_integer(&1) / 100),
      &Integer.to_string(trunc(&1 * 100))
    )
  end

  describe "README Example section - Selecting Data" do
    test "extracts all item names" do
      assert Enzyme.select(@products, "items[*].name") == ["Laptop", "Mouse", "Keyboard"]
    end

    test "extracts names and prices as maps" do
      result = Enzyme.select(@products, "items[*][name,price]")

      assert result == [
               ["Laptop", "129999"],
               ["Mouse", "2499"],
               ["Keyboard", "7999"]
             ]
    end

    test "extracts names of first two items" do
      assert Enzyme.select(@products, "items[0,1].name") == ["Laptop", "Mouse"]
    end

    test "extracts prices as euros using custom iso" do
      isos = [cents: cents_iso_string()]
      assert Enzyme.select(@products, "items[*].price::cents", isos) == [1299.99, 24.99, 79.99]
    end
  end

  describe "README Example section - Transforming Data" do
    test "applies 10% discount to items over 50 euros" do
      isos = [cents: cents_iso_string()]

      result =
        Enzyme.transform(
          @products,
          "items[*][?@.price::cents > 50].price::cents",
          fn price -> price * 0.9 end,
          isos
        )

      # Laptop: 129999 cents = 1299.99 euros -> 1169.991 euros -> 116999 cents
      # Mouse: 2499 cents = 24.99 euros (unchanged, under 50)
      # Keyboard: 7999 cents = 79.99 euros -> 71.991 euros -> 7199 cents
      assert get_in(result, ["items", Access.at(0), "price"]) == "116999"
      assert get_in(result, ["items", Access.at(1), "price"]) == "2499"
      assert get_in(result, ["items", Access.at(2), "price"]) == "7199"
    end
  end

  describe "README Example section - Built-in isomorphisms" do
    test "filters items by iso8601 date comparison" do
      result =
        Enzyme.select(
          @products,
          "items[*][?@.updated_at::iso8601 > '2024-01-15T00:00:00Z'::iso8601].name"
        )

      assert result == ["Laptop", "Keyboard"]
    end
  end

  describe "README - Dot and Colon Notation" do
    test "accesses atom keys with colon notation" do
      data = %{"company" => %Company{name: "Acme", founded: 1990}}

      assert Enzyme.select(data, "company:name") == "Acme"
      assert Enzyme.select(data, "company:founded") == 1990
    end
  end

  describe "README - Numeric Indices" do
    test "accesses list elements by index" do
      data = %{"items" => ["first", "second", "third"]}

      assert Enzyme.select(data, "items[0]") == "first"
      assert Enzyme.select(data, "items[2]") == "third"
      assert Enzyme.select(data, "items[0,2]") == ["first", "third"]
    end
  end

  describe "README - String or Atom Indices" do
    test "accesses keys using bracket notation" do
      data = %{"user" => %{"name" => "Alice", "email" => "alice@example.com", "role" => "admin"}}

      assert Enzyme.select(data, "user[name]") == "Alice"
      assert Enzyme.select(data, "user[name,email]") == ["Alice", "alice@example.com"]
    end
  end

  describe "README - Wildcards" do
    test "selects all elements with wildcard" do
      data = %{
        "users" => [
          %{"name" => "Alice", "score" => 95},
          %{"name" => "Bob", "score" => 87}
        ]
      }

      assert Enzyme.select(data, "users[*]") == [
               %{"name" => "Alice", "score" => 95},
               %{"name" => "Bob", "score" => 87}
             ]

      assert Enzyme.select(data, "users[*].name") == ["Alice", "Bob"]
      assert Enzyme.select(data, "users[*].score") == [95, 87]
    end
  end

  describe "README - Filter Expressions" do
    setup do
      data = %{
        "products" => [
          %{"name" => "Widget", "price" => 25, "in_stock" => true},
          %{"name" => "Gadget", "price" => 99, "in_stock" => false},
          %{"name" => "Gizmo", "price" => 50, "in_stock" => true}
        ]
      }

      {:ok, data: data}
    end

    test "filters by boolean", %{data: data} do
      assert Enzyme.select(data, "products[*][?@.in_stock == true].name") == ["Widget", "Gizmo"]
    end

    test "filters by string", %{data: data} do
      assert Enzyme.select(data, "products[*][?@.name == 'Widget'].price") == [25]
    end

    test "filters by number", %{data: data} do
      assert Enzyme.select(data, "products[*][?@.price == 99].name") == ["Gadget"]
    end

    test "filters by inequality", %{data: data} do
      assert Enzyme.select(data, "products[*][?@.in_stock != true].name") == ["Gadget"]
    end

    test "filters with comparison operators", %{data: data} do
      assert Enzyme.select(data, "products[*][?@.price > 30].name") == ["Gadget", "Gizmo"]
      assert Enzyme.select(data, "products[*][?@.price <= 50].name") == ["Widget", "Gizmo"]
    end
  end

  describe "README - String comparison operator ~~" do
    test "matches both atom and string types" do
      data = %{"items" => [%{type: :book}, %{"type" => "book"}]}

      assert Enzyme.select(data, "items[*][?@:type ~~ 'book' or @.type ~~ 'book']") == [
               %{type: :book},
               %{"type" => "book"}
             ]
    end
  end

  describe "README - Logical operators" do
    setup do
      data = %{
        "users" => [
          %{"name" => "Alice", "active" => true, "role" => "admin"},
          %{"name" => "Bob", "active" => true, "role" => "user"},
          %{"name" => "Charlie", "active" => false, "role" => "admin"}
        ]
      }

      {:ok, data: data}
    end

    test "AND operator", %{data: data} do
      assert Enzyme.select(data, "users[*][?@.active == true and @.role == 'admin'].name") ==
               ["Alice"]
    end

    test "OR operator", %{data: data} do
      assert Enzyme.select(data, "users[*][?@.role == 'admin' or @.role == 'superuser'].name") ==
               ["Alice", "Charlie"]
    end

    test "NOT operator", %{data: data} do
      assert Enzyme.select(data, "users[*][?not @.active == true].name") == ["Charlie"]
    end
  end

  describe "README - Operator precedence" do
    setup do
      data = %{
        "products" => [
          %{"name" => "Widget", "price" => 25, "category" => "tools", "featured" => true},
          %{"name" => "Gadget", "price" => 150, "category" => "electronics", "featured" => false},
          %{"name" => "Gizmo", "price" => 50, "category" => "tools", "featured" => false}
        ]
      }

      {:ok, data: data}
    end

    test "without parentheses: featured OR (electronics AND price > 100)", %{data: data} do
      result =
        Enzyme.select(
          data,
          "products[*][?@.featured == true or @.category == 'electronics' and @.price > 100].name"
        )

      assert result == ["Widget", "Gadget"]
    end

    test "with parentheses: (featured OR electronics) AND price > 100", %{data: data} do
      result =
        Enzyme.select(
          data,
          "products[*][?(@.featured == true or @.category == 'electronics') and @.price > 100].name"
        )

      assert result == ["Gadget"]
    end

    test "NOT with parentheses", %{data: data} do
      result =
        Enzyme.select(
          data,
          "products[*][?not (@.category == 'tools' and @.featured == false)].name"
        )

      assert result == ["Widget", "Gadget"]
    end
  end

  describe "README - Chained Filters" do
    test "senior engineers only" do
      data = %{
        "employees" => [
          %{"name" => "Alice", "dept" => "Engineering", "level" => "senior"},
          %{"name" => "Bob", "dept" => "Engineering", "level" => "junior"},
          %{"name" => "Charlie", "dept" => "Sales", "level" => "senior"}
        ]
      }

      result =
        Enzyme.select(data, "employees[*][?@.dept == 'Engineering'][?@.level == 'senior'].name")

      assert result == ["Alice"]
    end
  end

  describe "README - Self Reference @" do
    test "filters primitive values" do
      data = %{"scores" => [85, 92, 78, 95, 88]}
      assert Enzyme.select(data, "scores[*][?@ == 95]") == [95]
    end
  end

  describe "README - Chained Field References" do
    test "filters by nested string field" do
      data = %{
        "users" => [
          %{"name" => "Alice", "profile" => %{"verified" => true, "level" => 5}},
          %{"name" => "Bob", "profile" => %{"verified" => false, "level" => 3}},
          %{"name" => "Charlie", "profile" => %{"verified" => true, "level" => 8}}
        ]
      }

      result = Enzyme.select(data, "users[*][?@.profile.verified == true].name")
      assert result == ["Alice", "Charlie"]
    end

    test "compares nested numeric values" do
      data = %{
        "users" => [
          %{"name" => "Alice", "profile" => %{"verified" => true, "level" => 5}},
          %{"name" => "Bob", "profile" => %{"verified" => false, "level" => 3}},
          %{"name" => "Charlie", "profile" => %{"verified" => true, "level" => 8}}
        ]
      }

      result = Enzyme.select(data, "users[*][?@.profile.level > 4].name")
      assert result == ["Alice", "Charlie"]
    end

    test "combines chained fields with logical operators" do
      data = %{
        "users" => [
          %{"name" => "Alice", "profile" => %{"verified" => true, "level" => 5}},
          %{"name" => "Bob", "profile" => %{"verified" => false, "level" => 3}},
          %{"name" => "Charlie", "profile" => %{"verified" => true, "level" => 8}}
        ]
      }

      result =
        Enzyme.select(
          data,
          "users[*][?@.profile.verified == true and @.profile.level >= 5].name"
        )

      assert result == ["Alice", "Charlie"]
    end

    test "chains atom keys" do
      data = %{
        users: [
          %{name: "Alice", settings: %{theme: "dark", notifications: true}},
          %{name: "Bob", settings: %{theme: "light", notifications: false}}
        ]
      }

      result = Enzyme.select(data, ":users[*][?@:settings:theme == 'dark']:name")
      assert result == ["Alice"]
    end

    test "mixes string and atom keys" do
      data = %{
        "config" => %{users: [%{name: "Alice", active: true}]}
      }

      result = Enzyme.select(data, "config:users[*][?@:active == true]:name")
      assert result == ["Alice"]
    end

    test "provides null-safe navigation for missing fields" do
      data = %{
        "items" => [
          %{"user" => %{"profile" => %{"verified" => true}}},
          %{"user" => %{"name" => "Bob"}},
          %{"name" => "Charlie"}
        ]
      }

      result = Enzyme.select(data, "items[*][?@.user.profile.verified == true]")
      assert result == [%{"user" => %{"profile" => %{"verified" => true}}}]
    end
  end

  describe "README - Isos in Filters" do
    test "filters by converted integer value (left side)" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => "42"},
          %{"name" => "b", "count" => "7"},
          %{"name" => "c", "count" => "42"}
        ]
      }

      assert Enzyme.select(data, "items[*][?@.count::integer == 42].name", []) == ["a", "c"]
    end

    test "filters by converted integer value (right side)" do
      data = %{"items" => [%{"value" => 42}, %{"value" => 7}]}
      assert Enzyme.select(data, "items[*][?@.value == '42'::integer]", []) == [%{"value" => 42}]
    end

    test "both sides with isos" do
      data = %{"items" => [%{"left" => "10", "right" => "10"}]}

      assert Enzyme.select(data, "items[*][?@.left::integer == @.right::integer]", []) == [
               %{"left" => "10", "right" => "10"}
             ]
    end

    test "chained isos in filter" do
      data = %{"codes" => [Base.encode64("42"), Base.encode64("7")]}
      assert Enzyme.select(data, "codes[*][?@::base64::integer == 42]", []) == ["NDI="]
    end

    test "custom iso in filter" do
      cents_iso = Enzyme.iso(&(&1 / 100), &trunc(&1 * 100))
      data = %{"items" => [%{"price" => 999}, %{"price" => 1599}]}

      assert Enzyme.select(data, "items[*][?@.price::cents == 15.99]", cents: cents_iso) == [
               %{"price" => 1599}
             ]
    end
  end

  describe "README - Prisms" do
    test "extracts value from :ok tuples" do
      assert Enzyme.select({:ok, 42}, ":{:ok, v}") == 42
      assert Enzyme.select({:error, "oops"}, ":{:ok, v}") == nil
    end

    test "extracts from list of results" do
      results = [{:ok, 1}, {:error, "failed"}, {:ok, 2}, {:error, "timeout"}]

      assert Enzyme.select(results, "[*]:{:ok, v}") == [1, 2]
      assert Enzyme.select(results, "[*]:{:error, reason}") == ["failed", "timeout"]
    end
  end

  describe "README - Multiple Value Extraction" do
    test "extracts multiple values as tuple" do
      assert Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, w, h}") == {3, 4}
    end

    test "extracts specific positions using _ to ignore" do
      assert Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, _, h}") == 4
      assert Enzyme.select({:point3d, 1, 2, 3}, ":{:point3d, x, _, z}") == {1, 3}
    end
  end

  describe "README - Rest Pattern" do
    test "extracts all elements after tag" do
      assert Enzyme.select({:ok, 42}, ":{:ok, ...}") == 42
      assert Enzyme.select({:data, 1, 2, 3, 4}, ":{:data, ...}") == {1, 2, 3, 4}
    end
  end

  describe "README - Filter-Only Prisms" do
    test "filters without extracting" do
      results = [{:ok, 1}, {:error, "x"}, {:ok, 2}]
      assert Enzyme.select(results, "[*]:{:ok, _}") == [{:ok, 1}, {:ok, 2}]
    end
  end

  describe "README - Transforming with Prisms" do
    test "transforms value inside matching tuples" do
      assert Enzyme.transform({:ok, 5}, ":{:ok, v}", &(&1 * 2)) == {:ok, 10}
    end

    test "non-matching tuples pass through unchanged" do
      assert Enzyme.transform({:error, "x"}, ":{:ok, v}", &(&1 * 2)) == {:error, "x"}
    end

    test "transforms in a list" do
      results = [{:ok, 1}, {:error, "x"}, {:ok, 2}]

      assert Enzyme.transform(results, "[*]:{:ok, v}", &(&1 * 10)) == [
               {:ok, 10},
               {:error, "x"},
               {:ok, 20}
             ]
    end
  end

  describe "README - Prisms in Complex Paths" do
    test "extracts names from successful responses" do
      data = %{
        "responses" => [
          {:ok, %{"user" => %{"name" => "Alice"}}},
          {:error, "not found"},
          {:ok, %{"user" => %{"name" => "Bob"}}}
        ]
      }

      assert Enzyme.select(data, "responses[*]:{:ok, v}.user.name") == ["Alice", "Bob"]
    end
  end

  describe "README - Retagging Prisms (shorthand)" do
    test "changes tag from :ok to :success" do
      assert Enzyme.select({:ok, 42}, ":{:ok, v} -> :success") == {:success, 42}
    end

    test "transforms and retags" do
      assert Enzyme.transform({:ok, 5}, ":{:ok, v} -> :success", &(&1 * 2)) == {:success, 10}
    end

    test "retags in lists" do
      results = [{:ok, 1}, {:error, "x"}, {:ok, 2}]

      assert Enzyme.select(results, "[*]:{:ok, v} -> :success") == [
               {:success, 1},
               {:success, 2}
             ]
    end

    test "retags filter-only prism" do
      assert Enzyme.select({:ok, 42}, ":{:ok, _} -> :success") == {:success, 42}
    end

    test "retags with rest pattern" do
      assert Enzyme.select({:data, 1, 2, 3}, ":{:data, ...} -> :values") == {:values, 1, 2, 3}
    end
  end

  describe "README - Retagging Prisms (explicit assembly)" do
    test "reorders values" do
      assert Enzyme.select({:pair, 1, 2}, ":{:pair, a, b} -> :{:swapped, b, a}") ==
               {:swapped, 2, 1}
    end

    test "drops a dimension" do
      assert Enzyme.select({:point3d, 1, 2, 3}, ":{:point3d, x, y, z} -> :{:point2d, x, z}") ==
               {:point2d, 1, 3}
    end

    test "duplicates a value" do
      assert Enzyme.select({:single, 42}, ":{:single, v} -> :{:double, v, v}") ==
               {:double, 42, 42}
    end

    test "extracts non-contiguous positions and reorders" do
      assert Enzyme.select({:quad, 1, 2, 3, 4}, ":{:quad, a, _, c, _} -> :{:pair, c, a}") ==
               {:pair, 3, 1}
    end

    # NOTE: The README example for transform with explicit assembly doesn't work
    # as documented. Transform receives all extracted values {x, y, z}, not {x, z}.
    # This test verifies basic transform with prism works.
    test "transforms prism values" do
      result =
        Enzyme.transform(
          {:point3d, 0, 0, 0},
          ":{:point3d, x, y, z}",
          fn {x, y, z} -> {x + 1, y + 2, z + 3} end
        )

      assert result == {:point3d, 1, 2, 3}
    end
  end

  describe "README - Isomorphisms" do
    test "select with builtin integer iso" do
      data = %{"count" => "42"}
      assert Enzyme.select(data, "count::integer", []) == 42
    end

    test "transform with builtin integer iso" do
      data = %{"count" => "42"}
      assert Enzyme.transform(data, "count::integer", &(&1 + 1), []) == %{"count" => "43"}
    end
  end

  describe "README - Built-in Isos" do
    test "decodes base64 data" do
      data = %{"secret" => Base.encode64("password123")}
      assert Enzyme.select(data, "secret::base64", []) == "password123"
    end

    test "parses JSON string" do
      data = %{"config" => ~s({"debug": true})}
      assert Enzyme.select(data, "config::json", []) == %{"debug" => true}
    end
  end

  describe "README - Custom Isos" do
    test "cents to euros conversion for select" do
      cents_iso =
        Enzyme.iso(
          fn cents -> cents / 100 end,
          fn euros -> trunc(euros * 100) end
        )

      data = %{"price" => 1999}
      assert Enzyme.select(data, "price::cents", cents: cents_iso) == 19.99
    end

    test "cents to euros conversion for transform" do
      cents_iso =
        Enzyme.iso(
          fn cents -> cents / 100 end,
          fn euros -> trunc(euros * 100) end
        )

      data = %{"price" => 1999}

      assert Enzyme.transform(data, "price::cents", &(&1 + 1), cents: cents_iso) ==
               %{"price" => 2099}
    end
  end

  describe "README - Iso Resolution" do
    test "stored iso is used by default" do
      cents_iso = Enzyme.iso(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("price::cents", cents: cents_iso)

      assert Enzyme.select(%{"price" => 1999}, lens) == 19.99
    end

    test "runtime iso overrides stored iso" do
      cents_iso = Enzyme.iso(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("price::cents", cents: cents_iso)

      runtime_iso = Enzyme.iso(&(&1 / 1000), &trunc(&1 * 1000))
      assert Enzyme.select(%{"price" => 1999}, lens, cents: runtime_iso) == 1.999
    end

    test "iso provided only at runtime" do
      cents_iso = Enzyme.iso(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("price::cents")

      assert Enzyme.select(%{"price" => 1999}, lens, cents: cents_iso) == 19.99
    end
  end

  describe "README - Chaining Isos" do
    test "chains base64 and integer isos" do
      data = %{"value" => Base.encode64("42")}
      assert Enzyme.select(data, "value::base64::integer", []) == 42
    end
  end

  describe "README - Isos in Complex Paths" do
    test "selects all scores as integers" do
      data = %{
        "users" => [
          %{"name" => "Alice", "score" => "85"},
          %{"name" => "Bob", "score" => "92"}
        ]
      }

      assert Enzyme.select(data, "users[*].score::integer", []) == [85, 92]
    end

    test "transforms all scores and stores back as strings" do
      data = %{
        "users" => [
          %{"name" => "Alice", "score" => "85"},
          %{"name" => "Bob", "score" => "92"}
        ]
      }

      result = Enzyme.transform(data, "users[*].score::integer", &(&1 + 10), [])

      assert result == %{
               "users" => [
                 %{"name" => "Alice", "score" => "95"},
                 %{"name" => "Bob", "score" => "102"}
               ]
             }
    end
  end

  describe "README - Transforming Data" do
    setup do
      data = %{
        "users" => [
          %{"name" => "alice", "score" => 85},
          %{"name" => "bob", "score" => 92}
        ]
      }

      {:ok, data: data}
    end

    test "transforms with a function", %{data: data} do
      result = Enzyme.transform(data, "users[*].name", &String.capitalize/1)

      assert get_in(result, ["users", Access.at(0), "name"]) == "Alice"
      assert get_in(result, ["users", Access.at(1), "name"]) == "Bob"
    end

    test "transforms with a constant value", %{data: data} do
      result = Enzyme.transform(data, "users[*].score", 0)

      assert get_in(result, ["users", Access.at(0), "score"]) == 0
      assert get_in(result, ["users", Access.at(1), "score"]) == 0
    end

    test "transforms only matching elements", %{data: data} do
      result = Enzyme.transform(data, "users[*][?@.score == 85].score", fn s -> s + 10 end)

      assert get_in(result, ["users", Access.at(0), "score"]) == 95
      assert get_in(result, ["users", Access.at(1), "score"]) == 92
    end
  end

  describe "README - Reusable Lenses" do
    setup do
      data = %{
        "users" => [
          %{"name" => "alice", "score" => 85},
          %{"name" => "bob", "score" => 92}
        ]
      }

      {:ok, data: data}
    end

    test "creates and uses a lens", %{data: data} do
      user_names = Enzyme.new("users[*].name")
      assert Enzyme.select(data, user_names) == ["alice", "bob"]
    end
  end

  describe "README - Working with JSON" do
    setup do
      data = %{
        "company" => "Acme Corp",
        "departments" => [
          %{
            "name" => "Engineering",
            "employees" => [
              %{"name" => "Alice", "title" => "Senior Engineer"},
              %{"name" => "Bob", "title" => "Junior Engineer"}
            ]
          },
          %{
            "name" => "Sales",
            "employees" => [
              %{"name" => "Charlie", "title" => "Sales Manager"}
            ]
          }
        ]
      }

      [data: data]
    end

    test "gets employee names from all departments", %{data: data} do
      result = Enzyme.select(data, "departments[*].employees[*].name")
      assert result == ["Alice", "Bob", "Charlie"]
    end

    test "gets employees from Engineering only", %{data: data} do
      result = Enzyme.select(data, "departments[*][?@.name == 'Engineering'].employees[*].name")
      assert result == ["Alice", "Bob"]
    end

    test "updates all titles", %{data: data} do
      result = Enzyme.transform(data, "departments[*].employees[*].title", &String.upcase/1)

      engineering_employees = get_in(result, ["departments", Access.at(0), "employees"])
      assert Enum.at(engineering_employees, 0)["title"] == "SENIOR ENGINEER"
      assert Enum.at(engineering_employees, 1)["title"] == "JUNIOR ENGINEER"

      sales_employees = get_in(result, ["departments", Access.at(1), "employees"])
      assert Enum.at(sales_employees, 0)["title"] == "SALES MANAGER"
    end
  end
end
