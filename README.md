# Enzyme

A powerful Elixir library for digesting, querying, and transforming deeply nested data structures using an expressive path syntax.

[![CI](https://github.com/jlauemoeller/enzyme/actions/workflows/ci.yml/badge.svg)](https://github.com/jlauemoeller/enzyme/actions/workflows/ci.yml)

## Overview

Enzyme lets you precisely locate and transform data deep within Elixir data structures using an intuitive path syntax. Rather than manually traversing nested maps and lists, you can extract or modify specific values with indexing, slicing, wildcards, filters, and prisms. The library even converts data between different representations on the fly making it ideal for processing JSON API responses,configuration files, or working with complex text fixtures. Enzyme implements functional lenses under the hood, but no lens theory knowledge is required to use it effectively.

## Example

Imagine you're working with an e-commerce API that returns product data with prices stored as Euro cent strings and timestamps in ISO8601 format:

```elixir
# Raw API response (parsed JSON)
products = %{
  "items" => [
    %{"name" => "Laptop", "price" => "129999", "updated_at" => "2024-01-15T10:30:00Z"},
    %{"name" => "Mouse", "price" => "2499", "updated_at" => "2024-01-14T15:45:00Z"},
    %{"name" => "Keyboard", "price" => "7999", "updated_at" => "2024-01-16T09:20:00Z"}
  ]
}
```

### Selecting Data

Let's start by extracting all item names:

```elixir
Enzyme.select(products, "items[*].name")
# => ["Laptop", "Mouse", "Keyboard"]
```

Maybe we want both names and prices:

```elixir
Enzyme.select(products, "items[*][name,price]")
# => [
#  %{"name" => "Laptop", "price" => "129999"},
#  %{"name" => "Keyboard", "price" => "7999"}
# ]
```

Or just the names of the first two items:

```elixir
Enzyme.select(products, "items[0,1].name")
# => ["Laptop", "Mouse"]
```

Working with prices as strings is not ideal. Let's define a custom bidirectional mapping (a so-called _isomorphism_) between cents-as-strings and euros-as-floats (ignoring for a moment that we should never use floats for monetary values in real code). Every isomorphism concists of two functions, "forward" and "backward", so data can be converted both ways:

```elixir
# Define a custom iso for cents <-> euros
cents_iso = Enzyme.iso(
  &(String.to_integer(&1) / 100),          # string cents -> euros
  &(Integer.to_string(trunc(&1 * 100)))    # euros -> string cents
)

isos = [cents: cents_iso]
```

As a diagram, the `cents_iso` looks like this:

```text

                         forward >
        ┌────────────────────────────────────────┐
        │                                        │
        │                                        ▼
┌───────────────┐                         ┌─────────────┐
│    String     │       cents_iso         │    Float    │
└───────────────┘                         └─────────────┘
        ▲                                        │
        │                                        │
        └────────────────────────────────────────┘
                        < backward

```

We can now extract all prices as floating point euro amounts:

```elixir
Enzyme.select(products, "items[*].price::cents", isos)
# => [1299.99, 24.99, 79.99]
```

You can read `price::cents` as "price as cents" (or, if you are into lenses, "price viewed through the cents isomorphism" ... yeah, heady).

### Transforming Data

Let's apply a 10% discount to all items over €50, automatically converting to/from cents. We'll use a filter expression to select only the expensive items:

```elixir
Enzyme.transform(
  products,
  "items[*][?price::cents > 50].price::cents",
  fn price -> price * 0.9 end,
  isos
)
# => %{"items" => [
#  %{"name" => "Laptop", "price" => "116999", ...}, # $1169.99
#  %{"name" => "Mouse", "price" => "2499", ...}, # unchanged
#  %{"name" => "Keyboard", "price" => "7199", ...} # $71.99
# ]}
```

Notice how we use the `cents` iso both in the `[?filter]` expression and on the price field itself. Unlike `select` and filter expressions,
`transform` first applies the "forward" function to convert the selected data to the working representation, hand that to the transformation function, and then applies the inverse "backward" function to convert the transformed value back to the base representation. This final value then replaces the original value in the data structure.

Here's what that looks like as a diagram:

```text
                         forward >
        ┌────────────────────────────────────────┐
        │                                        │
        │                                        ▼
┌───────────────┐                         ┌─────────────┐
│    String     │                         │    Float    │
└───────────────┘                         └─────────────┘
        ▲                                        │
        │                cents_iso               │ transform
        │                                        ▼
        │                                 ┌─────────────┐
        │                                 │    Float    │
        │                                 └─────────────┘
        │                                        │
        │                                        │
        └────────────────────────────────────────┘
                         < backward

```

### Built-in isomorphisms

Enzyme comes with several built-in isomorphisms such as `integer` and `float` for common conversions (see full list below). Using the built-in `iso8601` isomorphism for instance, we can query items updated after a specific date:

```elixir
Enzyme.select(
  products,
  "items[*][?updated_at::iso8601 > '2024-01-15T00:00:00Z'::iso8601].name"
)
# => ["Laptop", "Keyboard"]
```

Filter expressions use `compare/2` for comparisons if defined for the data type, so you can safely compare e.g dates without worrying about Erlang term ordering getting in the way.

## Tracing

Enzyme supports tracing lens operations to help you understand how paths navigate data structures. Enable tracing by passing `__trace__: true` to `Enzyme.select/3` or `Enzyme.transform/4`. You can also pass a device ID (such as a `StringIO` instance) to redirect output. The trace displays each step in the path, showing the current focus, the lens operation applied, and the resulting values, with indentation representing traversal depth.

```elixir
data = [
  %{"user" => %{"name" => "alice", "age" => 30}},
  %{"user" => %{"name" => "bob", "age" => 25}}
]

Enzyme.select(data, "[*].user.name", __trace__: true)
⏺ single([
┆     %{"user" => %{"age" => 30, "name" => "alice"}},
┆     %{"user" => %{"age" => 25, "name" => "bob"}}
┆   ])[*]
┆   └ ▶ many([
┆   ┆     single(%{"user" => %{"age" => 30, "name" => "alice"}}),
┆   ┆     single(%{"user" => %{"age" => 25, "name" => "bob"}})
┆   ┆   ]).user
┆   ┆   └ ◆ single(%{"age" => 30, "name" => "alice"})
┆   ┆   └ ◆ single(%{"age" => 25, "name" => "bob"})
┆   ┆   └ ▶ many([
┆   ┆   ┆     single(%{"age" => 30, "name" => "alice"}),
┆   ┆   ┆     single(%{"age" => 25, "name" => "bob"})
┆   ┆   ┆   ]).name
┆   ┆   ┆   └ ◆ single("alice")
┆   ┆   ┆   └ ◆ single("bob")
┆   ┆   └ ◀ many([single("alice"), single("bob")])
⏹ many([single("alice"), single("bob")])
```

Each line shows how the focus moves deeper into the data structure as lenses are
applied, with markers indicating events:

- `⏺` indicates the starting point of the lens focus
- `▶` indicates a step forward in the matching process
- `◀` data being returned from a lens step
- `◆` indicates a successful match at that step
- `⏹` indicates the end of the trace with the final result
- `!` indicates an abrupt end of the trace, such as an exception

The `single` and `many` markers indicate whether the focus is on a single value or multiple values at that point in the path.

## Features

- **Path-based or programmatic construction**: Lenses can be constructed either from string paths or programmatically. Paths can include slices, wildcards, filters, prisms, and isomorphisms. In most cases, the path syntax is more concise and easier to read but programmatic construction is available for dynamic scenarios and for when you need filters that cannot be expressed in the path syntax.
- **Filter expressions**: The lens focus can be fine tuned using filter expressions with logical operators and comparison operators. Isomorphisms can be applied within filters for type-safe comparisons.
- **Prisms**: You can select and filter tagged tuples (aka. "sum types") like `{:ok, value}` and `{:error, reason}`. Enzyme supports optional retagging and value reassembly so you can project sum types into different shapes.
- **Extensible Isomorphisms**: Lenses can use bidirectional transformations (isomorphims) for viewing or transforming data through a conversion layer. You can use built-in isos or define arbitrarily complex custom ones.
- **Composable**: Lenses can be composed together to create complex queries and transformations from smaller reusable parts.
- **Reusable**: Create reusable lens objects or selector/transformer functions for repeated use. This improves performance by avoiding repeated parsing of path strings.
- **Efficient**: Designed for performance with minimal overhead. The parser is a fast recursive descent parser, and lens operations are optimized for common use cases.
- **Works with JSON**: Ideal for querying and transforming parsed JSON data structures. The built-in `json` isomorphism makes it easy to work with JSON strings and becomes active if the Jason library is available.

## Installation

Add `enzyme` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:enzyme, "~> 0.4.0"}
  ]
end
```

## Path Syntax

Paths are recipes for how to navigate and manipulate data structures. The Enzyme parser compiles path strings into lens objects that can be used with `Enzyme.select/3` and `Enzyme.transform/4`. To understand how a path works, read it from left to right, applying each segment in sequence to the data structure. By doing so, you move the "focus" -- written @ -- into the data structure until you reach the end of the path, the end of the data structure, or a point where the path no longer matches. If there is a match, the `select` operation returns the value(s) at the current focus, while `transform` applies a function to the focus and replaces it with the result of the transformation.

Enzyme allows you to work with complex data structures in a declarative way where you specify _where_ you want to extract or change data rather than _how_ to traverse the data structure step-by-step. This leads to more concise and maintainable code and makes it much easier to adapt to changing data structures.

One particularly powerful aspect of functional lenses is their ability to conceptually focus on multiple values at once (e.g. all items in a list), and that they can be combined with filters, prisms, and isomorphisms to create complex queries and transformations. The lens focus is not limited to a single "node" in the data structure but simultaneously tracks multiple nodes as needed.

### Dot and Colon Notation

So far, all our examples have been based on parsed JSON which yields nested maps with string keys, and lists. It would seem that keys are always assumed to be strings, making them unsuited for Elixir structs or maps with atom keys. However, the path syntax allows you to work with atom keys as well. Keys are treated as strings when using dot notation but you can use a ':' as the path separator to indicate that a key is an atom. So `company:name` means "first perform a lookup using the string `"company"`, then lookup `:name` in the result. `:company:name` would mean that both keys are atoms. You can mix and match dot and colon notation as needed. Atoms are always converted from strings using `String.to_existing_atom/1`, so make sure the atoms you reference already exist to avoid runtime errors.

Use dot notation to access map keys:

```elixir
data = %{"company" => %Company{name: "Acme", founded: 1990}}

Enzyme.select(data, "company:name")
# => "Acme"

Enzyme.select(data, "company:founded")
# => 1990
```

### Numeric Indices

Access list or tuple elements by index using a familiar bracket notation:

```elixir
data = %{"items" => ["first", "second", "third"]}

Enzyme.select(data, "items[0]")
# => "first"

Enzyme.select(data, "items[2]")
# => "third"

# Select multiple indices (returns a list)
Enzyme.select(data, "items[0,2]")
# => ["first", "third"]
```

### String or Atom Indices

You can also use brackets for string or atom keys and this is especially useful when selecting a slice of multiple keys (which you can also do with numeric indices):

```elixir
data = %{"user" => %{"name" => "Alice", "email" => "alice@example.com", "role" => "admin"}}

# Single key (equivalent to dot notation)
Enzyme.select(data, "user[name]")
# => "Alice"

# Multiple keys
Enzyme.select(data, "user[name,email]")
# => ["Alice", "alice@example.com"]
```

### Wildcards

Use `[*]` to select all elements at the focus:

```elixir
data = %{
  "users" => [
    %{"name" => "Alice", "score" => 95},
    %{"name" => "Bob", "score" => 87}
  ]
}
Enzyme.select(data, "users[*]")
# => [%{"name" => "Alice", "score" => 95}, %{"name" => "Bob", "score" => 87}]

Enzyme.select(data, "users[*].name")
# => ["Alice", "Bob"]

Enzyme.select(data, "users[*].score")
# => [95, 87]
```

The `[*]` operataor generates a lens that distributes the focus over all elements in a list, tuple or map, and continues the traversal of the rest of the path into all elements it selects. You can combine wildcards with filters to control the selection.

### Filter Expressions

Filters help you further narrow down the focus by applying boolean expressions to each element. Only elements for which the expression evaluates to true are kept in the focus.

Filter use an `[?expression]` syntax:

```elixir
data = %{
  "products" => [
    %{"name" => "Widget", "price" => 25, "in_stock" => true},
    %{"name" => "Gadget", "price" => 99, "in_stock" => false},
    %{"name" => "Gizmo", "price" => 50, "in_stock" => true}
  ]
}

# Filter by boolean
Enzyme.select(data, "products[*][?in_stock == true].name")
# => ["Widget", "Gizmo"]

# Filter by string
Enzyme.select(data, "products[*][?name == 'Widget'].price")
# => [25]

# Filter by number
Enzyme.select(data, "products[*][?price == 99].name")
# => ["Gadget"]

# Inequality
Enzyme.select(data, "products[*][?in_stock != true].name")
# => ["Gadget"]

# Comparison operators
Enzyme.select(data, "products[*][?price > 30].name")
# => ["Gadget", "Gizmo"]

Enzyme.select(data, "products[*][?price <= 50].name")
# => ["Widget", "Gizmo"]
```

#### Filter Operators

You can use the following operators to build filter expressions:

| Operator | Description                                     |
| -------- | ----------------------------------------------- |
| `==`     | Equality (Erlang term comparison)               |
| `!=`     | Inequality                                      |
| `<`      | Less than                                       |
| `<=`     | Less than or equal                              |
| `>`      | Greater than                                    |
| `>=`     | Greater than or equal                           |
| `~~`     | String equality (converts both sides to string) |
| `!~`     | String inequality                               |
| not      | Logical NOT                                     |
| and      | Logical AND                                     |
| or       | Logical OR                                      |

The `~~` and `!~` operators convert their operands to strings using `to_string/1` before comparison and come in handy when working with heterogeneous data (but see the section on isomorphisms for a more type-safe approach).

```elixir
# String-based comparison
data = %{"items" => [%{type: :book}, %{"type" => "book"}]}

# Matches both atom and string
Enzyme.select(data, "items[*][?type ~~ 'book']")
# => [%{type: :book}, %{"type" => "book"}]
```

Combine conditions using `and`, `or`, and `not`:

```elixir
data = %{
  "users" => [
    %{"name" => "Alice", "active" => true, "role" => "admin"},
    %{"name" => "Bob", "active" => true, "role" => "user"},
    %{"name" => "Charlie", "active" => false, "role" => "admin"}
  ]
}

# AND: both conditions must be true
Enzyme.select(data, "users[*][?active == true and role == 'admin'].name")
# => ["Alice"]

# OR: either condition can be true
Enzyme.select(data, "users[*][?role == 'admin' or role == 'superuser'].name")
# => ["Alice", "Charlie"]

# NOT: negate a condition
Enzyme.select(data, "users[*][?not active == true].name")
# => ["Charlie"]
```

**Operator Precedence** (highest to lowest):

1. `not` - unary negation
2. `and` - logical conjunction
3. `or` - logical disjunction

Use parentheses to override default precedence:

```elixir
data = %{
  "products" => [
    %{"name" => "Widget", "price" => 25, "category" => "tools", "featured" => true},
    %{"name" => "Gadget", "price" => 150, "category" => "electronics", "featured" => false},
    %{"name" => "Gizmo", "price" => 50, "category" => "tools", "featured" => false}
  ]
}

# Without parentheses: featured OR (electronics AND price > 100)
Enzyme.select(data, "products[*][?featured == true or category == 'electronics' and price > 100].name")
# => ["Widget", "Gadget"]

# With parentheses: (featured OR electronics) AND price > 100
Enzyme.select(data, "products[*][?(featured == true or category == 'electronics') and price > 100].name")
# => ["Gadget"]

# NOT with parentheses
Enzyme.select(data, "products[*][?not (category == 'tools' and featured == false)].name")
# => ["Widget", "Gadget"]
```

#### Chained Filters

You can chain multiple filters for AND logic:

```elixir
data = %{
  "employees" => [
    %{"name" => "Alice", "dept" => "Engineering", "level" => "senior"},
    %{"name" => "Bob", "dept" => "Engineering", "level" => "junior"},
    %{"name" => "Charlie", "dept" => "Sales", "level" => "senior"}
  ]
}

# Senior engineers only
Enzyme.select(data, "employees[*][?dept == 'Engineering'][?level == 'senior'].name")
# => ["Alice"]
```

#### Focus Reference

Use `@` to reference the current focus within filter expressions:

```elixir
data = %{"scores" => [85, 92, 78, 95, 88]}

# Filter primitive values
Enzyme.select(data, "scores[*][?@ == 95]")
# => [95]

# @.field is equivalent to field
Enzyme.select(data, "users[*][?@.active == true].name")
# Same as: "users[*][?active == true].name"
```

#### Isos in Filters

You can use the syntax `::iso` in filter expressions to transform values before comparison:

```elixir
# Data has counts stored as strings
data = %{
  "items" => [
    %{"name" => "a", "count" => "42"},
    %{"name" => "b", "count" => "7"},
    %{"name" => "c", "count" => "42"}
  ]
}

# Filter by converted integer value (left side)
Enzyme.select(data, "items[*][?count::integer == 42].name", [])
# => ["a", "c"]

# Filter by converted integer value (right side)
data = %{"items" => [%{"value" => 42}, %{"value" => 7}]}
Enzyme.select(data, "items[*][?value == '42'::integer]", [])
# => [%{"value" => 42}]

# Both sides with isos
data = %{"items" => [%{"left" => "10", "right" => "10"}]}
Enzyme.select(data, "items[*][?left::integer == right::integer]", [])
# => [%{"left" => "10", "right" => "10"}]

# Chain isos: decode base64, then parse as integer
data = %{"codes" => [Base.encode64("42"), Base.encode64("7")]}
Enzyme.select(data, "codes[*][?@::base64::integer == 42]", [])
# => ["NDI="]  # (base64 of "42")

# Custom iso
cents_iso = Enzyme.iso(&(&1 / 100), &(trunc(&1 * 100)))
data = %{"items" => [%{"price" => 999}, %{"price" => 1599}]}
Enzyme.select(data, "items[*][?price::cents == 15.99]", cents: cents_iso)
# => [%{"price" => 1599}]
```

### Prisms

Prisms let you work with tagged tuples (or, "sum types") like `{:ok, value}` or `{:error, reason}`. They match tuples by their tag and/or shape and can extract values from specific positions. You can even convert matching tuples into different tuple shapes, or replace elements. Non-matching tuples return `nil` on select or pass through unchanged on transform.

```elixir
# Extract value from {:ok, value} tuples. The named variable `v` indicates
# the position to extract.
Enzyme.select({:ok, 42}, ":{:ok, v}")
# => 42

Enzyme.select({:error, "oops"}, ":{:ok, v}")
# => nil

# Process a list of results, filtering out the successful ones
results = [{:ok, 1}, {:error, "failed"}, {:ok, 2}, {:error, "timeout"}]

Enzyme.select(results, "[*]:{:ok, v}")
# => [1, 2]

# Extract error reasons
Enzyme.select(results, "[*]:{:error, reason}")
# => ["failed", "timeout"]
```

#### Multiple Value Extraction

Extract multiple values from larger tuples:

```elixir
# Extract both width and height as a tuple
Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, w, h}")
# => {3, 4}

# Extract only specific positions using _ to ignore
Enzyme.select({:rectangle, 3, 4}, ":{:rectangle, _, h}")
# => 4

Enzyme.select({:point3d, 1, 2, 3}, ":{:point3d, x, _, z}")
# => {1, 3}
```

#### Rest Pattern

Use `...` to extract all elements after the tag without specifying each position or how many there are:

```elixir
Enzyme.select({:ok, 42}, ":{:ok, ...}")
# => 42

Enzyme.select({:data, 1, 2, 3, 4}, ":{:data, ...}")
# => {1, 2, 3, 4}
```

Prisms only support a single rest pattern at the end of the tuple so something like `{:data, ..., x}` or `{:data, x, ...}` is not allowed.

#### Filter-Only Prisms

Use all `_` to match without extracting. This is useful when yoy are only interested in the shape of the tuplem, or only need to extract certain values:

```elixir
results = [{:ok, 1}, {:error, "x"}, {:ok, 2}]

# Filter to only :ok tuples
Enzyme.select(results, "[*]:{:ok, _}")
# => [{:ok, 1}, {:ok, 2}]
```

#### Transforming with Prisms

Prisms let you transform values inside matching tuples before passing them on through the lens chain:

```elixir
# Double the value inside :ok tuples
Enzyme.transform({:ok, 5}, ":{:ok, v}", &(&1 * 2))
# => {:ok, 10}

# Non-matching tuples pass through unchanged
Enzyme.transform({:error, "x"}, ":{:ok, v}", &(&1 * 2))
# => {:error, "x"}

# Transform in a list
results = [{:ok, 1}, {:error, "x"}, {:ok, 2}]
Enzyme.transform(results, "[*]:{:ok, v}", &(&1 * 10))
# => [{:ok, 10}, {:error, "x"}, {:ok, 20}]
```

#### Prisms in Complex Paths

You can combine prisms with other path components:

```elixir
data = %{
  "responses" => [
    {:ok, %{"user" => %{"name" => "Alice"}}},
    {:error, "not found"},
    {:ok, %{"user" => %{"name" => "Bob"}}}
  ]
}

# Extract names from successful responses only
Enzyme.select(data, "responses[*]:{:ok, v}.user.name")
# => ["Alice", "Bob"]
```

#### Retagging Prisms

Prisms also support retagging to transform sum types by changing tags or reassembling extracted values using the `->` arrow syntax.

**Shorthand retagging (tag-only change):**

```elixir
# Change :ok to :success
Enzyme.select({:ok, 42}, ":{:ok, v} -> :success")
# => {:success, 42}

# Transform and retag
Enzyme.transform({:ok, 5}, ":{:ok, v} -> :success", &(&1 * 2))
# => {:success, 10}

# Retag in lists
results = [{:ok, 1}, {:error, "x"}, {:ok, 2}]
Enzyme.select(results, "[*]:{:ok, v} -> :success")
# => [{:success, 1}, {:success, 2}]

# Retag filter-only (all positions ignored)
Enzyme.select({:ok, 42}, ":{:ok, _} -> :success")
# => {:success, 42}

# Retag with rest pattern
Enzyme.select({:data, 1, 2, 3}, ":{:data, ...} -> :values")
# => {:values, 1, 2, 3}
```

#### Reassembling Prism

Prisms can also reassemble extracted values into new tuple shapes.

```elixir
# Reorder values
Enzyme.select({:pair, 1, 2}, ":{:pair, a, b} -> :{:swapped, b, a}")
# => {:swapped, 2, 1}

# Drop a dimension (3D -> 2D)
Enzyme.select({:point3d, 1, 2, 3}, ":{:point3d, x, y, z} -> :{:point2d, x, z}")
# => {:point2d, 1, 3}

# Duplicate a value
Enzyme.select({:single, 42}, ":{:single, v} -> :{:double, v, v}")
# => {:double, 42, 42}

# Extract non-contiguous positions and reorder
Enzyme.select({:quad, 1, 2, 3, 4}, ":{:quad, a, _, c, _} -> :{:pair, c, a}")
# => {:pair, 3, 1}

# Transform with assembly
Enzyme.transform({:point3d, 0, 0, 0}, ":{:point3d, x, y, z} -> :{:point2d, x, z}", fn {x, z} -> {x + 1, z + 1} end)
# => {:point2d, 1, 1}
```

**Use cases:**

- Normalize API response types (e.g., `:ok`/`:error` → `:success`/`:failure`)
- Simplify data structures (drop unnecessary dimensions)
- Adapt between different sum type conventions across system boundaries

### Isomorphisms (Isos)

Isos let you view and transform data through a conversion layer. They define bidirectional transformations: a `forward` function converts from the stored representation to a working representation, and a `backward` function converts back. `Ensyme.select/3` applies the `forward` function to convert data before extracting it, while `Enzyme.transform/4` applies `forward` before transforming and `backward` after transforming to store the result. That means your transformation function always process data in the working representation created by the `forward` function.

Use `::` to apply an iso in path expressions:

```elixir
# String stored as integer, select returns integer
data = %{"count" => "42"}
Enzyme.select(data, "count::integer", [])
# => 42

# Transform works in integer space, stores back as string
Enzyme.transform(data, "count::integer", &(&1 + 1), [])
# => %{"count" => "43"}
```

#### Built-in Isos

Enxyme ships with a small number of built-in isos for common conversions:

| Iso        | Description                                  | Example                                    |
| ---------- | -------------------------------------------- | ------------------------------------------ |
| `:integer` | String <-> Integer                           | `"42"` <-> `42`                            |
| `:float`   | String <-> Float                             | `"3.14"` <-> `3.14`                        |
| `:atom`    | String <-> Atom                              | `"active"` <-> `:active`                   |
| `:base64`  | Base64 string <-> Decoded binary             | `"aGVsbG8="` <-> `"hello"`                 |
| `:json`    | JSON string <-> Elixir term (requires Jason) | `"{\"a\":1}"` <-> `%{"a" => 1}`            |
| `:iso8601` | ISO8601 string <-> `DateTime` struct         | `"2024-01-01T12:00:00Z"` <-> `%DateTime{}` |
| `:time`    | Time string <-> `Time` struct                | `"14:30:00"` <-> `%Time{}`                 |
| `:date`    | Date string <-> `Date` struct                | `"2024-01-01"` <-> `%Date{}`               |

```elixir
# Decode base64 data
data = %{"secret" => Base.encode64("password123")}
Enzyme.select(data, "secret::base64", [])
# => "password123"

# Parse JSON string
data = %{"config" => ~s({"debug": true})}
Enzyme.select(data, "config::json", [])
# => %{"debug" => true}
```

The `:json` iso requires the `Jason` library to be available. If `Jason` is not present, attempting to use the `:json` iso will result in a runtime error.

#### Custom Isos

You can easily add your own custom isos for domain-specific transformations:

```elixir
# Cents to euros conversion
cents_iso = Enzyme.iso(
  fn cents -> cents / 100 end,       # forward: cents → euros
  fn euros -> trunc(euros * 100) end  # backward: euros → cents
)

data = %{"price" => 1999}  # stored as cents

# Select returns euros
Enzyme.select(data, "price::cents", cents: cents_iso)
# => 19.99

# Add $1 in euro space, stored back as cents
Enzyme.transform(data, "price::cents", &(&1 + 1), cents: cents_iso)
# => %{"price" => 2099}
```

#### Iso Resolution

Iso definitions can be provided at parse time or runtime. Runtime isos always take precedence, allowing you to override isos stored during parsing:

```elixir
# Store iso when creating lens
cents_iso = Enzyme.iso(&(&1 / 100), &(trunc(&1 * 100)))
lens = Enzyme.new("price::cents", cents: cents_iso)

# Uses stored iso
Enzyme.select(%{"price" => 1999}, lens)
# => 19.99

# Runtime iso overrides stored iso
runtime_iso = Enzyme.iso(&(&1 / 1000), &(trunc(&1 * 1000)))
Enzyme.select(%{"price" => 1999}, lens, cents: runtime_iso)
# => 1.999

# Can also provide iso only at runtime
lens = Enzyme.new("price::cents")
Enzyme.select(%{"price" => 1999}, lens, cents: cents_iso)
# => 19.99
```

The resolution priority for isos are: runtime > parse-time > builtins.

This allows you to override built-in isos with your own implementations if needed, and allows you to create reusable lenses with embedded isos for common use cases. BY providing different runtime isos, you can adapt the behavior of such lenses as needed.

#### Chaining Isos

Multiple isos can be chained to create sophisticated transformations:

```elixir
# Data is base64-encoded integer string
data = %{"value" => Base.encode64("42")}

Enzyme.select(data, "value::base64::integer", [])
# => 42
```

#### Isos in Complex Paths

You can combine isos with other path components to control how data is viewed and transformed:

```elixir
data = %{
  "users" => [
    %{"name" => "Alice", "score" => "85"},
    %{"name" => "Bob", "score" => "92"}
  ]
}

# Select all scores as integers
Enzyme.select(data, "users[*].score::integer", [])
# => [85, 92]

# Increment all scores (stored back as strings)
Enzyme.transform(data, "users[*].score::integer", &(&1 + 10), [])
# => %{"users" => [%{"name" => "Alice", "score" => "95"}, %{"name" => "Bob", "score" => "102"}]}
```

## Transforming Data

Use `Enzyme.transform/3` to update values while preserving structure:

```elixir
data = %{
  "users" => [
    %{"name" => "alice", "score" => 85},
    %{"name" => "bob", "score" => 92}
  ]
}

# Transform with a function
Enzyme.transform(data, "users[*].name", &String.capitalize/1)
# => %{"users" => [%{"name" => "Alice", ...}, %{"name" => "Bob", ...}]}

# Transform with a constant value
Enzyme.transform(data, "users[*].score", 0)
# => %{"users" => [%{"name" => "alice", "score" => 0}, ...]}

# Transform only matching elements
Enzyme.transform(data, "users[*][?score == 85].score", fn s -> s + 10 end)
# => %{"users" => [%{"name" => "alice", "score" => 95}, %{"name" => "bob", "score" => 92}]}
```

## Reusable Lenses

Create lens objects to avoid repeated parsing:

```elixir
# Create a lens
user_names = Enzyme.new("users[*].name")

# Use with select
Enzyme.select(data, user_names)

# Create a selector function
get_names = fn data -> Enzyme.select(data, "users[*].name") end
get_names.(data)
# => ["alice", "bob"]

# Create a transformer function
upcase_names = fn data -> Enzyme.transform(data, Enzyme.new("users[*].name"), &String.upcase/1) end
upcase_names.(data)
# => %{"users" => [%{"name" => "ALICE", ...}, ...]}
```

## Working with JSON

Enzyme is particularly useful for working with parsed JSON:

```elixir
json = """
{
  "company": "Acme Corp",
  "departments": [
    {
      "name": "Engineering",
      "employees": [
        {"name": "Alice", "title": "Senior Engineer"},
        {"name": "Bob", "title": "Junior Engineer"}
      ]
    },
    {
      "name": "Sales",
      "employees": [
        {"name": "Charlie", "title": "Sales Manager"}
      ]
    }
  ]
}
"""

data = Jason.decode!(json)

# Get all employee names across all departments
Enzyme.select(data, "departments[*].employees[*].name")
# => ["Alice", "Bob", "Charlie"]

# Get employees from Engineering only
Enzyme.select(data, "departments[*][?name == 'Engineering'].employees[*].name")
# => ["Alice", "Bob"]

# Update all titles
Enzyme.transform(data, "departments[*].employees[*].title", &String.upcase/1)
```

## Path Syntax Reference

| Syntax          | Description                           | Example                                     |
| --------------- | ------------------------------------- | ------------------------------------------- |
| `key`           | Map string key                        | `name`, `user.email`                        |
| `.`             | String key separator                  | `user.name` (both string keys)              |
| `:`             | Atom key separator                    | `:user:name`, `config:debug`                |
| `[n]`           | List index                            | `items[0]`, `users[2]`                      |
| `[n,m,...]`     | Multiple indices                      | `items[0,2,4]`                              |
| `[*]`           | All elements                          | `users[*]`                                  |
| `[key]`         | String key in brackets                | `user[name]`                                |
| `[a,b,...]`     | Multiple string keys                  | `user[name,email]`                          |
| `[:atom]`       | Atom key in brackets                  | `data[:key]`                                |
| `[:a,:b]`       | Multiple atom keys                    | `data[:foo,:bar]`                           |
| `[?expr]`       | Filter expression                     | `users[*][?active == true]`                 |
| `[?a and b]`    | Filter with logical AND               | `[?active == true and role == 'admin']`     |
| `[?a or b]`     | Filter with logical OR                | `[?role == 'admin' or role == 'user']`      |
| `[?not expr]`   | Filter with logical NOT               | `[?not deleted == true]`                    |
| `[?(expr)]`     | Filter with grouping                  | `[?(a == 1 or b == 2) and c == 3]`          |
| `[?f::iso==v]`  | Filter with iso (either/both sides)   | `[?count::integer == '42'::integer]`        |
| `:{:tag, a, b}` | Prism (extract named positions)       | `:{:ok, v}`, `:{:rect, w, h}`               |
| `:{:tag, _, b}` | Prism (ignore positions with `_`)     | `:{:rectangle, _, h}`                       |
| `:{:tag, ...}`  | Prism (extract all after tag)         | `:{:ok, ...}`                               |
| `:{:tag, _}`    | Prism (filter only, no extraction)    | `:{:ok, _}`                                 |
| `:{ } -> :tag`  | Prism retag (shorthand)               | `:{:ok, v} -> :success`                     |
| `:{ } -> :{ }`  | Prism retag (explicit assembly)       | `:{:point3d, x, y, z} -> :{:point2d, x, z}` |
| `key::iso`      | Isomorphism (bidirectional transform) | `count::integer`, `data::base64`            |
| `::iso1::iso2`  | Chained isos                          | `value::base64::json`                       |

## License

MIT License
