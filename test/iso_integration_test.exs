defmodule IsoIntegrationTest do
  use ExUnit.Case, async: true

  alias Enzyme.Iso

  describe "select with builtin isos" do
    test "::integer converts string to integer" do
      data = %{"count" => "42"}
      assert Enzyme.select(data, "count::integer", []) == 42
    end

    test "::float converts string to float" do
      data = %{"rate" => "3.14"}
      assert Enzyme.select(data, "rate::float", []) == 3.14
    end

    test "::atom converts string to atom" do
      data = %{"status" => "active"}
      assert Enzyme.select(data, "status::atom", []) == :active
    end

    test "::base64 decodes base64 encoded data" do
      data = %{"data" => Base.encode64("secret")}
      assert Enzyme.select(data, "data::base64", []) == "secret"
    end
  end

  describe "select with custom isos" do
    test "custom iso with path string" do
      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      data = %{"price" => 1999}
      assert Enzyme.select(data, "price::cents", cents: cents_iso) == 19.99
    end

    test "custom iso with pre-parsed lens" do
      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("price::cents", cents: cents_iso)
      data = %{"price" => 1999}
      assert Enzyme.select(data, lens) == 19.99
    end

    test "runtime opts work for unresolved IsoRef" do
      # When iso is NOT provided at parse time, runtime opts are used
      lens = Enzyme.new("price::cents")
      data = %{"price" => 1999}

      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      assert Enzyme.select(data, lens, cents: cents_iso) == 19.99
    end

    test "runtime opts override stored (parse-time) opts" do
      # Parse-time iso divides by 100
      stored_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("price::cents", cents: stored_iso)
      data = %{"price" => 1999}

      # Uses stored iso by default
      assert Enzyme.select(data, lens) == 19.99

      # Runtime iso divides by 1000 - overrides stored iso
      runtime_iso = Iso.new(&(&1 / 1000), &trunc(&1 * 1000))
      assert Enzyme.select(data, lens, cents: runtime_iso) == 1.999
    end

    test "runtime opts can override builtin" do
      custom_integer = Iso.new(&(String.to_integer(&1) * 2), &Integer.to_string(div(&1, 2)))
      data = %{"count" => "10"}

      # Builtin behavior
      assert Enzyme.select(data, "count::integer", []) == 10

      # Custom override doubles the value
      assert Enzyme.select(data, "count::integer", integer: custom_integer) == 20
    end
  end

  describe "select with chained isos" do
    test "multiple isos in sequence" do
      # Data is base64-encoded integer string
      encoded = Base.encode64("42")
      data = %{"value" => encoded}

      assert Enzyme.select(data, "value::base64::integer", []) == 42
    end
  end

  describe "select with isos in nested paths" do
    test "iso after map key" do
      data = %{"user" => %{"age" => "25"}}
      assert Enzyme.select(data, "user.age::integer", []) == 25
    end

    test "iso after list index" do
      data = %{"counts" => ["10", "20", "30"]}
      assert Enzyme.select(data, "counts[1]::integer", []) == 20
    end

    test "iso after wildcard" do
      data = %{"counts" => ["10", "20", "30"]}
      assert Enzyme.select(data, "counts[*]::integer", []) == [10, 20, 30]
    end

    test "iso combined with filter" do
      data = %{
        "products" => [
          %{"name" => "Widget", "price" => "25"},
          %{"name" => "Gadget", "price" => "99"},
          %{"name" => "Gizmo", "price" => "50"}
        ]
      }

      # Note: filter sees string, then iso converts
      prices = Enzyme.select(data, "products[*].price::integer", [])
      assert prices == [25, 99, 50]
    end
  end

  describe "transform with builtin isos" do
    test "::integer transforms and stores back as string" do
      data = %{"count" => "42"}
      result = Enzyme.transform(data, "count::integer", &(&1 + 1), [])
      assert result == %{"count" => "43"}
    end

    test "::float transforms and stores back as string" do
      data = %{"rate" => "3.14"}
      result = Enzyme.transform(data, "rate::float", &(&1 * 2), [])
      # Float.to_string may have precision differences
      assert result["rate"] |> String.to_float() |> Float.round(2) == 6.28
    end

    test "::base64 transforms decoded and stores encoded" do
      data = %{"data" => Base.encode64("hello")}
      result = Enzyme.transform(data, "data::base64", &String.upcase/1, [])
      assert Base.decode64!(result["data"]) == "HELLO"
    end
  end

  describe "transform with custom isos" do
    test "custom iso roundtrips correctly" do
      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      # $19.99 in cents
      data = %{"price" => 1999}

      # Add $1.00 in dollar space
      result = Enzyme.transform(data, "price::cents", &(&1 + 1), cents: cents_iso)
      # $20.99 in cents
      assert result == %{"price" => 2099}
    end

    test "transform with pre-parsed lens" do
      cents_iso = Iso.new(&(&1 / 100), &trunc(&1 * 100))
      lens = Enzyme.new("price::cents", cents: cents_iso)
      data = %{"price" => 1999}

      result = Enzyme.transform(data, lens, &(&1 + 1), [])
      assert result == %{"price" => 2099}
    end
  end

  describe "transform with isos in nested paths" do
    test "iso after wildcard transforms all" do
      data = %{"counts" => ["10", "20", "30"]}
      result = Enzyme.transform(data, "counts[*]::integer", &(&1 * 2), [])
      assert result == %{"counts" => ["20", "40", "60"]}
    end

    test "iso in deeply nested path" do
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

  describe "error handling" do
    test "raises for unresolved iso at runtime" do
      data = %{"value" => 42}

      assert_raise ArgumentError, ~r/Iso 'unknown' is not resolved/, fn ->
        Enzyme.select(data, "value::unknown", [])
      end
    end

    test "error message lists available builtins" do
      data = %{"value" => 42}

      error = catch_error(Enzyme.select(data, "value::unknown", []))
      assert error.message =~ ":integer"
      assert error.message =~ ":float"
      assert error.message =~ ":base64"
    end

    test "raises for invalid iso in opts" do
      data = %{"value" => "42"}

      assert_raise ArgumentError, ~r/Expected %Enzyme.Iso{}/, fn ->
        Enzyme.select(data, "value::custom", custom: "not an iso")
      end
    end
  end

  describe "Enzyme.new/2" do
    test "resolves iso at parse time if provided" do
      iso = Iso.new(&String.upcase/1, &String.downcase/1)
      lens = Enzyme.new("name::custom", custom: iso)

      # Should work without runtime opts
      data = %{"name" => "alice"}
      assert Enzyme.select(data, lens) == "ALICE"
    end

    test "leaves iso unresolved if not provided" do
      lens = Enzyme.new("name::custom")

      # Should fail without runtime opts
      data = %{"name" => "alice"}

      assert_raise ArgumentError, ~r/not resolved/, fn ->
        Enzyme.select(data, lens)
      end

      # Should work with runtime opts
      iso = Iso.new(&String.upcase/1, &String.downcase/1)
      assert Enzyme.select(data, lens, custom: iso) == "ALICE"
    end
  end
end
