defmodule Enzyme.LogicalOperatorTest do
  @moduledoc false
  use ExUnit.Case

  describe "logical operators in filters" do
    test "and operator" do
      data = %{
        "users" => [
          %{"name" => "Alice", "active" => true, "role" => "admin"},
          %{"name" => "Bob", "active" => true, "role" => "user"},
          %{"name" => "Charlie", "active" => false, "role" => "admin"}
        ]
      }

      # Active admins only
      result = Enzyme.select(data, "users[*][?@.active == true and @.role == 'admin'].name")
      assert result == ["Alice"]
    end

    test "or operator" do
      data = %{
        "users" => [
          %{"name" => "Alice", "role" => "admin"},
          %{"name" => "Bob", "role" => "superuser"},
          %{"name" => "Charlie", "role" => "user"}
        ]
      }

      # Admins or superusers
      result = Enzyme.select(data, "users[*][?@.role == 'admin' or @.role == 'superuser'].name")
      assert result == ["Alice", "Bob"]
    end

    test "not operator" do
      data = %{
        "items" => [
          %{"name" => "a", "deleted" => false},
          %{"name" => "b", "deleted" => true},
          %{"name" => "c", "deleted" => false}
        ]
      }

      # Non-deleted items
      result = Enzyme.select(data, "items[*][?not @.deleted == true].name")
      assert result == ["a", "c"]
    end

    test "parentheses grouping" do
      data = %{
        "products" => [
          %{"name" => "Widget", "price" => 25, "category" => "tools", "featured" => true},
          %{"name" => "Gadget", "price" => 150, "category" => "electronics", "featured" => false},
          %{"name" => "Gizmo", "price" => 50, "category" => "tools", "featured" => false},
          %{"name" => "Thing", "price" => 200, "category" => "electronics", "featured" => true}
        ]
      }

      # Featured products OR (electronics over $100)
      result =
        Enzyme.select(
          data,
          "products[*][?@.featured == true or (@.category == 'electronics' and @.price > 100)].name"
        )

      assert result == ["Widget", "Gadget", "Thing"]
    end

    test "complex filter with comparison operators" do
      data = %{
        "employees" => [
          %{"name" => "Alice", "score" => 95, "dept" => "Engineering"},
          %{"name" => "Bob", "score" => 72, "dept" => "Engineering"},
          %{"name" => "Charlie", "score" => 88, "dept" => "Sales"},
          %{"name" => "Diana", "score" => 65, "dept" => "Sales"}
        ]
      }

      # Engineering with score >= 80 or Sales with score >= 85
      result =
        Enzyme.select(
          data,
          "employees[*][?(@.dept == 'Engineering' and @.score >= 80) or (@.dept == 'Sales' and @.score >= 85)].name"
        )

      assert result == ["Alice", "Charlie"]
    end

    test "not with parentheses" do
      data = %{
        "items" => [
          %{"name" => "a", "status" => "active", "type" => "regular"},
          %{"name" => "b", "status" => "inactive", "type" => "premium"},
          %{"name" => "c", "status" => "active", "type" => "premium"},
          %{"name" => "d", "status" => "inactive", "type" => "regular"}
        ]
      }

      # Items that are NOT (inactive regular items)
      result =
        Enzyme.select(
          data,
          "items[*][?not (@.status == 'inactive' and @.type == 'regular')].name"
        )

      assert result == ["a", "b", "c"]
    end

    test "chained logical operators" do
      data = %{
        "records" => [
          %{"a" => 1, "b" => 2, "c" => 3},
          %{"a" => 1, "b" => 2, "c" => 0},
          %{"a" => 1, "b" => 0, "c" => 3},
          %{"a" => 0, "b" => 2, "c" => 3}
        ]
      }

      # All three conditions must be true
      result = Enzyme.select(data, "records[*][?@.a == 1 and @.b == 2 and @.c == 3]")
      assert result == [%{"a" => 1, "b" => 2, "c" => 3}]
    end

    test "logical operators with isos" do
      data = %{
        "items" => [
          %{"name" => "a", "count" => "10", "active" => true},
          %{"name" => "b", "count" => "5", "active" => true},
          %{"name" => "c", "count" => "15", "active" => false}
        ]
      }

      # Active items with count > 7
      result =
        Enzyme.select(data, "items[*][?@.active == true and @.count::integer > 7].name", [])

      assert result == ["a"]
    end

    test "transform with logical operators" do
      data = %{
        "users" => [
          %{"name" => "alice", "active" => true, "role" => "admin"},
          %{"name" => "bob", "active" => true, "role" => "user"},
          %{"name" => "charlie", "active" => false, "role" => "admin"}
        ]
      }

      # Uppercase names of active admins
      result =
        Enzyme.transform(
          data,
          "users[*][?@.active == true and @.role == 'admin'].name",
          &String.upcase/1
        )

      assert result == %{
               "users" => [
                 %{"name" => "ALICE", "active" => true, "role" => "admin"},
                 %{"name" => "bob", "active" => true, "role" => "user"},
                 %{"name" => "charlie", "active" => false, "role" => "admin"}
               ]
             }
    end
  end
end
