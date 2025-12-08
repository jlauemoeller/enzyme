defmodule Enzyme.Prism do
  @moduledoc """
  A prism that matches and extracts values from tagged tuples (sum types).

  Prisms are optics for working with tuples that may or may not match a particular
  shape. Unlike lenses which always focus on a present value, prisms may fail to
  match, in which case they return %None{} (for select) or leave the value unchanged
  (for transform).

  ## Pattern Syntax

  Prisms use a pattern syntax to specify which tagged tuples to match and which
  elements to extract:

  | Pattern | Input | Output |
  |---------|-------|--------|
  | `:{:ok, v}` | `{:ok, 5}` | `5` (single named -> unwrap) |
  | `:{:rectangle, w, h}` | `{:rectangle, 3, 4}` | `{3, 4}` (multiple -> tuple) |
  | `:{:rectangle, _, h}` | `{:rectangle, 3, 4}` | `4` (single named -> unwrap) |
  | `:{:point3d, x, _, z}` | `{:point3d, 1, 2, 3}` | `{1, 3}` (named ones, in order) |
  | `:{:rectangle, ...}` | `{:rectangle, 3, 4}` | `{3, 4}` (everything after tag) |
  | `:{:rectangle, _, _}` | `{:rectangle, 3, 4}` | `{:rectangle, 3, 4}` (filter only) |

  ## Retagging Syntax

  Prisms support retagging extracted tuples using the `->` arrow syntax:

  **Shorthand (tag-only change):**
  | Pattern | Input | Output |
  |---------|-------|--------|
  | `:{:ok, v} -> :success` | `{:ok, 5}` | `{:success, 5}` |
  | `:{:rectangle, w, h} -> :box` | `{:rectangle, 3, 4}` | `{:box, 3, 4}` |
  | `:{:ok, ...} -> :success` | `{:ok, 1, 2, 3}` | `{:success, 1, 2, 3}` |
  | `:{:ok, _} -> :success` | `{:ok, 5}` | `{:success, 5}` (filter-only retag) |

  **Explicit assembly (reorder, drop, duplicate):**
  | Pattern | Input | Output |
  |---------|-------|--------|
  | `:{:pair, a, b} -> :{:swapped, b, a}` | `{:pair, 1, 2}` | `{:swapped, 2, 1}` |
  | `:{:point3d, x, y, z} -> :{:point2d, x, z}` | `{:point3d, 1, 2, 3}` | `{:point2d, 1, 3}` |
  | `:{:data, v} -> :{:double, v, v}` | `{:data, 42}` | `{:double, 42, 42}` |

  ## Examples

      # Create a prism for {:ok, value} tuples
      iex> prism = Enzyme.Prism.new(:ok, [:value])
      iex> Enzyme.Prism.select(prism, {:ok, 5})
      %Enzyme.Single{value: 5}

      iex> prism = Enzyme.Prism.new(:ok, [:value])
      iex> Enzyme.Prism.select(prism, {:error, "oops"})
      %Enzyme.None{}

      # Create a prism that extracts multiple values
      iex> prism = Enzyme.Prism.new(:rectangle, [:w, :h])
      iex> Enzyme.Prism.select(prism, {:rectangle, 3, 4})
      %Enzyme.Single{value: {3, 4}}

      # Create a prism that ignores some positions
      iex> prism = Enzyme.Prism.new(:rectangle, [nil, :h])
      iex> Enzyme.Prism.select(prism, {:rectangle, 3, 4})
      %Enzyme.Single{value: 4}

      # Filter-only prism (all positions ignored)
      iex> prism = Enzyme.Prism.new(:ok, [nil])
      iex> Enzyme.Prism.select(prism, {:ok, 5})
      %Enzyme.Single{value: {:ok, 5}}

      # Retag with shorthand syntax (use the high-level Enzyme API)
      iex> Enzyme.select({:ok, 42}, ":{:ok, v} -> :success")
      {:success, 42}

      # Retag with explicit assembly
      iex> Enzyme.select({:point3d, 1, 2, 3}, ":{:point3d, x, y, z} -> :{:point2d, x, z}")
      {:point2d, 1, 3}

  """

  defstruct [:tag, :pattern, :rest, :output_tag, :output_pattern]

  import Enzyme.Guards
  import Enzyme.Wraps

  alias Enzyme.Prism
  alias Enzyme.Types

  @type t :: %Prism{
          tag: atom(),
          pattern: list() | nil,
          rest: boolean(),
          output_tag: atom() | nil,
          output_pattern: list() | :rest | nil
        }

  @doc """
  Creates a new prism for a tagged tuple.

  ## Parameters

  - `tag` - The atom tag to match (first element of tuple)
  - `pattern` - List of extraction specs. Use atom/string names to extract,
    `nil` to ignore. Use `:...` for rest pattern (extract all after tag).

  ## Examples

      Enzyme.Prism.new(:ok, [:value])           # {:ok, v} -> v
      Enzyme.Prism.new(:error, [:reason])       # {:error, r} -> r
      Enzyme.Prism.new(:rectangle, [:w, :h])    # {:rectangle, w, h} -> {w, h}
      Enzyme.Prism.new(:rectangle, [nil, :h])   # {:rectangle, _, h} -> h
      Enzyme.Prism.new(:rectangle, :...)        # {:rectangle, ...} -> {w, h}
      Enzyme.Prism.new(:ok, [nil])              # {:ok, _} -> {:ok, _} (filter only)

  """

  @spec new(atom(), list() | :...) :: Prism.t()
  def new(tag, :...) when is_atom(tag) do
    %Prism{tag: tag, pattern: nil, rest: true}
  end

  @spec new(atom(), list() | :...) :: Prism.t()
  def new(tag, pattern) when is_atom(tag) and is_list(pattern) do
    %Prism{tag: tag, pattern: pattern, rest: false}
  end

  @doc """
  Selects and extracts values from a tagged tuple if it matches the prism.

  Returns `%Enzyme.Single{value: value}` or `%Enzyme.Many{values: list}` wrapped
  results.

  For non-matching tuples, returns `%Enzyme.None{}` or filters them out of lists.
  """

  @spec select(Prism.t(), Types.collection() | Types.wrapped()) :: Types.wrapped()

  def select(%Prism{} = prism, %Enzyme.Single{value: value}) do
    select(prism, value)
  end

  def select(%Prism{} = prism, %Enzyme.Many{values: collection}) when is_list(collection) do
    results =
      collection
      |> Enum.map(&select(prism, &1))
      |> Enum.filter(fn
        %Enzyme.None{} -> false
        _ -> true
      end)
      |> Enum.map(&unwrap/1)

    many(results)
  end

  def select(%Prism{} = prism, list) when is_list(list) do
    results =
      list
      |> Enum.map(&select(prism, &1))
      |> Enum.filter(fn
        %Enzyme.None{} -> false
        _ -> true
      end)
      |> Enum.map(&unwrap/1)

    many(results)
  end

  def select(%Prism{tag: tag, rest: true} = prism, tuple)
      when is_tuple(tuple) and tuple_size(tuple) >= 1 do
    if elem(tuple, 0) == tag do
      extracted = extract_rest(tuple)
      single(apply_output_assembly(prism, extracted, tuple))
    else
      none()
    end
  end

  def select(%Prism{tag: tag, pattern: pattern} = prism, tuple)
      when is_tuple(tuple) and tuple_size(tuple) >= 1 do
    if elem(tuple, 0) == tag and tuple_size(tuple) == length(pattern) + 1 do
      extracted = extract_pattern(tuple, pattern)
      single(apply_output_assembly(prism, extracted, tuple))
    else
      none()
    end
  end

  def select(%Prism{}, _other) do
    none()
  end

  @doc """
  Transforms values in a tagged tuple if it matches the prism.

  For non-matching tuples, returns them unchanged.
  The transform function receives the extracted value(s) and should return
  the new value(s) in the same shape.
  """

  @spec transform(Prism.t(), Types.collection() | Types.wrapped(), (any() -> any())) ::
          Types.wrapped()

  def transform(%Prism{} = prism, wrapped, fun)
      when is_wrapped(wrapped) and is_transform(fun) do
    transform_wrapped(wrapped, fun, &transform(prism, &1, &2))
  end

  def transform(%Prism{} = prism, list, fun) when is_list(list) and is_transform(fun) do
    many(Enum.map(list, fn item -> unwrap(transform(prism, item, fun)) end))
  end

  def transform(%Prism{tag: tag, rest: true} = prism, tuple, fun)
      when is_tuple(tuple) and tuple_size(tuple) >= 1 and is_transform(fun) do
    if elem(tuple, 0) == tag do
      extracted = extract_rest(tuple)
      transformed = fun.(extracted)
      output_tag = prism.output_tag || tag
      single(rebuild_rest(output_tag, transformed, tuple_size(tuple) - 1, prism))
    else
      single(tuple)
    end
  end

  def transform(%Prism{tag: tag, pattern: pattern} = prism, tuple, fun)
      when is_tuple(tuple) and tuple_size(tuple) >= 1 and is_transform(fun) do
    if elem(tuple, 0) == tag and tuple_size(tuple) == length(pattern) + 1 do
      extracted = extract_pattern(tuple, pattern)

      if filter_only?(pattern) do
        # Filter-only: transform receives whole tuple, retagging if needed
        single(maybe_retag_tuple(fun.(tuple), prism.output_tag))
      else
        transformed = fun.(extracted)
        output_tag = prism.output_tag || tag
        single(rebuild_pattern(output_tag, tuple, pattern, transformed, prism))
      end
    else
      single(tuple)
    end
  end

  def transform(%Prism{}, other, _fun) do
    single(other)
  end

  # Extract all elements after the tag
  defp extract_rest(tuple) do
    size = tuple_size(tuple)

    case size do
      1 -> {}
      2 -> elem(tuple, 1)
      _ -> tuple |> Tuple.to_list() |> tl() |> List.to_tuple()
    end
  end

  # Extract elements according to pattern (nil = ignore, anything else = extract)
  defp extract_pattern(tuple, pattern) do
    extracted =
      pattern
      |> Enum.with_index(1)
      |> Enum.filter(fn {spec, _idx} -> spec != nil end)
      |> Enum.map(fn {_spec, idx} -> elem(tuple, idx) end)

    case extracted do
      # Filter-only: return original tuple
      [] -> tuple
      # Single extraction: unwrap
      [single] -> single
      # Multiple: return as tuple
      multiple -> List.to_tuple(multiple)
    end
  end

  # Check if pattern extracts nothing (all nils)
  defp filter_only?(pattern) do
    Enum.all?(pattern, &is_nil/1)
  end

  # Apply output assembly after extraction (for select operations)
  defp apply_output_assembly(%Prism{output_tag: nil}, extracted, _original_tuple) do
    # No retagging - return extracted value as-is
    extracted
  end

  defp apply_output_assembly(
         %Prism{output_tag: output_tag, output_pattern: nil, pattern: pattern},
         extracted,
         original_tuple
       )
       when is_list(pattern) do
    # Shorthand retag: keep extracted values, change tag
    # Special case: filter-only (all nils) retags whole tuple
    if filter_only?(pattern) do
      maybe_retag_tuple(original_tuple, output_tag)
    else
      # Wrap extracted value(s) with new tag
      assemble_output(output_tag, extracted)
    end
  end

  defp apply_output_assembly(
         %Prism{output_tag: output_tag, output_pattern: nil, rest: true},
         extracted,
         _original_tuple
       ) do
    # Shorthand retag with rest pattern: keep all extracted, change tag
    assemble_output(output_tag, extracted)
  end

  defp apply_output_assembly(
         %Prism{output_tag: output_tag, output_pattern: output_pattern, pattern: pattern},
         extracted,
         _original_tuple
       )
       when is_list(pattern) do
    # Explicit assembly: reassemble according to output_pattern
    reassemble_with_pattern(output_tag, extracted, pattern, output_pattern)
  end

  defp apply_output_assembly(
         %Prism{output_tag: output_tag, output_pattern: output_pattern, rest: true},
         extracted,
         _original_tuple
       ) do
    # Explicit assembly with rest pattern
    # extracted is already the values, reassemble according to output_pattern
    if output_pattern == :rest do
      # output pattern is also rest - keep all
      assemble_output(output_tag, extracted)
    else
      # Reassemble specific pattern from rest extraction
      extracted_list = if is_tuple(extracted), do: Tuple.to_list(extracted), else: [extracted]
      reassemble_from_list(output_tag, extracted_list, output_pattern)
    end
  end

  # Retag a tuple (change its first element)
  defp maybe_retag_tuple(tuple, nil) when is_tuple(tuple) do
    tuple
  end

  defp maybe_retag_tuple(tuple, new_tag) when is_tuple(tuple) do
    [_ | rest] = Tuple.to_list(tuple)
    List.to_tuple([new_tag | rest])
  end

  # Assemble output from extracted value(s) - wraps with tag
  defp assemble_output(tag, extracted) do
    if is_tuple(extracted) do
      # Already a tuple - wrap with tag
      List.to_tuple([tag | Tuple.to_list(extracted)])
    else
      # Single value - make tuple
      {tag, extracted}
    end
  end

  # Reassemble extracted values according to output pattern
  defp reassemble_with_pattern(output_tag, extracted, input_pattern, output_pattern) do
    # Build map of extracted names to values
    extracted_values = if is_tuple(extracted), do: Tuple.to_list(extracted), else: [extracted]

    extracted_names =
      input_pattern
      |> Enum.with_index()
      |> Enum.filter(fn {spec, _idx} -> spec != nil end)
      |> Enum.map(fn {spec, _idx} -> spec end)

    name_to_value = Enum.zip(extracted_names, extracted_values) |> Map.new()

    # Assemble according to output pattern
    output_values = Enum.map(output_pattern, fn name -> Map.fetch!(name_to_value, name) end)

    List.to_tuple([output_tag | output_values])
  end

  # Reassemble from a list of extracted values (for rest pattern with explicit output)
  defp reassemble_from_list(output_tag, values, output_indices) when is_list(output_indices) do
    output_values = Enum.map(output_indices, fn idx -> Enum.at(values, idx) end)
    List.to_tuple([output_tag | output_values])
  end

  # Rebuild tuple from rest-style extraction
  defp rebuild_rest(tag, transformed, arity, %Prism{output_pattern: nil}) do
    # No output pattern - use same structure
    elements =
      case arity do
        0 -> []
        1 -> [transformed]
        _ when is_tuple(transformed) -> Tuple.to_list(transformed)
        _ -> [transformed]
      end

    List.to_tuple([tag | elements])
  end

  defp rebuild_rest(tag, transformed, _arity, %Prism{output_pattern: output_pattern})
       when is_list(output_pattern) do
    # Explicit output pattern - reassemble
    transformed_list =
      if is_tuple(transformed), do: Tuple.to_list(transformed), else: [transformed]

    reassemble_from_list(tag, transformed_list, output_pattern)
  end

  defp rebuild_rest(tag, transformed, arity, %Prism{output_pattern: :rest}) do
    # Output pattern is rest - same as no pattern
    rebuild_rest(tag, transformed, arity, %Prism{output_pattern: nil})
  end

  # Rebuild tuple from pattern-style extraction
  defp rebuild_pattern(tag, original_tuple, pattern, transformed, %Prism{output_pattern: nil}) do
    # No output pattern - replace in original positions
    # Get indices that were extracted (non-nil pattern positions)
    extract_indices =
      pattern
      |> Enum.with_index(1)
      |> Enum.filter(fn {spec, _idx} -> spec != nil end)
      |> Enum.map(fn {_spec, idx} -> idx end)

    # Convert transformed back to list
    transformed_values =
      case {extract_indices, transformed} do
        {[_single], value} -> [value]
        {_multiple, tuple} when is_tuple(tuple) -> Tuple.to_list(tuple)
        {_multiple, value} -> [value]
      end

    # Build replacement map
    replacements = Enum.zip(extract_indices, transformed_values) |> Map.new()

    # Rebuild the tuple
    elements =
      for i <- 0..(tuple_size(original_tuple) - 1) do
        if i == 0 do
          # Use output tag (might be different from original)
          tag
        else
          Map.get(replacements, i, elem(original_tuple, i))
        end
      end

    List.to_tuple(elements)
  end

  defp rebuild_pattern(tag, _original_tuple, pattern, transformed, %Prism{
         output_pattern: output_pattern
       })
       when is_list(output_pattern) do
    # Explicit output pattern - reassemble from scratch
    transformed_list =
      if is_tuple(transformed), do: Tuple.to_list(transformed), else: [transformed]

    # Build map from input pattern names to transformed values
    extracted_names =
      pattern
      |> Enum.filter(fn spec -> spec != nil end)

    name_to_value = Enum.zip(extracted_names, transformed_list) |> Map.new()

    # Assemble according to output pattern
    output_values = Enum.map(output_pattern, fn name -> Map.fetch!(name_to_value, name) end)

    List.to_tuple([tag | output_values])
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Prism do
  def select(prism, collection), do: Enzyme.Prism.select(prism, collection)
  def transform(prism, collection, fun), do: Enzyme.Prism.transform(prism, collection, fun)
end
