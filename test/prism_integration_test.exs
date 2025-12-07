defmodule Enzyme.PrismIntegrationTest do
  @moduledoc false
  use ExUnit.Case

  describe "Enzyme.select/2 with prism paths" do
    test "extracts value from {:ok, value}" do
      assert Enzyme.select({:ok, 42}, ":{:ok, v}") == 42
    end

    test "returns nil for non-matching tuple" do
      assert Enzyme.select({:error, "oops"}, ":{:ok, v}") == nil
    end

    test "extracts from nested structure" do
      data = %{"result" => {:ok, %{"user" => "Alice"}}}
      assert Enzyme.select(data, "result:{:ok, v}.user") == "Alice"
    end

    test "extracts multiple values as tuple" do
      assert Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, w, h}") == {3, 4}
    end

    test "extracts with ignored positions" do
      assert Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, _, h}") == 4
    end

    test "filter only returns original tuple" do
      assert Enzyme.select({:ok, 5}, ":{:ok, _}") == {:ok, 5}
    end

    test "rest pattern extracts all after tag" do
      assert Enzyme.select({:ok, 5}, ":{:ok, ...}") == 5
      assert Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, ...}") == {3, 4}
    end

    test "extracts from list of results" do
      data = [
        {:ok, 1},
        {:error, "a"},
        {:ok, 2},
        {:error, "b"},
        {:ok, 3}
      ]

      assert Enzyme.select(data, "[*]:{:ok, v}") == [1, 2, 3]
    end

    test "extracts from list and continues path" do
      data = [
        {:ok, %{"name" => "Alice"}},
        {:error, "not found"},
        {:ok, %{"name" => "Bob"}}
      ]

      assert Enzyme.select(data, "[*]:{:ok, v}.name") == ["Alice", "Bob"]
    end

    test "complex path with multiple components" do
      data = %{
        "responses" => [
          {:ok, %{"user" => %{"email" => "alice@example.com"}}},
          {:error, "timeout"},
          {:ok, %{"user" => %{"email" => "bob@example.com"}}}
        ]
      }

      result = Enzyme.select(data, "responses[*]:{:ok, v}.user.email")
      assert result == ["alice@example.com", "bob@example.com"]
    end

    test "filters shapes by type" do
      shapes = [
        {:circle, 5},
        {:rectangle, 3, 4},
        {:circle, 10},
        {:rectangle, 5, 6}
      ]

      assert Enzyme.select(shapes, "[*]:{:circle, r}") == [5, 10]
      assert Enzyme.select(shapes, "[*]:{:rectangle, w, h}") == [{3, 4}, {5, 6}]
    end

    test "extracts only height from rectangles" do
      shapes = [
        {:circle, 5},
        {:rectangle, 3, 4},
        {:rectangle, 5, 6}
      ]

      assert Enzyme.select(shapes, "[*]:{:rectangle, _, h}") == [4, 6]
    end
  end

  describe "Enzyme.transform/3 with prism paths" do
    test "transforms matching tuple" do
      assert Enzyme.transform({:ok, 5}, ":{:ok, v}", &(&1 * 2)) == {:ok, 10}
    end

    test "leaves non-matching tuple unchanged" do
      assert Enzyme.transform({:error, "x"}, ":{:ok, v}", &(&1 * 2)) == {:error, "x"}
    end

    test "transforms in nested structure" do
      data = %{"result" => {:ok, 5}}
      result = Enzyme.transform(data, "result:{:ok, v}", &(&1 * 2))
      assert result == %{"result" => {:ok, 10}}
    end

    test "transforms multiple values" do
      transform_fn = fn {w, h} -> {w * 2, h * 2} end
      result = Enzyme.transform({:rectangle, 3, 4}, ":{:rectangle, w, h}", transform_fn)
      assert result == {:rectangle, 6, 8}
    end

    test "transforms only extracted position" do
      result = Enzyme.transform({:rectangle, 3, 4}, ":{:rectangle, _, h}", &(&1 * 2))
      assert result == {:rectangle, 3, 8}
    end

    test "transforms list of tuples" do
      data = [{:ok, 1}, {:error, "x"}, {:ok, 2}]
      result = Enzyme.transform(data, "[*]:{:ok, v}", &(&1 * 10))
      assert result == [{:ok, 10}, {:error, "x"}, {:ok, 20}]
    end

    test "transforms nested values in list" do
      data = [
        {:ok, %{"count" => 1}},
        {:error, "x"},
        {:ok, %{"count" => 2}}
      ]

      result = Enzyme.transform(data, "[*]:{:ok, v}.count", &(&1 * 10))

      assert result == [
               {:ok, %{"count" => 10}},
               {:error, "x"},
               {:ok, %{"count" => 20}}
             ]
    end

    test "transforms shapes" do
      shapes = [
        {:circle, 5},
        {:rectangle, 3, 4},
        {:circle, 10}
      ]

      result = Enzyme.transform(shapes, "[*]:{:circle, r}", &(&1 * 2))
      assert result == [{:circle, 10}, {:rectangle, 3, 4}, {:circle, 20}]
    end
  end

  describe "Enzyme.prism/2 programmatic API" do
    test "creates and uses prism" do
      prism = Enzyme.prism(:ok, [:value])
      assert Enzyme.select({:ok, 42}, prism) == 42
    end

    test "prism with rest pattern" do
      prism = Enzyme.prism(:ok, :...)
      assert Enzyme.select({:ok, 42}, prism) == 42
    end

    test "composes prism with other lenses" do
      lens = Enzyme.one("result") |> Enzyme.prism(:ok, [:v])
      data = %{"result" => {:ok, 42}}
      assert Enzyme.select(data, lens) == 42
    end

    test "prism in longer composition" do
      lens =
        Enzyme.one("data")
        |> Enzyme.all()
        |> Enzyme.prism(:ok, [:v])
        |> Enzyme.one("name")

      data = %{
        "data" => [
          {:ok, %{"name" => "Alice"}},
          {:error, "x"},
          {:ok, %{"name" => "Bob"}}
        ]
      }

      assert Enzyme.select(data, lens) == ["Alice", "Bob"]
    end
  end

  describe "real-world scenarios" do
    test "processing API responses" do
      responses = [
        {:ok, %{"status" => 200, "data" => %{"id" => 1, "name" => "Product A"}}},
        {:error, %{"status" => 404, "message" => "Not found"}},
        {:ok, %{"status" => 200, "data" => %{"id" => 2, "name" => "Product B"}}},
        {:error, %{"status" => 500, "message" => "Server error"}}
      ]

      # Get all successful product names
      names = Enzyme.select(responses, "[*]:{:ok, v}.data.name")
      assert names == ["Product A", "Product B"]

      # Get all error messages
      errors = Enzyme.select(responses, "[*]:{:error, v}.message")
      assert errors == ["Not found", "Server error"]
    end

    test "processing database results" do
      results = %{
        "users" => [
          {:ok, %{"id" => 1, "email" => "alice@example.com"}},
          {:ok, %{"id" => 2, "email" => "bob@example.com"}},
          {:error, "user not found"}
        ],
        "posts" => [
          {:ok, %{"id" => 101, "title" => "First Post"}},
          {:error, "post deleted"}
        ]
      }

      # Get all successful user emails
      emails = Enzyme.select(results, "users[*]:{:ok, v}.email")
      assert emails == ["alice@example.com", "bob@example.com"]

      # Get all successful post titles
      titles = Enzyme.select(results, "posts[*]:{:ok, v}.title")
      assert titles == ["First Post"]
    end

    test "transforming configuration with optional values" do
      config = %{
        "database" => {:ok, %{"host" => "localhost", "port" => 5432}},
        "cache" => {:error, "not configured"},
        "logging" => {:ok, %{"level" => "info", "file" => "/var/log/app.log"}}
      }

      # Uppercase all log levels in successful configs
      result = Enzyme.transform(config, "logging:{:ok, v}.level", &String.upcase/1)

      assert result == %{
               "database" => {:ok, %{"host" => "localhost", "port" => 5432}},
               "cache" => {:error, "not configured"},
               "logging" => {:ok, %{"level" => "INFO", "file" => "/var/log/app.log"}}
             }
    end

    test "working with Either-style results" do
      # Left = error, Right = success (Haskell convention)
      results = [
        {:right, 42},
        {:left, "parse error"},
        {:right, 17},
        {:left, "type error"}
      ]

      # Get all successful values
      successes = Enzyme.select(results, "[*]:{:right, v}")
      assert successes == [42, 17]

      # Get all errors
      errors = Enzyme.select(results, "[*]:{:left, v}")
      assert errors == ["parse error", "type error"]
    end
  end
end
