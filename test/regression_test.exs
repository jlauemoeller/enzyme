defmodule Enzyme.RegressionTest do
  @moduledoc false
  use ExUnit.Case

  describe "One select applied to list of records" do
    setup do
      data = [
        %{"label1" => [%{unit: "a", item: "1"}, %{unit: "b", item: "2"}]},
        %{"label2" => [%{unit: "a", item: "1"}, %{unit: "b", item: "2"}]},
        %{"label3" => [%{unit: "a", item: "1"}, %{unit: "b", item: "2"}]}
      ]

      [data: data]
    end

    test "does not return nil for elements that do not match", %{data: data} do
      assert Enzyme.select(data, "[*][label3]") == [
               [%{unit: "a", item: "1"}, %{unit: "b", item: "2"}]
             ]
    end

    test "does not produce nil values for elements that do not match", %{data: data} do
      assert Enzyme.transform(data, "[*][label3]", fn list ->
               Enum.map(list, &Map.take(&1, [:item]))
             end) == [
               %{"label1" => [%{unit: "a", item: "1"}, %{unit: "b", item: "2"}]},
               %{"label2" => [%{unit: "a", item: "1"}, %{unit: "b", item: "2"}]},
               %{"label3" => [%{item: "1"}, %{item: "2"}]}
             ]
    end
  end

  describe "One transform applied to list of records" do
    setup do
      data =
        [
          %{field: nil},
          %{field: nil}
        ]

      [data: data]
    end

    test "Applies One transform to list of records", %{data: data} do
      assert Enzyme.transform(data, "[*]:field", "value") == [
               %{field: "value"},
               %{field: "value"}
             ]
    end
  end

  describe "Selecting and transforming through multiple [*] levels" do
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

    test "selecting through multiple [*] levels", %{data: data} do
      assert Enzyme.select(data, "departments[*].employees[*].name") == [
               "Alice",
               "Bob",
               "Charlie"
             ]
    end

    test "selecting through multiple [*][*][*] levels", %{data: data} do
      assert Enzyme.select(data, "departments[*][*][*].name") == [
               "Alice",
               "Bob",
               "Charlie"
             ]
    end

    test "selecting through multiple [*] levels with filtering", %{data: data} do
      assert Enzyme.select(data, "departments[*][?@.name == 'Engineering'].employees[*].name") ==
               [
                 "Alice",
                 "Bob"
               ]
    end

    test "transforming through multiple [*] levels", %{data: data} do
      updated = Enzyme.transform(data, "departments[*].employees[*].title", &String.upcase/1)

      expected = %{
        "company" => "Acme Corp",
        "departments" => [
          %{
            "name" => "Engineering",
            "employees" => [
              %{"name" => "Alice", "title" => "SENIOR ENGINEER"},
              %{"name" => "Bob", "title" => "JUNIOR ENGINEER"}
            ]
          },
          %{
            "name" => "Sales",
            "employees" => [
              %{"name" => "Charlie", "title" => "SALES MANAGER"}
            ]
          }
        ]
      }

      assert updated == expected
    end

    test "transforming through multiple [*][*][*] levels", %{data: data} do
      updated =
        Enzyme.transform(data, "departments[*][*][*].title", &String.upcase/1)

      expected = %{
        "company" => "Acme Corp",
        "departments" => [
          %{
            "name" => "Engineering",
            "employees" => [
              %{"name" => "Alice", "title" => "SENIOR ENGINEER"},
              %{"name" => "Bob", "title" => "JUNIOR ENGINEER"}
            ]
          },
          %{
            "name" => "Sales",
            "employees" => [
              %{"name" => "Charlie", "title" => "SALES MANAGER"}
            ]
          }
        ]
      }

      assert updated == expected
    end
  end

  describe "t" do
    setup do
      data = %{
        title: "Lorem Ipsum",
        data: %{
          "47QKL" => %{
            "ABC" => [
              %{
                title: "1.4",
                data: %{
                  year_id: 142,
                  value: true
                }
              }
            ],
            "DEF" => [
              %{
                title: "1.4.1",
                data: nil
              }
            ]
          }
        }
      }

      [data: data]
    end

    test "t1" do
      data = %{year_id: 123, value: true}

      assert Enzyme.transform(data, ":year_id", 142) == %{
               year_id: 142,
               value: true
             }
    end

    test "t2", %{data: data} do
      assert Enzyme.transform(data, ":data", 123) == %{
               title: "Lorem Ipsum",
               data: 123
             }
    end

    test "t3", %{data: data} do
      assert Enzyme.transform(data, ":data[*][*][*][*]:year_id", 123) == %{
               title: "Lorem Ipsum",
               data: %{
                 "47QKL" => %{
                   "ABC" => [
                     %{
                       title: "1.4",
                       data: %{
                         year_id: 123,
                         value: true
                       }
                     }
                   ],
                   "DEF" => [
                     %{
                       title: "1.4.1",
                       data: nil
                     }
                   ]
                 }
               }
             }
    end
  end

  describe "Filters with maps" do
    test "filters maps in single lists" do
      data = [
        %{active: false, name: "a"},
        %{active: true, name: "b"},
        %{active: true, name: "c"}
      ]

      assert Enzyme.select(data, "[?@:name == 'c']") == [
               %{active: true, name: "c"}
             ]
    end

    test "filters many single maps" do
      data = [
        %{active: false, name: "a"},
        %{active: true, name: "b"},
        %{active: true, name: "c"}
      ]

      assert Enzyme.select(data, "[*][?@:name == 'c']") == [
               %{active: true, name: "c"}
             ]
    end
  end
end
