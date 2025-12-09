defmodule Enzyme do
  alias Enzyme.All
  alias Enzyme.Filter
  alias Enzyme.Iso
  alias Enzyme.IsoRef
  alias Enzyme.One
  alias Enzyme.Parser
  alias Enzyme.Prism
  alias Enzyme.Protocol
  alias Enzyme.Sequence
  alias Enzyme.Slice

  import Enzyme.Guards
  import Enzyme.Wraps

  @type lens :: All.t() | Filter.t() | Iso.t() | One.t() | Prism.t() | Sequence.t() | Slice.t()

  @moduledoc """
  A powerful Elixir library for querying and transforming deeply nested data structures using an expressive path syntax.

  Enzyme lets you precisely locate and transform data deep within Elixir data structures using an intuitive path syntax. Rather than manually traversing nested maps and lists, you can extract or modify specific values with indexing, slicing, wildcards, filters, and prisms. The library even converts data between different representations automatically making it ideal for processing JSON APIs and configuration files. Enzyme implements functional lenses under the hood, but no lens theory knowledge is required to use it effectively.

  See the [README](README.md) for more information and examples.
  """

  @doc """
  Creates a new lens from a path string.
  """

  @spec new(String.t()) :: lens()
  def new(path) when is_binary(path) do
    Parser.parse(path)
  end

  @doc """
  Creates a new lens from a path string with default iso definitions.

  Iso references in the path (e.g., `"value::cents"`) are stored as references
  and resolved at runtime. The isos provided to `new/2` can be overridden when
  calling `select/3` or `transform/4`.

  ## Examples

      # Define default iso
      cents_iso = Enzyme.iso(&(&1 / 100), &(trunc(&1 * 100)))
      lens = Enzyme.new("price::cents", cents: cents_iso)

      # Use the lens (iso resolved from stored defaults)
      Enzyme.select(%{"price" => 1999}, lens)
      # => 19.99

      # Override at runtime
      other_iso = Enzyme.iso(&(&1 / 1000), &(trunc(&1 * 1000)))
      Enzyme.select(%{"price" => 1999}, lens, cents: other_iso)
      # => 1.999

  """

  @spec new(String.t(), Keyword.t()) :: lens()
  def new(path, opts) when is_binary(path) and is_list(opts) do
    lens = Parser.parse(path)
    store_opts(lens, opts)
  end

  defp store_opts(%Sequence{} = seq, opts), do: %{seq | opts: opts}
  defp store_opts(lens, []), do: lens
  defp store_opts(lens, opts), do: %Sequence{lenses: [lens], opts: opts}

  @doc """
  Creates a lens that selects a single element by index or key.
  """

  @spec one(integer() | binary() | atom()) :: One.t()
  def one(index) when is_index(index) do
    %One{index: index}
  end

  @doc """
  Creates a lens that selects a single element by index or key, composing it
  with an existing lens. The composition is left associative so the existing lens
  is applied first.
  """

  @spec one(lens(), integer() | binary() | atom()) :: Sequence.t()
  def one(lens, index) when is_lens(lens) and is_index(index) do
    %Sequence{lenses: [lens, one(index)]}
  end

  @doc """
  Creates a lens that selects all elements in a collection.
  """

  @spec all() :: All.t()
  def all do
    %All{}
  end

  @doc """
  Creates a lens that selects all elements in a collection, composing it with
  an existing lens. The composition is left associative so the existing lens is
  applied first.
  """

  @spec all(lens()) :: Sequence.t()
  def all(lens) when is_lens(lens) do
    %Sequence{lenses: [lens, all()]}
  end

  @doc """
  Creates a lens that selects multiple elements by indices or keys.
  """

  @spec slice([integer() | binary() | atom()]) :: Slice.t()
  def slice(indices) when is_list(indices) do
    %Slice{indices: indices}
  end

  @doc """
  Creates a lens that selects multiple elements by indices or keys, composing it
  with an existing lens. The composition is left associative so the existing lens
  is applied first.
  """

  @spec slice(lens(), [integer() | binary() | atom()]) :: Sequence.t()
  def slice(lens, indices) when is_lens(lens) and is_list(indices) do
    %Sequence{lenses: [lens, slice(indices)]}
  end

  @doc """
  Creates a lens that filters elements in a collection based on a predicate
  function. The function will receive a focused element in the collection and
  should return a truthy value to keep an element, or a falsy value to exclude it.
  """

  @spec filter((any() -> any())) :: Filter.t()
  def filter(predicate) when is_function(predicate, 1) do
    %Filter{predicate: predicate}
  end

  @doc """
  Creates a lens that filters elements in a collection based on a predicate
  function, composing it with an existing lens. The composition is left
  associative so the existing lens is applied first. The function will receive
  a focused element in the collection and should return a truthy value to keep
  an element, or a falsy value to exclude it.
  """

  @spec filter(lens(), (any() -> any())) :: Sequence.t()
  def filter(lens, predicate) when is_lens(lens) and is_function(predicate, 1) do
    %Sequence{lenses: [lens, filter(predicate)]}
  end

  @doc """
  Creates a lens that rejects elements in a collection based on a predicate
  function. The function will receive a focused element in the collection and
  should return a truthy value to reject an element, or a falsy value to keep it.
  """

  @spec reject((any() -> any())) :: Filter.t()
  def reject(predicate) when is_function(predicate, 1) do
    %Filter{predicate: fn x -> not predicate.(x) end}
  end

  @doc """
  Creates a lens that rejects elements in a collection based on a predicate
  function, composing it with an existing lens. The composition is left
  associative so the existing lens is applied first. The function will receive
  a focused element in the collection and should return a truthy value to reject
  an element, or a falsy value to keep it.
  """

  @spec reject(lens(), (any() -> any())) :: Sequence.t()
  def reject(lens, predicate) when is_lens(lens) and is_function(predicate, 1) do
    %Sequence{lenses: [lens, filter(fn x -> not predicate.(x) end)]}
  end

  @doc """
  Creates a lens that applies multiple lenses in sequence.
  """

  @spec sequence([lens()]) :: Sequence.t()
  def sequence(lenses) when is_list(lenses) do
    %Sequence{lenses: lenses}
  end

  @doc """
  Creates a lens that composes a given lens with a sequence of leneses.The
  composition is left associative so the existing lens is applied first.
  """

  @spec sequence(lens(), [lens()]) :: Sequence.t()
  def sequence(lens, lenses) when is_lens(lens) and is_list(lenses) do
    %Sequence{lenses: [lens | lenses]}
  end

  @doc """
  Creates a prism that matches tagged tuples and extracts values.

  Prisms are optics for sum types (tagged tuples like `{:ok, value}` or
  `{:error, reason}`). They may or may not match - non-matching values
  return nil on select, or pass through unchanged on transform.

  ## Parameters

  - `tag` - The atom tag to match (first element of tuple)
  - `pattern` - Extraction pattern:
    - `:...` - Extract all elements after the tag
    - List of names/nils - Extract named positions, ignore nils

  ## Pattern Semantics

  | Pattern | Input | Output |
  |---------|-------|--------|
  | `[:v]` | `{:ok, 5}` | `5` (single → unwrap) |
  | `[:w, :h]` | `{:rect, 3, 4}` | `{3, 4}` (multiple → tuple) |
  | `[nil, :h]` | `{:rect, 3, 4}` | `4` (only named) |
  | `:...` | `{:rect, 3, 4}` | `{3, 4}` (all after tag) |
  | `[nil]` | `{:ok, 5}` | `{:ok, 5}` (filter only) |

  ## Examples

      iex> prism = Enzyme.prism(:ok, [:value])
      iex> Enzyme.select({:ok, 5}, prism)
      5

      iex> prism = Enzyme.prism(:ok, [:value])
      iex> Enzyme.select({:error, "oops"}, prism)
      nil

      iex> prism = Enzyme.prism(:rectangle, [:w, :h])
      iex> Enzyme.select({:rectangle, 3, 4}, prism)
      {3, 4}

      iex> prism = Enzyme.prism(:ok, :...)
      iex> Enzyme.select({:ok, 5}, prism)
      5

  """
  @spec prism(atom(), :... | [atom() | nil]) :: Prism.t()
  def prism(tag, pattern) when is_atom(tag) do
    Prism.new(tag, pattern)
  end

  @doc """
  Creates a prism composed with an existing lens. The composition is left
  associative so the lens is applied first.

  ## Examples

      iex> lens = Enzyme.one("result") |> Enzyme.prism(:ok, [:v])
      iex> Enzyme.select(%{"result" => {:ok, 42}}, lens)
      42

  """
  def prism(lens, tag, pattern) when is_lens(lens) and is_atom(tag) do
    %Sequence{lenses: [lens, prism(tag, pattern)]}
  end

  @doc """
  Creates a new iso with bidirectional mapping functions.

  ## Parameters

  - `forward` - Function converting from stored to working representation
  - `backward` - Function converting from working back to stored representation

  ## Examples
  ```
      Enzyme.iso(
        fn cents -> cents / 100 end,
        fn dollars -> trunc(dollars * 100) end)
      )
  ```
  """

  @spec iso((any() -> any()), (any() -> any())) :: Iso.t()
  def iso(forward, backward)
      when is_function(forward, 1) and is_function(backward, 1) do
    Iso.new(forward, backward)
  end

  @doc """
  Returns all elements selected by a lens in a data structure. The lens can be
  provided explicitly or as a path string.

  ## Examples

  ```
  iex> data = [%{"name" => "Acme, Inc"}, %{"name" => "Longhorn, Inc"}]
  iex> Enzyme.select(data, "[*].name")
  ["Acme, Inc", "Longhorn, Inc"]
  ```

  ```
  iex> data = [%{"name" => "Acme, Inc"}, %{"name" => "Longhorn, Inc"}]
  iex> Enzyme.select(data, Enzyme.new("[*].name"))
  ["Acme, Inc", "Longhorn, Inc"]
  ```

  ## Specifying isos
  You can optionally provide a keyword list of iso definitions. The isos
  referenced in the path are resolved in this order:

  1. Runtime opts (this parameter)
  2. Compile-time opts (passed to `Enzyme.new/2`)
  3. Built-in isos (see `Enzyme.Iso.Builtins`)

  ### Using a builtin iso
      Enzyme.select(%{"count" => "42"}, "count::integer")
      # => 42

  ### Using a custom iso
      cents_iso = Enzyme.iso(:cents, &(&1 / 100), &(trunc(&1 * 100)))
      Enzyme.select(%{"price" => 1999}, "price::cents", cents: cents_iso)
      # => 19.99

  ### Runtime override of compile-time iso
      lens = Enzyme.new("price::cents", cents: cents_iso)
      other_iso = Enzyme.iso(:cents, &(&1 / 1000), &(trunc(&1 * 1000)))
      Enzyme.select(%{"price" => 1999}, lens, cents: other_iso)
      # => 1.999

  """

  def select(collection, path_or_lens, opts \\ [])

  @spec select(any(), String.t(), Keyword.t()) :: any()
  def select(collection, path, opts) when is_collection(collection) and is_binary(path) do
    select(collection, new(path), opts)
  end

  @spec select(any(), lens(), Keyword.t()) :: any()
  def select(collection, lens, opts) when is_collection(collection) and is_lens(lens) do
    lens
    |> resolve_isos(opts)
    |> Protocol.select(single(collection))
    |> unwrap()
  end

  @doc """
  Updates all elements selected by a lens in a data structure. The lens can be
  provided explicitly or as a path string. The transformation can be provided
  as a function or a value.

  ## Examples

  ```
  iex> data = [%{"name" => "Acme, Inc"}, %{"name" => "Longhorn, Inc"}]
  iex> Enzyme.transform(data, "[*].name", "replaced")
  [
    %{"name" => "replaced"},
    %{"name" => "replaced"}
  ]
  ```

  ```
  iex> data = [%{"name" => "Acme, Inc"}, %{"name" => "Longhorn, Inc"}]
  iex> Enzyme.transform(data, "[*].name", &String.downcase/1)
  [
    %{"name" => "acme, inc"},
    %{"name" => "longhorn, inc"}
  ]
  ```

  ## Specifying isos
  You can optionally provide a keyword list of iso definitions. The isos
  referenced in the path are resolved in this order:

  1. Runtime opts (this parameter)
  2. Compile-time opts (passed to `Enzyme.new/2`)
  3. Built-in isos (see `Enzyme.Iso.Builtins`)

  ### Using a builtin iso - increment string integer, result stored back as string
      Enzyme.transform(%{"count" => "42"}, "count::integer", &(&1 + 1), [])
      # => %{"count" => "43"}

  ### Using a custom iso
      cents_iso = Enzyme.iso(:cents, &(&1 / 100), &(trunc(&1 * 100)))
      Enzyme.transform(%{"price" => 1999}, "price::cents", &(&1 + 1), cents: cents_iso)
      # => %{"price" => 2099}

  """

  def transform(collection, path_or_lens, fun_or_value, opts \\ [])

  @spec transform(any(), String.t(), (any() -> any()) | any(), Keyword.t()) :: any()
  def transform(collection, path, fun, opts)
      when is_collection(collection) and is_binary(path) and is_transform(fun) and is_list(opts) do
    transform(collection, new(path), fun, opts)
  end

  @spec transform(any(), String.t(), any(), Keyword.t()) :: any()
  def transform(collection, path, value, opts)
      when is_collection(collection) and is_binary(path) and is_list(opts) do
    transform(collection, new(path), fn _ -> value end, opts)
  end

  @spec transform(any(), lens(), (any() -> any()) | any(), Keyword.t()) :: any()
  def transform(collection, lens, fun, opts)
      when is_collection(collection) and is_lens(lens) and is_transform(fun) and is_list(opts) do
    lens
    |> resolve_isos(opts)
    |> Protocol.transform(single(collection), fun)
    |> unwrap()
  end

  @spec transform(any(), lens(), any(), Keyword.t()) :: any()
  def transform(collection, lens, value, opts)
      when is_collection(collection) and is_lens(lens) and is_list(opts) do
    transform(collection, lens, fn _ -> value end, opts)
  end

  # Private: Resolve any IsoRefs in a lens structure
  # Resolution order: runtime opts > stored opts > builtins
  defp resolve_isos(%Sequence{lenses: lenses, opts: stored_opts}, runtime_opts) do
    # Merge opts: runtime opts take precedence over stored opts
    merged_opts = Keyword.merge(stored_opts, runtime_opts)
    %Sequence{lenses: Enum.map(lenses, &resolve_isos(&1, merged_opts)), opts: []}
  end

  defp resolve_isos(%IsoRef{name: name}, opts) do
    # IsoRef - resolve from opts, then builtins
    case Keyword.get(opts, name) do
      %Iso{} = resolved ->
        resolved

      nil ->
        # Try builtins
        case Iso.Builtins.get(name) do
          %Iso{} = builtin -> builtin
          nil -> raise ArgumentError, unresolved_iso_error(name)
        end

      other ->
        raise ArgumentError,
              "Expected %Enzyme.Iso{} for '#{name}' in opts, got: #{inspect(other)}"
    end
  end

  # Handle Filter with unresolved isos in expression
  defp resolve_isos(%Filter{predicate: nil, expression: expr} = filter, opts)
       when not is_nil(expr) do
    # Resolve isos in the expression, then compile to predicate
    resolved_expr = Enzyme.ExpressionParser.resolve_expression_isos(expr, opts)
    predicate = Enzyme.ExpressionParser.compile(resolved_expr)
    %Filter{filter | predicate: predicate, expression: nil}
  end

  # Pass through other lens types unchanged (Iso, already-resolved Filters, etc.)
  defp resolve_isos(lens, _opts), do: lens

  defp unresolved_iso_error(name) do
    builtins = Iso.Builtins.names() |> Enum.map_join(", ", &inspect/1)

    "Iso '#{name}' is not resolved. " <>
      "Provide it via opts (e.g., #{name}: my_iso) or use a builtin. " <>
      "Available builtins: #{builtins}"
  end
end
