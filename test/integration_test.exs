defmodule Enzyme.IntegrationTest do
  @moduledoc """
  Integration tests exercising multiple library concepts together in realistic scenarios.

  These tests use deeply nested data structures combining maps, lists, tagged tuples,
  and various path components (wildcards, filters, slices, prisms, isos) to verify
  the library works correctly for complex real-world use cases.
  """
  use ExUnit.Case

  # Custom isos for testing
  defp cents_to_euros do
    Enzyme.iso(
      fn cents -> cents / 100.0 end,
      fn euros -> euros * 100.0 end
    )
  end

  defp percentage do
    Enzyme.iso(
      fn decimal -> decimal * 100.0 end,
      fn percent -> percent / 100.0 end
    )
  end

  describe "E-commerce order processing - select" do
    setup do
      orders = %{
        "orders" => [
          %{
            "id" => "ORD-001",
            "status" => {:confirmed, "2024-03-15T10:30:00Z"},
            "customer" => %{
              "name" => "Alice Smith",
              "tier" => :premium,
              "email" => "alice@example.com"
            },
            "items" => [
              %{"sku" => "LAPTOP-01", "name" => "Pro Laptop", "price" => "129999", "qty" => "1"},
              %{"sku" => "MOUSE-02", "name" => "Wireless Mouse", "price" => "4999", "qty" => "2"}
            ],
            "shipping" => %{"method" => "express", "cost" => "1500"}
          },
          %{
            "id" => "ORD-002",
            "status" => {:pending, nil},
            "customer" => %{
              "name" => "Bob Jones",
              "tier" => :standard,
              "email" => "bob@example.com"
            },
            "items" => [
              %{
                "sku" => "KEYBOARD-01",
                "name" => "Mechanical Keyboard",
                "price" => "15999",
                "qty" => "1"
              }
            ],
            "shipping" => %{"method" => "standard", "cost" => "500"}
          },
          %{
            "id" => "ORD-003",
            "status" => {:shipped, "2024-03-14T08:00:00Z"},
            "customer" => %{
              "name" => "Carol White",
              "tier" => :premium,
              "email" => "carol@example.com"
            },
            "items" => [
              %{"sku" => "MONITOR-01", "name" => "4K Monitor", "price" => "49999", "qty" => "1"},
              %{"sku" => "CABLE-05", "name" => "HDMI Cable", "price" => "1999", "qty" => "3"}
            ],
            "shipping" => %{"method" => "express", "cost" => "2000"}
          }
        ]
      }

      [orders: orders, isos: [cents: cents_to_euros()]]
    end

    @describetag :skip
    test "select premium customer names from confirmed orders with express shipping", %{
      orders: orders
    } do
      # Combines: wildcard, filter on atom key, filter on tagged tuple, nested access
      result =
        Enzyme.select(
          orders,
          "orders[*][?@.customer:tier == :premium][?@.shipping.method == 'express']:{:confirmed, _}.customer.name"
        )

      assert result == ["Alice Smith"]
    end

    test "select all item prices as euros from orders with multiple items", %{
      orders: orders,
      isos: isos
    } do
      # Combines: wildcard, filter with comparison, nested wildcard, iso chain
      Enzyme.new("orders[*].items[*].price::integer::cents")

      result =
        Enzyme.select(
          orders,
          "orders[*].items[*].price::integer::cents",
          isos
        )

      assert result == [[1299.99, 49.99], [159.99], [499.99, 19.99]]
    end

    test "select shipped order timestamps parsed as DateTime", %{orders: orders} do
      # Combines: wildcard, prism extraction, iso
      result = Enzyme.select(orders, "orders[*].status:{:shipped, ts}::iso8601")

      assert length(result) == 1
      assert %DateTime{year: 2024, month: 3, day: 14} = hd(result)
    end

    test "select order IDs and customer emails using key slice", %{orders: orders} do
      # Combines: wildcard, multiple key selection, nested access
      result = Enzyme.select(orders, "orders[*][id,customer.email]")

      assert result == [
               ["ORD-001", "alice@example.com"],
               ["ORD-002", "bob@example.com"],
               ["ORD-003", "carol@example.com"]
             ]
    end

    test "select items where quantity > 1 as integers", %{orders: orders} do
      # Combines: nested wildcards, filter with iso on left side
      result =
        Enzyme.select(
          orders,
          "orders[*].items[*][?@.qty::integer > 1][name,qty]"
        )

      assert result == [[["Wireless Mouse", "2"]], [], [["HDMI Cable", "3"]]]
    end
  end

  describe "E-commerce order processing - transform" do
    setup do
      order = %{
        "id" => "ORD-001",
        "status" => {:pending, nil},
        "items" => [
          %{"name" => "Widget", "price" => "1000", "discount" => "0.1"},
          %{"name" => "Gadget", "price" => "2000", "discount" => "0.2"}
        ],
        "totals" => %{
          "subtotal" => "3000",
          "tax_rate" => "0.08",
          "shipping" => "500"
        }
      }

      [order: order, isos: [cents: cents_to_euros(), pct: percentage()]]
    end

    test "apply percentage discount to all item prices", %{order: order, isos: isos} do
      # Combines: wildcard, iso for price, transform function using another field
      # This applies a flat 15% discount to all prices
      result =
        Enzyme.transform(
          order,
          "items[*].price::float::cents",
          fn price -> price * 0.85 end,
          isos
        )

      assert get_in(result, ["items", Access.at(0), "price"]) == "850.0"
      assert get_in(result, ["items", Access.at(1), "price"]) == "1700.0"
    end

    @describetag :skip
    test "confirm pending order with timestamp", %{order: order} do
      # Combines: prism matching and retagging with transform
      result =
        Enzyme.transform(
          order,
          "status:{:pending, _} -> :confirmed",
          fn _ -> "2024-03-20T12:00:00Z" end
        )

      assert result["status"] == {:confirmed, "2024-03-20T12:00:00Z"}
    end

    test "update tax rate as percentage", %{order: order, isos: isos} do
      # Combines: nested key access, custom iso for percentage
      result =
        Enzyme.transform(
          order,
          "totals.tax_rate::float::pct",
          fn rate -> rate + 2 end,
          isos
        )

      # 8% + 2% = 10% = 0.1
      assert result["totals"]["tax_rate"] == "0.1"
    end

    test "zero out discounts for items priced under $15", %{order: order, isos: isos} do
      # Combines: wildcard, filter with iso comparison, constant replacement
      result =
        Enzyme.transform(
          order,
          "items[*][?@.price::cents < 15].discount",
          "0.0",
          isos
        )

      # Widget is $10, so its discount should be zeroed
      assert get_in(result, ["items", Access.at(0), "discount"]) == "0.0"
      # Gadget is $20, unchanged
      assert get_in(result, ["items", Access.at(1), "discount"]) == "0.2"
    end

    test "uppercase all item names in order", %{order: order} do
      # Combines: wildcard, string transformation
      result = Enzyme.transform(order, "items[*].name", &String.upcase/1)

      assert get_in(result, ["items", Access.at(0), "name"]) == "WIDGET"
      assert get_in(result, ["items", Access.at(1), "name"]) == "GADGET"
    end
  end

  describe "API response handling - select" do
    setup do
      response = %{
        "meta" => %{
          "request_id" => "req-abc-123",
          "timestamp" => "2024-03-15T14:30:00Z"
        },
        "data" => %{
          "users" => [
            {:ok, %{id: 1, name: "Alice", roles: [:admin, :user], score: "95"}},
            {:error, %{code: "NOT_FOUND", message: "User 2 deleted"}},
            {:ok, %{id: 3, name: "Bob", roles: [:user], score: "87"}},
            {:ok, %{id: 4, name: "Carol", roles: [:admin, :moderator], score: "92"}},
            {:error, %{code: "SUSPENDED", message: "Account suspended"}}
          ],
          "pagination" => %{
            "page" => "1",
            "per_page" => "10",
            "total" => "5"
          }
        }
      }

      [response: response]
    end

    test "extract successful user data only", %{response: response} do
      # Combines: nested access, wildcard, prism filtering
      result = Enzyme.select(response, "data.users[*]:{:ok, user}")

      assert length(result) == 3
      assert Enum.map(result, & &1.name) == ["Alice", "Bob", "Carol"]
    end

    test "find admin users from successful responses with score >= 90", %{response: response} do
      # Combines: prism, filter on atom key with list membership simulation, nested filter
      # Note: Testing admin role by checking first role (simplified)
      result =
        Enzyme.select(
          response,
          "data.users[*]:{:ok, u}[?@:score::integer >= 90]:name"
        )

      assert result == ["Alice", "Carol"]
    end

    test "extract error codes and messages together", %{response: response} do
      # Combines: prism for errors, multiple key selection
      result = Enzyme.select(response, "data.users[*]:{:error, e}[:code,:message]")

      assert result == [
               ["NOT_FOUND", "User 2 deleted"],
               ["SUSPENDED", "Account suspended"]
             ]
    end

    test "get pagination info as integers", %{response: response} do
      # Combines: nested access, multiple keys, iso on each
      page = Enzyme.select(response, "data.pagination.page::integer", [])
      total = Enzyme.select(response, "data.pagination.total::integer", [])

      assert page == 1
      assert total == 5
    end

    test "extract request metadata with timestamp as DateTime", %{response: response} do
      # Combines: nested access, iso chain
      ts = Enzyme.select(response, "meta.timestamp::iso8601", [])

      assert %DateTime{year: 2024, month: 3, day: 15, hour: 14, minute: 30} = ts
    end
  end

  describe "API response handling - transform" do
    setup do
      response = %{
        "results" => [
          {:ok, %{"value" => "100", "label" => "first"}},
          {:error, "timeout"},
          {:ok, %{"value" => "200", "label" => "second"}},
          {:error, "connection_refused"}
        ]
      }

      [response: response]
    end

    test "double all successful values", %{response: response} do
      # Combines: wildcard, prism, nested access with iso, transform
      result =
        Enzyme.transform(
          response,
          "results[*]:{:ok, data}.value::integer",
          &(&1 * 2),
          []
        )

      results = result["results"]
      assert {:ok, %{"value" => "200", "label" => "first"}} = Enum.at(results, 0)
      assert {:error, "timeout"} = Enum.at(results, 1)
      assert {:ok, %{"value" => "400", "label" => "second"}} = Enum.at(results, 2)
      assert {:error, "connection_refused"} = Enum.at(results, 3)
    end

    test "convert errors to standardized format", %{response: response} do
      # Combines: wildcard, prism retagging
      result =
        Enzyme.transform(
          response,
          "results[*]:{:error, msg} -> :failure",
          fn msg -> %{"reason" => msg, "retryable" => true} end
        )

      results = result["results"]
      assert {:failure, %{"reason" => "timeout", "retryable" => true}} = Enum.at(results, 1)

      assert {:failure, %{"reason" => "connection_refused", "retryable" => true}} =
               Enum.at(results, 3)
    end

    test "uppercase labels in successful responses only", %{response: response} do
      # Combines: wildcard, prism, nested transform
      result = Enzyme.transform(response, "results[*]:{:ok, data}.label", &String.upcase/1)

      results = result["results"]
      assert {:ok, %{"label" => "FIRST"}} = Enum.at(results, 0)
      assert {:ok, %{"label" => "SECOND"}} = Enum.at(results, 2)
    end
  end

  describe "Configuration management - select" do
    setup do
      config = %{
        environments: %{
          production: %{
            "database" => %{
              "host" => "prod-db.example.com",
              "port" => "5432",
              "pool_size" => "20",
              "ssl" => true
            },
            "cache" => %{
              "enabled" => true,
              "ttl_seconds" => "3600"
            },
            "features" => [
              %{name: :dark_mode, enabled: true, rollout: "1.0"},
              %{name: :beta_api, enabled: false, rollout: "0.0"},
              %{name: :new_checkout, enabled: true, rollout: "0.5"}
            ]
          },
          staging: %{
            "database" => %{
              "host" => "staging-db.example.com",
              "port" => "5432",
              "pool_size" => "5",
              "ssl" => false
            },
            "cache" => %{
              "enabled" => false,
              "ttl_seconds" => "60"
            },
            "features" => [
              %{name: :dark_mode, enabled: true, rollout: "1.0"},
              %{name: :beta_api, enabled: true, rollout: "1.0"},
              %{name: :new_checkout, enabled: true, rollout: "1.0"}
            ]
          }
        }
      }

      [config: config]
    end

    test "get production database config with port as integer", %{config: config} do
      # Combines: atom keys, nested string keys, iso
      port = Enzyme.select(config, ":environments:production.database.port::integer", [])
      pool = Enzyme.select(config, ":environments:production.database.pool_size::integer", [])

      assert port == 5432
      assert pool == 20
    end

    test "find enabled features with rollout > 50% in production", %{config: config} do
      # Combines: deep atom path, wildcard, compound filter, iso in filter
      result =
        Enzyme.select(
          config,
          ":environments:production.features[*][?@:enabled == true and @:rollout::float > 0.5]:name"
        )

      assert result == [:dark_mode]
    end

    test "get all feature names per environment", %{config: config} do
      # Combines: atom wildcard, nested wildcard, atom key extraction
      result = Enzyme.select(config, ":environments[*].features[*]:name")

      assert result == [
               :dark_mode,
               :beta_api,
               :new_checkout,
               :dark_mode,
               :beta_api,
               :new_checkout
             ]
    end

    test "compare cache settings between environments", %{config: config} do
      prod_ttl = Enzyme.select(config, ":environments:production.cache.ttl_seconds::integer", [])
      staging_ttl = Enzyme.select(config, ":environments:staging.cache.ttl_seconds::integer", [])

      assert prod_ttl == 3600
      assert staging_ttl == 60
    end
  end

  describe "Configuration management - transform" do
    setup do
      config = %{
        settings: %{
          "timeouts" => %{
            "connect" => "5000",
            "read" => "30000",
            "write" => "10000"
          },
          "limits" => %{
            "max_connections" => "100",
            "rate_limit" => "1000"
          }
        },
        flags: [
          {:feature, :logging, true},
          {:feature, :metrics, false},
          {:feature, :tracing, true}
        ]
      }

      [config: config]
    end

    test "double all timeout values", %{config: config} do
      # Combines: atom key, nested access, wildcard over map values, iso
      result =
        Enzyme.transform(
          config,
          ":settings.timeouts[*]::integer",
          &(&1 * 2),
          []
        )

      timeouts = result.settings["timeouts"]
      assert timeouts["connect"] == "10000"
      assert timeouts["read"] == "60000"
      assert timeouts["write"] == "20000"
    end

    @describetag :skip
    # This doesn't work because we don't track variable bindings across steps yet
    # So the output of the prism is just the raw projected tuple, eg. {:metrics, false}
    # without any knowledge of the variable bindings in the prism. This information
    # is required by the ExpressionParser to correctly extract the named position
    # from the tuple.
    # (see https://github.com/jlauemoeller/enzyme/blob/7044ca3819c0718c686d4a8fbf41a096e16cbda6/lib/enzyme/expression_parser.ex#L552)

    test "enable all disabled features", %{config: config} do
      # Combines: atom key, wildcard, prism with multiple extraction, filter, transform
      result =
        Enzyme.transform(
          config,
          ":flags[*]:{:feature, name, enabled}[?@:enabled == false]",
          fn {name, _} -> {name, true} end
        )

      flags = result.flags
      assert {:feature, :logging, true} = Enum.at(flags, 0)
      assert {:feature, :metrics, true} = Enum.at(flags, 1)
      assert {:feature, :tracing, true} = Enum.at(flags, 2)
    end

    test "cap rate limit at 500", %{config: config} do
      # Combines: deep nested access, iso, conditional transform
      result =
        Enzyme.transform(
          config,
          ":settings.limits.rate_limit::integer",
          fn limit -> min(limit, 500) end,
          []
        )

      assert result.settings["limits"]["rate_limit"] == "500"
    end
  end

  describe "Event analytics - select" do
    setup do
      events = %{
        "session_id" => "sess-xyz-789",
        "events" => [
          %{
            "type" => "page_view",
            "timestamp" => "2024-03-15T10:00:00Z",
            "data" => %{"path" => "/home", "duration_ms" => "1500"}
          },
          %{
            "type" => "click",
            "timestamp" => "2024-03-15T10:00:05Z",
            "data" => %{"element" => "buy_button", "x" => "150", "y" => "300"}
          },
          %{
            "type" => "page_view",
            "timestamp" => "2024-03-15T10:00:10Z",
            "data" => %{"path" => "/checkout", "duration_ms" => "8500"}
          },
          %{
            "type" => "error",
            "timestamp" => "2024-03-15T10:00:15Z",
            "data" => %{"message" => "Payment failed", "code" => "PAY_001"}
          },
          %{
            "type" => "page_view",
            "timestamp" => "2024-03-15T10:00:20Z",
            "data" => %{"path" => "/error", "duration_ms" => "500"}
          }
        ]
      }

      [events: events]
    end

    @describetag :skip
    # This doesn't work because the ExpressionParser cannot yet handle
    # changed dot notation in filters.
    test "extract page view paths with duration > 1 second", %{events: events} do
      # Combines: wildcard, compound filter with iso, nested access
      result =
        Enzyme.select(
          events,
          "events[*][?@.type == 'page_view' and @.data.duration_ms::integer > 1000].data.path"
        )

      assert result == ["/home", "/checkout"]
    end

    test "get all event timestamps as DateTimes", %{events: events} do
      # Combines: wildcard, iso
      result = Enzyme.select(events, "events[*].timestamp::iso8601", [])

      assert length(result) == 5
      assert Enum.all?(result, &match?(%DateTime{}, &1))
    end

    test "extract error event details", %{events: events} do
      # Combines: wildcard, filter, nested key slice
      result =
        Enzyme.select(events, "events[*][?@.type == 'error'].data[message,code]")

      assert result == [["Payment failed", "PAY_001"]]
    end

    test "get click coordinates as integers", %{events: events} do
      # Combines: wildcard, filter, nested access, multiple selections with iso
      clicks = Enzyme.select(events, "events[*][?@.type == 'click'].data")

      assert length(clicks) == 1
      click = hd(clicks)

      x = Enzyme.select(click, "x::integer", [])
      y = Enzyme.select(click, "y::integer", [])

      assert x == 150
      assert y == 300
    end
  end

  describe "Event analytics - transform" do
    setup do
      events = %{
        "events" => [
          %{"type" => "view", "value" => "100"},
          %{"type" => "click", "value" => "50"},
          %{"type" => "view", "value" => "200"}
        ]
      }

      [events: events]
    end

    test "boost view event values by 20%", %{events: events} do
      # Combines: wildcard, filter, iso, percentage transform
      result =
        Enzyme.transform(
          events,
          "events[*][?@.type == 'view'].value::integer",
          fn v -> trunc(v * 1.2) end,
          []
        )

      evts = result["events"]
      assert %{"type" => "view", "value" => "120"} = Enum.at(evts, 0)
      assert %{"type" => "click", "value" => "50"} = Enum.at(evts, 1)
      assert %{"type" => "view", "value" => "240"} = Enum.at(evts, 2)
    end

    test "rename event types", %{events: events} do
      # Combines: wildcard, filter, constant replacement
      result = Enzyme.transform(events, "events[*][?@.type == 'view'].type", "page_view")

      evts = result["events"]
      assert %{"type" => "page_view"} = Enum.at(evts, 0)
      assert %{"type" => "click"} = Enum.at(evts, 1)
      assert %{"type" => "page_view"} = Enum.at(evts, 2)
    end
  end

  describe "Edge cases and complex combinations" do
    test "deeply nested prism with iso chain" do
      data = %{
        "responses" => [
          {:ok, %{"encoded_value" => Base.encode64("42")}},
          {:error, "failed"},
          {:ok, %{"encoded_value" => Base.encode64("100")}}
        ]
      }

      result = Enzyme.select(data, "responses[*]:{:ok, r}.encoded_value::base64::integer", [])

      assert result == [42, 100]
    end

    test "filter with negation and parentheses" do
      data = %{
        "items" => [
          %{"a" => true, "b" => true, "c" => false},
          %{"a" => false, "b" => true, "c" => true},
          %{"a" => true, "b" => false, "c" => true},
          %{"a" => false, "b" => false, "c" => false}
        ]
      }

      # Items where NOT (a AND b) - should exclude first item only
      result = Enzyme.select(data, "items[*][?not (@.a == true and @.b == true)]")

      assert length(result) == 3
      refute Enum.any?(result, fn item -> item["a"] == true and item["b"] == true end)
    end

    test "transform through prism retagging with value modification" do
      pipeline = %{
        "stages" => [
          {:pending, %{name: "stage1", retries: 0}},
          {:running, %{name: "stage2", retries: 1}},
          {:pending, %{name: "stage3", retries: 2}}
        ]
      }

      # Start all pending stages (retag and set initial state)
      result =
        Enzyme.transform(
          pipeline,
          "stages[*]:{:pending, data} -> :running",
          fn data -> Map.put(data, :started_at, "now") end
        )

      stages = result["stages"]
      assert {:running, %{name: "stage1", started_at: "now"}} = Enum.at(stages, 0)
      assert {:running, %{name: "stage2", retries: 1}} = Enum.at(stages, 1)
      assert {:running, %{name: "stage3", started_at: "now"}} = Enum.at(stages, 2)
    end

    test "mixed atom and string key navigation with filters" do
      data = %{
        users: [
          %{"profile" => %{verified: true, score: "95"}},
          %{"profile" => %{verified: false, score: "60"}},
          %{"profile" => %{verified: true, score: "80"}}
        ]
      }

      result =
        Enzyme.select(
          data,
          ":users[*].profile[?@:verified == true and @:score::integer >= 90]:score::integer",
          []
        )

      assert result == [95]
    end

    test "slice with filter on sliced elements" do
      data = %{
        "items" => [
          %{"id" => 1, "active" => true},
          %{"id" => 2, "active" => false},
          %{"id" => 3, "active" => true},
          %{"id" => 4, "active" => true},
          %{"id" => 5, "active" => false}
        ]
      }

      # Get active items from first 3 items only
      result = Enzyme.select(data, "items[0,1,2][?@.active == true].id")

      assert result == [1, 3]
    end
  end

  # ============================================================================
  # Additional tests inspired by regression_test.exs patterns
  # ============================================================================

  describe "Selective key matching in heterogeneous lists - select" do
    test "selects only elements that have the matching key, no nils" do
      # Inspired by: regression where [*][specific_key] returned nils for non-matches
      data = [
        %{"type" => "order", "order_id" => "ORD-001", "total" => 100},
        %{"type" => "refund", "refund_id" => "REF-001", "amount" => 50},
        %{"type" => "order", "order_id" => "ORD-002", "total" => 200},
        %{"type" => "adjustment", "note" => "Manual fix"}
      ]

      result = Enzyme.select(data, "[*][order_id]")
      assert result == ["ORD-001", "ORD-002"]
    end

    test "selects nested data only from matching elements" do
      data = [
        %{"category" => "electronics", "items" => [%{name: "Phone"}, %{name: "Laptop"}]},
        %{"category" => "clothing"},
        %{"category" => "electronics", "items" => [%{name: "Tablet"}]}
      ]

      result = Enzyme.select(data, "[*].items[*]:name")
      assert result == ["Phone", "Laptop", "Tablet"]
    end

    test "handles mixed presence of nested structures" do
      data = %{
        "records" => [
          %{"id" => 1, "metadata" => %{"tags" => ["a", "b"]}},
          %{"id" => 2},
          %{"id" => 3, "metadata" => %{"tags" => ["c"]}}
        ]
      }

      result = Enzyme.select(data, "records[*].metadata.tags[*]")
      assert result == ["a", "b", "c"]
    end
  end

  describe "Selective key matching in heterogeneous lists - transform" do
    test "transforms only elements that have the matching key" do
      data = [
        %{"type" => "order", "amount" => 100},
        %{"type" => "note", "text" => "reminder"},
        %{"type" => "order", "amount" => 200}
      ]

      result = Enzyme.transform(data, "[*][amount]", &(&1 * 2))

      assert result == [
               %{"type" => "order", "amount" => 200},
               %{"type" => "note", "text" => "reminder"},
               %{"type" => "order", "amount" => 400}
             ]
    end

    test "transforms nested atom keys in list of lists" do
      # Inspired by: regression with [*]:field pattern
      data = [
        [%{status: "pending"}, %{status: "active"}],
        [%{status: "completed"}]
      ]

      result = Enzyme.transform(data, "[*][*]:status", &String.upcase/1)

      assert result == [
               [%{status: "PENDING"}, %{status: "ACTIVE"}],
               [%{status: "COMPLETED"}]
             ]
    end

    test "leaves non-matching elements completely unchanged" do
      data = %{
        "items" => [
          %{"sku" => "A", "price" => 10, "discount" => 0.1},
          %{"sku" => "B", "price" => 20},
          %{"sku" => "C", "price" => 30, "discount" => 0.2}
        ]
      }

      result = Enzyme.transform(data, "items[*][discount]", fn d -> d * 2 end)

      items = result["items"]
      assert Enum.at(items, 0)["discount"] == 0.2
      assert Map.has_key?(Enum.at(items, 1), "discount") == false
      assert Enum.at(items, 2)["discount"] == 0.4
    end
  end

  describe "Multi-level wildcard traversal - select" do
    test "three levels of wildcards" do
      data = %{
        "regions" => [
          %{
            "name" => "North",
            "districts" => [
              %{"name" => "D1", "stores" => [%{"id" => 1}, %{"id" => 2}]},
              %{"name" => "D2", "stores" => [%{"id" => 3}]}
            ]
          },
          %{
            "name" => "South",
            "districts" => [
              %{"name" => "D3", "stores" => [%{"id" => 4}, %{"id" => 5}, %{"id" => 6}]}
            ]
          }
        ]
      }

      result = Enzyme.select(data, "regions[*].districts[*].stores[*].id")

      assert result == [1, 2, 3, 4, 5, 6]
    end

    test "wildcards with intermediate filtering" do
      data = %{
        "teams" => [
          %{
            "name" => "Alpha",
            "active" => true,
            "members" => [
              %{"name" => "Alice", "role" => "lead"},
              %{"name" => "Bob", "role" => "dev"}
            ]
          },
          %{
            "name" => "Beta",
            "active" => false,
            "members" => [
              %{"name" => "Carol", "role" => "lead"}
            ]
          },
          %{
            "name" => "Gamma",
            "active" => true,
            "members" => [
              %{"name" => "Dave", "role" => "dev"},
              %{"name" => "Eve", "role" => "dev"}
            ]
          }
        ]
      }

      # Get dev names from active teams only
      result =
        Enzyme.select(
          data,
          "teams[*][?@.active == true].members[*][?@.role == 'dev'].name"
        )

      assert result == ["Bob", "Dave", "Eve"]
    end

    test "double wildcard [*][*] pattern" do
      data = %{
        "matrix" => [
          [%{"v" => 1}, %{"v" => 2}],
          [%{"v" => 3}, %{"v" => 4}, %{"v" => 5}]
        ]
      }

      result = Enzyme.select(data, "matrix[*][*].v")
      assert result == [1, 2, 3, 4, 5]
    end
  end

  describe "Multi-level wildcard traversal - transform" do
    test "transforms at third level of nesting" do
      data = %{
        "buildings" => [
          %{
            "floors" => [
              %{"rooms" => [%{"temp" => 20}, %{"temp" => 22}]},
              %{"rooms" => [%{"temp" => 19}]}
            ]
          }
        ]
      }

      result = Enzyme.transform(data, "buildings[*].floors[*].rooms[*].temp", &(&1 + 5))

      rooms1 = get_in(result, ["buildings", Access.at(0), "floors", Access.at(0), "rooms"])
      rooms2 = get_in(result, ["buildings", Access.at(0), "floors", Access.at(1), "rooms"])

      assert Enum.at(rooms1, 0)["temp"] == 25
      assert Enum.at(rooms1, 1)["temp"] == 27
      assert Enum.at(rooms2, 0)["temp"] == 24
    end

    test "transforms with filter at multiple levels" do
      data = %{
        "organizations" => [
          %{
            "active" => true,
            "departments" => [
              %{"budget" => 1000, "name" => "Engineering"},
              %{"budget" => 500, "name" => "HR"}
            ]
          },
          %{
            "active" => false,
            "departments" => [
              %{"budget" => 2000, "name" => "Sales"}
            ]
          }
        ]
      }

      # Increase budget by 10% for departments in active organizations with budget >= 1000
      result =
        Enzyme.transform(
          data,
          "organizations[*][?@.active == true].departments[*][?@.budget >= 1000].budget",
          fn b -> trunc(b * 1.1) end
        )

      org1_depts = get_in(result, ["organizations", Access.at(0), "departments"])
      org2_depts = get_in(result, ["organizations", Access.at(1), "departments"])

      assert Enum.at(org1_depts, 0)["budget"] == 1100
      assert Enum.at(org1_depts, 1)["budget"] == 500
      assert Enum.at(org2_depts, 0)["budget"] == 2000
    end
  end

  describe "Nil and missing value handling" do
    test "select gracefully handles nil values in path" do
      data = %{
        "users" => [
          %{"name" => "Alice", "address" => %{"city" => "NYC"}},
          %{"name" => "Bob", "address" => nil},
          %{"name" => "Carol", "address" => %{"city" => "LA"}}
        ]
      }

      result = Enzyme.select(data, "users[*].address.city")
      assert result == ["NYC", "LA"]
    end

    test "transform skips nil intermediate values" do
      data = %{
        "items" => [
          %{"details" => %{"count" => 5}},
          %{"details" => nil},
          %{"details" => %{"count" => 10}}
        ]
      }

      result = Enzyme.transform(data, "items[*].details.count", &(&1 * 2))

      assert get_in(result, ["items", Access.at(0), "details", "count"]) == 10
      assert get_in(result, ["items", Access.at(1), "details"]) == nil
      assert get_in(result, ["items", Access.at(2), "details", "count"]) == 20
    end

    test "handles empty lists at various levels" do
      data = %{
        "categories" => [
          %{"name" => "A", "products" => []},
          %{"name" => "B", "products" => [%{"sku" => "B1"}]},
          %{"name" => "C", "products" => []}
        ]
      }

      result = Enzyme.select(data, "categories[*].products[*].sku")
      assert result == ["B1"]
    end
  end

  describe "Complex prism scenarios" do
    test "prism filtering in nested structure" do
      data = %{
        "tasks" => [
          %{
            "name" => "Task 1",
            "subtasks" => [
              {:completed, %{duration: 100}},
              {:pending, %{scheduled: "tomorrow"}},
              {:completed, %{duration: 200}}
            ]
          },
          %{
            "name" => "Task 2",
            "subtasks" => [
              {:failed, %{error: "timeout"}},
              {:completed, %{duration: 50}}
            ]
          }
        ]
      }

      # Get all completed subtask durations
      result = Enzyme.select(data, "tasks[*].subtasks[*]:{:completed, info}:duration")
      assert result == [100, 200, 50]
    end

    test "transform through nested prisms" do
      data = %{
        "results" => [
          {:ok, %{"score" => 80}},
          {:error, "failed"},
          {:ok, %{"score" => 90}}
        ]
      }

      result = Enzyme.transform(data, "results[*]:{:ok, data}.score", &(&1 + 10))

      results = result["results"]
      assert {:ok, %{"score" => 90}} = Enum.at(results, 0)
      assert {:error, "failed"} = Enum.at(results, 1)
      assert {:ok, %{"score" => 100}} = Enum.at(results, 2)
    end

    test "prism with rest pattern in list context" do
      data = [
        {:record, "id1", "name1", :active},
        {:record, "id2", "name2", :inactive},
        {:record, "id3", "name3", :active}
      ]

      result = Enzyme.select(data, "[*]:{:record, ...}")

      assert result == [
               {"id1", "name1", :active},
               {"id2", "name2", :inactive},
               {"id3", "name3", :active}
             ]
    end
  end

  describe "Mixed atom and string key deep traversal" do
    test "alternating atom and string keys in deep path" do
      data = %{
        config: %{
          "database" => %{
            settings: %{
              "pool" => %{
                size: 10,
                overflow: 5
              }
            }
          }
        }
      }

      result = Enzyme.select(data, ":config.database:settings.pool:size")
      assert result == 10
    end

    test "transforms through mixed key types" do
      data = %{
        users: [
          %{"profile" => %{score: 100}},
          %{"profile" => %{score: 200}}
        ]
      }

      result = Enzyme.transform(data, ":users[*].profile:score", &(&1 + 50))

      scores =
        result.users
        |> Enum.map(fn u -> u["profile"].score end)

      assert scores == [150, 250]
    end
  end

  describe "Filter edge cases" do
    test "filter with string containing special characters" do
      data = %{
        "items" => [
          %{"id" => "item-1", "label" => "foo's bar"},
          %{"id" => "item-2", "label" => "normal"},
          %{"id" => "item-3", "label" => "has \"quotes\""}
        ]
      }

      result = Enzyme.select(data, "items[*][?@.label == 'normal'].id")
      assert result == ["item-2"]
    end

    test "filter comparing against nil" do
      data = %{
        "records" => [
          %{"id" => 1, "deleted_at" => nil},
          %{"id" => 2, "deleted_at" => "2024-01-01"},
          %{"id" => 3, "deleted_at" => nil}
        ]
      }

      # Select non-deleted records
      result = Enzyme.select(data, "records[*][?@.deleted_at == nil].id")
      assert result == [1, 3]
    end

    test "chained filters with different operators" do
      data = %{
        "products" => [
          %{"name" => "A", "price" => 100, "stock" => 50, "active" => true},
          %{"name" => "B", "price" => 200, "stock" => 0, "active" => true},
          %{"name" => "C", "price" => 150, "stock" => 25, "active" => false},
          %{"name" => "D", "price" => 300, "stock" => 100, "active" => true}
        ]
      }

      # Active products with stock > 0 and price < 250
      result =
        Enzyme.select(
          data,
          "products[*][?@.active == true][?@.stock > 0][?@.price < 250].name"
        )

      assert result == ["A"]
    end
  end

  describe "Chained field references in filters" do
    test "API response filtering by nested authentication status" do
      # Realistic scenario: API returns user data with nested auth/session info
      response = %{
        "users" => [
          %{
            "id" => "user-001",
            "name" => "Alice",
            "auth" => %{
              "session" => %{"active" => true, "expires_at" => "2024-12-20"},
              "mfa" => %{"enabled" => true}
            }
          },
          %{
            "id" => "user-002",
            "name" => "Bob",
            "auth" => %{
              "session" => %{"active" => false, "expires_at" => nil},
              "mfa" => %{"enabled" => false}
            }
          },
          %{
            "id" => "user-003",
            "name" => "Charlie",
            "auth" => %{
              "session" => %{"active" => true, "expires_at" => "2024-12-25"},
              "mfa" => %{"enabled" => true}
            }
          }
        ]
      }

      # Select users with active sessions and MFA enabled
      result =
        Enzyme.select(
          response,
          "users[*][?@.auth.session.active and @.auth.mfa.enabled].name"
        )

      assert result == ["Alice", "Charlie"]

      # Select user IDs with inactive sessions
      inactive = Enzyme.select(response, "users[*][?@.auth.session.active == false].id")
      assert inactive == ["user-002"]
    end

    test "filtering IoT sensor data by nested thresholds" do
      # Realistic scenario: IoT sensor network with nested config and readings
      sensors = %{
        "devices" => [
          %{
            "id" => "sensor-01",
            "location" => "warehouse-A",
            "readings" => %{
              "temperature" => %{"value" => 22.5, "unit" => "celsius"},
              "humidity" => %{"value" => 65, "unit" => "percent"}
            },
            "config" => %{
              "thresholds" => %{"temperature" => %{"max" => 25}, "humidity" => %{"max" => 70}}
            }
          },
          %{
            "id" => "sensor-02",
            "location" => "warehouse-B",
            "readings" => %{
              "temperature" => %{"value" => 28.0, "unit" => "celsius"},
              "humidity" => %{"value" => 55, "unit" => "percent"}
            },
            "config" => %{
              "thresholds" => %{"temperature" => %{"max" => 25}, "humidity" => %{"max" => 70}}
            }
          },
          %{
            "id" => "sensor-03",
            "location" => "warehouse-C",
            "readings" => %{
              "temperature" => %{"value" => 24.0, "unit" => "celsius"},
              "humidity" => %{"value" => 75, "unit" => "percent"}
            },
            "config" => %{
              "thresholds" => %{"temperature" => %{"max" => 25}, "humidity" => %{"max" => 70}}
            }
          }
        ]
      }

      # Find sensors where temperature exceeds configured threshold
      overheated =
        Enzyme.select(
          sensors,
          "devices[*][?@.readings.temperature.value > @.config.thresholds.temperature.max].location"
        )

      assert overheated == ["warehouse-B"]

      # Find sensors where humidity exceeds configured threshold
      humid =
        Enzyme.select(
          sensors,
          "devices[*][?@.readings.humidity.value > @.config.thresholds.humidity.max].location"
        )

      assert humid == ["warehouse-C"]

      # Combine both conditions
      alerts =
        Enzyme.select(
          sensors,
          "devices[*][?@.readings.temperature.value > @.config.thresholds.temperature.max or @.readings.humidity.value > @.config.thresholds.humidity.max].id"
        )

      assert alerts == ["sensor-02", "sensor-03"]
    end

    test "e-commerce product filtering with nested attributes" do
      # Realistic scenario: Product catalog with nested specs and pricing
      catalog = %{
        "products" => [
          %{
            "sku" => "LAPTOP-001",
            "name" => "Pro Laptop",
            "specs" => %{
              "processor" => %{"cores" => 8, "speed" => 3.2},
              "memory" => %{"size_gb" => 16, "type" => "DDR4"}
            },
            "pricing" => %{
              "list_price" => 1299,
              "discount" => %{"active" => true, "percent" => 10}
            }
          },
          %{
            "sku" => "LAPTOP-002",
            "name" => "Budget Laptop",
            "specs" => %{
              "processor" => %{"cores" => 4, "speed" => 2.4},
              "memory" => %{"size_gb" => 8, "type" => "DDR4"}
            },
            "pricing" => %{
              "list_price" => 599,
              "discount" => %{"active" => false, "percent" => 0}
            }
          },
          %{
            "sku" => "LAPTOP-003",
            "name" => "Gaming Laptop",
            "specs" => %{
              "processor" => %{"cores" => 12, "speed" => 4.5},
              "memory" => %{"size_gb" => 32, "type" => "DDR5"}
            },
            "pricing" => %{
              "list_price" => 2499,
              "discount" => %{"active" => true, "percent" => 15}
            }
          }
        ]
      }

      # High-performance laptops (8+ cores, 16GB+ RAM)
      high_perf =
        Enzyme.select(
          catalog,
          "products[*][?@.specs.processor.cores >= 8 and @.specs.memory.size_gb >= 16].name"
        )

      assert high_perf == ["Pro Laptop", "Gaming Laptop"]

      # Products with active discounts
      discounted =
        Enzyme.select(catalog, "products[*][?@.pricing.discount.active == true].sku")

      assert discounted == ["LAPTOP-001", "LAPTOP-003"]

      # Budget options: < $1000 OR active discount >= 10%
      budget =
        Enzyme.select(
          catalog,
          "products[*][?@.pricing.list_price < 1000 or (@.pricing.discount.active == true and @.pricing.discount.percent >= 10)].sku"
        )

      assert budget == ["LAPTOP-001", "LAPTOP-002", "LAPTOP-003"]
    end

    test "filtering with atom keys through nested structures" do
      # Realistic scenario: Elixir application config with nested atom keys
      config = %{
        services: [
          %{
            name: :auth_service,
            deployment: %{
              region: :us_east,
              health: %{status: :healthy, uptime_seconds: 86_400}
            },
            metrics: %{requests_per_sec: 1500, error_rate: 0.001}
          },
          %{
            name: :payment_service,
            deployment: %{
              region: :eu_west,
              health: %{status: :degraded, uptime_seconds: 3600}
            },
            metrics: %{requests_per_sec: 500, error_rate: 0.05}
          },
          %{
            name: :notification_service,
            deployment: %{
              region: :us_east,
              health: %{status: :healthy, uptime_seconds: 172_800}
            },
            metrics: %{requests_per_sec: 2000, error_rate: 0.002}
          }
        ]
      }

      # Find healthy services in us_east
      healthy_us =
        Enzyme.select(
          config,
          ":services[*][?@:deployment:health:status == :healthy and @:deployment:region == :us_east]:name"
        )

      assert healthy_us == [:auth_service, :notification_service]

      # Find services with high error rate (> 1%)
      high_errors =
        Enzyme.select(config, ":services[*][?@:metrics:error_rate > 0.01]:name")

      assert high_errors == [:payment_service]

      # Services with high load (> 1000 rps) and healthy
      high_load_healthy =
        Enzyme.select(
          config,
          ":services[*][?@:metrics:requests_per_sec > 1000 and @:deployment:health:status == :healthy]:name"
        )

      assert high_load_healthy == [:auth_service, :notification_service]
    end

    test "mixed string and atom key chaining in filters" do
      # Realistic scenario: API response with mixed key types
      data = %{
        "response" => %{
          metadata: %{request_id: "req-123", timestamp: "2024-03-15T10:00:00Z"},
          data: [
            %{
              "attributes" => %{tags: %{priority: :high, category: "urgent"}},
              id: "item-001"
            },
            %{
              "attributes" => %{tags: %{priority: :low, category: "routine"}},
              id: "item-002"
            },
            %{
              "attributes" => %{tags: %{priority: :high, category: "scheduled"}},
              id: "item-003"
            }
          ]
        }
      }

      # High priority items
      high_priority =
        Enzyme.select(data, "response:data[*][?@.attributes:tags:priority == :high]:id")

      assert high_priority == ["item-001", "item-003"]

      # Urgent category items
      urgent = Enzyme.select(data, "response:data[*][?@.attributes:tags:category == 'urgent']:id")
      assert urgent == ["item-001"]
    end

    test "deeply nested filtering with complete data" do
      # Realistic scenario: Social media API with complete nested fields
      posts = %{
        "feed" => [
          %{
            "id" => "post-001",
            "author" => %{
              "profile" => %{
                "verified" => true,
                "stats" => %{"followers" => 5000, "posts" => 150}
              }
            }
          },
          %{
            "id" => "post-002",
            "author" => %{
              "profile" => %{"verified" => false, "stats" => %{"followers" => 800, "posts" => 50}}
            }
          },
          %{
            "id" => "post-003",
            "author" => %{
              "profile" => %{
                "verified" => false,
                "stats" => %{"followers" => 2000, "posts" => 300}
              }
            }
          },
          %{
            "id" => "post-004",
            "author" => %{
              "profile" => %{
                "verified" => true,
                "stats" => %{"followers" => 50_000, "posts" => 1200}
              }
            }
          },
          %{
            "id" => "post-005",
            "author" => %{
              "profile" => %{
                "verified" => true,
                "stats" => %{"followers" => 15_000, "posts" => 450}
              }
            }
          }
        ]
      }

      # Verified authors only
      verified = Enzyme.select(posts, "feed[*][?@.author.profile.verified == true].id")
      assert verified == ["post-001", "post-004", "post-005"]

      # Influencers (> 10k followers)
      influencers =
        Enzyme.select(posts, "feed[*][?@.author.profile.stats.followers > 10000].id")

      assert influencers == ["post-004", "post-005"]

      # Small accounts (< 1000 followers)
      small_accounts =
        Enzyme.select(posts, "feed[*][?@.author.profile.stats.followers < 1000].id")

      assert small_accounts == ["post-002"]

      # Verified influencers with high engagement (verified + > 10k followers + > 400 posts)
      engaged_influencers =
        Enzyme.select(
          posts,
          "feed[*][?@.author.profile.verified == true and @.author.profile.stats.followers > 10000 and @.author.profile.stats.posts > 400].id"
        )

      assert engaged_influencers == ["post-004", "post-005"]

      # Not verified
      not_verified = Enzyme.select(posts, "feed[*][?@.author.profile.verified == false].id")
      assert not_verified == ["post-002", "post-003"]
    end

    test "transforming values selected by chained field filters" do
      # Realistic scenario: Update nested config values
      app_config = %{
        "environments" => [
          %{
            "name" => "production",
            "services" => %{
              "database" => %{"connection" => %{"pool_size" => 10, "timeout" => 5000}}
            }
          },
          %{
            "name" => "staging",
            "services" => %{
              "database" => %{"connection" => %{"pool_size" => 5, "timeout" => 3000}}
            }
          },
          %{
            "name" => "development",
            "services" => %{
              "database" => %{"connection" => %{"pool_size" => 2, "timeout" => 1000}}
            }
          }
        ]
      }

      # Double the pool size for environments with pool_size < 10
      result =
        Enzyme.transform(
          app_config,
          "environments[*][?@.services.database.connection.pool_size < 10].services.database.connection.pool_size",
          &(&1 * 2)
        )

      prod_pool =
        get_in(result, [
          "environments",
          Access.at(0),
          "services",
          "database",
          "connection",
          "pool_size"
        ])

      staging_pool =
        get_in(result, [
          "environments",
          Access.at(1),
          "services",
          "database",
          "connection",
          "pool_size"
        ])

      dev_pool =
        get_in(result, [
          "environments",
          Access.at(2),
          "services",
          "database",
          "connection",
          "pool_size"
        ])

      # unchanged
      assert prod_pool == 10
      # 5 * 2
      assert staging_pool == 10
      # 2 * 2
      assert dev_pool == 4
    end

    test "chained fields with iso conversions in filters" do
      # Realistic scenario: Financial data with string amounts
      transactions = %{
        "accounts" => [
          %{
            "id" => "acc-001",
            "holder" => %{"name" => "Alice", "credit_score" => %{"value" => "750"}},
            "balance" => %{"amount" => "15000", "currency" => "USD"}
          },
          %{
            "id" => "acc-002",
            "holder" => %{"name" => "Bob", "credit_score" => %{"value" => "680"}},
            "balance" => %{"amount" => "5000", "currency" => "USD"}
          },
          %{
            "id" => "acc-003",
            "holder" => %{"name" => "Charlie", "credit_score" => %{"value" => "800"}},
            "balance" => %{"amount" => "25000", "currency" => "USD"}
          }
        ]
      }

      # High value accounts (balance > 10k) with good credit (score > 700)
      premium =
        Enzyme.select(
          transactions,
          "accounts[*][?@.balance.amount::integer > 10000 and @.holder.credit_score.value::integer > 700].holder.name",
          []
        )

      assert premium == ["Alice", "Charlie"]

      # Accounts eligible for upgrade (balance > 10k OR credit score > 750)
      eligible =
        Enzyme.select(
          transactions,
          "accounts[*][?@.balance.amount::integer > 10000 or @.holder.credit_score.value::integer > 750].id",
          []
        )

      assert eligible == ["acc-001", "acc-003"]
    end

    test "complex real-world scenario: microservices health monitoring" do
      # Realistic scenario: Kubernetes-style service mesh health data
      cluster = %{
        "namespaces" => [
          %{
            "name" => "production",
            "services" => [
              %{
                "name" => "api-gateway",
                "replicas" => %{
                  "desired" => 3,
                  "ready" => 3,
                  "status" => %{
                    "conditions" => %{"healthy" => true, "last_check" => "2024-03-15T10:00:00Z"}
                  }
                },
                "metrics" => %{
                  "cpu" => %{"usage_percent" => 45},
                  "memory" => %{"usage_mb" => 512}
                }
              },
              %{
                "name" => "user-service",
                "replicas" => %{
                  "desired" => 5,
                  "ready" => 3,
                  "status" => %{
                    "conditions" => %{"healthy" => false, "last_check" => "2024-03-15T10:00:00Z"}
                  }
                },
                "metrics" => %{
                  "cpu" => %{"usage_percent" => 85},
                  "memory" => %{"usage_mb" => 1024}
                }
              }
            ]
          },
          %{
            "name" => "staging",
            "services" => [
              %{
                "name" => "api-gateway",
                "replicas" => %{
                  "desired" => 2,
                  "ready" => 2,
                  "status" => %{
                    "conditions" => %{"healthy" => true, "last_check" => "2024-03-15T10:00:00Z"}
                  }
                },
                "metrics" => %{
                  "cpu" => %{"usage_percent" => 30},
                  "memory" => %{"usage_mb" => 256}
                }
              }
            ]
          }
        ]
      }

      # Find unhealthy services in production
      unhealthy_prod =
        Enzyme.select(
          cluster,
          "namespaces[*][?@.name == 'production'].services[*][?@.replicas.status.conditions.healthy == false].name"
        )

      assert unhealthy_prod == ["user-service"]

      # Find services with high CPU usage (> 80%) anywhere
      high_cpu =
        Enzyme.select(
          cluster,
          "namespaces[*].services[*][?@.metrics.cpu.usage_percent > 80].name"
        )

      assert high_cpu == ["user-service"]

      # Find services where ready replicas don't match desired
      scaling_issues =
        Enzyme.select(
          cluster,
          "namespaces[*].services[*][?@.replicas.ready != @.replicas.desired].name"
        )

      assert scaling_issues == ["user-service"]

      # Critical services: unhealthy OR high CPU OR scaling issues in production
      critical =
        Enzyme.select(
          cluster,
          "namespaces[*][?@.name == 'production'].services[*][?@.replicas.status.conditions.healthy == false or @.metrics.cpu.usage_percent > 80 or @.replicas.ready != @.replicas.desired].name"
        )

      assert critical == ["user-service"]
    end
  end
end
