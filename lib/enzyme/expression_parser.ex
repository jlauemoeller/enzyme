defmodule Enzyme.ExpressionParser do
  @moduledoc false
  # Parses and compiles filter expressions for the Enzyme path language.
  #
  # Supports the following expression grammar:
  # - expression := or_expr
  # - or_expr := and_expr ('or' and_expr)*
  # - and_expr := not_expr ('and' not_expr)*
  # - not_expr := 'not' not_expr | primary
  # - primary := '(' expression ')' | comparison
  # - comparison := operand cmp_operator operand
  # - operand := ('@' | field | literal) iso_chain?
  # - field := '@.'? identifier
  # - iso_chain := '::' identifier iso_chain?
  # - literal := string | number | boolean | atom_literal
  # - cmp_operator := '==' | '!=' | '<' | '<=' | '>' | '>=' | '~~' | '!~'

  # ## ISO Support

  # Both left and right operands support optional iso chains for type conversion:

  #     # Left side only
  #     items[*][?count::integer == 42]

  #     # Right side only
  #     items[*][?value == '42'::integer]

  #     # Both sides
  #     items[*][?left::integer == right::integer]

  #     # Chained isos
  #     items[*][?code::base64 == '42']

  alias Enzyme.Expression
  alias Enzyme.Iso
  alias Enzyme.IsoRef

  @doc """
  Parses a filter expression string into an Expression struct.

  ## Examples

      iex> Enzyme.ExpressionParser.parse("field == 'value'")
      %Enzyme.Expression{
        left: {:field, "field"},
        operator: :eq,
        right: {:literal, "value"}
      }

      iex> Enzyme.ExpressionParser.parse("@ == 42")
      %Enzyme.Expression{
        left: {:self},
        operator: :eq,
        right: {:literal, 42}
      }

  """
  def parse(input), do: parse(input, [])

  @doc """
  Parses a filter expression with opts for iso resolution.

  Isos referenced in the expression (e.g., `field::integer`) will be resolved
  from opts if provided, otherwise stored as unresolved for later resolution.

  Supports logical operators `and`, `or`, `not` and parentheses for grouping.
  Operator precedence (lowest to highest): or, and, not, comparison operators.
  """
  def parse(input, opts) when is_list(opts) do
    input = String.trim(input)
    {expr, rest} = parse_or_expr(input, opts)

    if String.trim(rest) != "" do
      raise "Unexpected characters after expression: #{rest}"
    end

    expr
  end

  # Parse or_expr: and_expr ('or' and_expr)*
  defp parse_or_expr(input, opts) do
    {left, rest} = parse_and_expr(input, opts)
    parse_or_rest(left, String.trim(rest), opts)
  end

  defp parse_or_rest(left, "or" <> rest, opts) do
    # Check it's not part of a larger identifier
    check_keyword_boundary(rest, "or")
    {right, remaining} = parse_and_expr(String.trim(rest), opts)
    expr = %Expression{left: left, operator: :or, right: right}
    parse_or_rest(expr, String.trim(remaining), opts)
  end

  defp parse_or_rest(expr, rest, _opts), do: {expr, rest}

  # Parse and_expr: not_expr ('and' not_expr)*
  defp parse_and_expr(input, opts) do
    {left, rest} = parse_not_expr(input, opts)
    parse_and_rest(left, String.trim(rest), opts)
  end

  defp parse_and_rest(left, "and" <> rest, opts) do
    # Check it's not part of a larger identifier
    check_keyword_boundary(rest, "and")
    {right, remaining} = parse_not_expr(String.trim(rest), opts)
    expr = %Expression{left: left, operator: :and, right: right}
    parse_and_rest(expr, String.trim(remaining), opts)
  end

  defp parse_and_rest(expr, rest, _opts), do: {expr, rest}

  # Parse not_expr: 'not' not_expr | primary
  defp parse_not_expr("not" <> rest, opts) do
    # Check it's not part of a larger identifier
    check_keyword_boundary(rest, "not")
    {expr, remaining} = parse_not_expr(String.trim(rest), opts)
    {%Expression{left: nil, operator: :not, right: expr}, remaining}
  end

  defp parse_not_expr(input, opts), do: parse_primary(input, opts)

  # Parse primary: '(' expression ')' | comparison
  defp parse_primary("(" <> rest, opts) do
    {expr, remaining} = parse_or_expr(String.trim(rest), opts)

    case String.trim(remaining) do
      ")" <> after_paren -> {expr, after_paren}
      other -> raise "Expected closing ')' but found: #{String.slice(other, 0, 10)}"
    end
  end

  defp parse_primary(input, opts), do: parse_comparison(input, opts)

  # Parse comparison: operand cmp_operator operand
  defp parse_comparison(input, opts) do
    {left, rest} = parse_operand(input, opts)
    {operator, rest} = parse_cmp_operator(String.trim(rest))
    {right, rest} = parse_operand(String.trim(rest), opts)
    {%Expression{left: left, operator: operator, right: right}, rest}
  end

  # Check that a keyword isn't part of a larger identifier
  defp check_keyword_boundary(rest, keyword) do
    case rest do
      "" ->
        :ok

      <<char, _::binary>> when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ ->
        raise "Expected whitespace after '#{keyword}' but found continuation"

      _ ->
        :ok
    end
  end

  @doc """
  Compiles an Expression into a predicate function.

  ## Examples

      iex> expr = Enzyme.ExpressionParser.parse("name == 'test'")
      iex> pred = Enzyme.ExpressionParser.compile(expr)
      iex> pred.(%{name: "test"})
      true
      iex> pred.(%{name: "other"})
      false

  """
  # Compile logical NOT
  def compile(%Expression{left: nil, operator: :not, right: right}) do
    right_pred = compile(right)
    fn element -> not right_pred.(element) end
  end

  # Compile logical AND
  def compile(%Expression{
        left: %Expression{} = left,
        operator: :and,
        right: %Expression{} = right
      }) do
    left_pred = compile(left)
    right_pred = compile(right)
    fn element -> left_pred.(element) and right_pred.(element) end
  end

  # Compile logical OR
  def compile(%Expression{
        left: %Expression{} = left,
        operator: :or,
        right: %Expression{} = right
      }) do
    left_pred = compile(left)
    right_pred = compile(right)
    fn element -> left_pred.(element) or right_pred.(element) end
  end

  # Compile comparison expression
  def compile(%Expression{left: left, operator: op, right: right}) do
    fn element ->
      left_val = resolve_operand(left, element)
      right_val = resolve_operand(right, element)
      apply_operator(op, left_val, right_val)
    end
  end

  @doc """
  Returns true if the expression contains any isos (resolved or unresolved).
  """
  # Logical NOT
  def has_isos?(%Expression{left: nil, operator: :not, right: right}) do
    has_isos?(right)
  end

  # Logical AND/OR
  def has_isos?(%Expression{
        left: %Expression{} = left,
        operator: op,
        right: %Expression{} = right
      })
      when op in [:and, :or] do
    has_isos?(left) or has_isos?(right)
  end

  # Comparison
  def has_isos?(%Expression{left: left, right: right}) do
    operand_has_isos?(left) or operand_has_isos?(right)
  end

  defp operand_has_isos?({:field_with_isos, _name, _isos}), do: true
  defp operand_has_isos?({:self_with_isos, _isos}), do: true
  defp operand_has_isos?({:literal_with_isos, _value, _isos}), do: true
  defp operand_has_isos?(_), do: false

  @doc """
  Returns true if the expression contains any unresolved isos.
  """
  # Logical NOT
  def has_unresolved_isos?(%Expression{left: nil, operator: :not, right: right}) do
    has_unresolved_isos?(right)
  end

  # Logical AND/OR
  def has_unresolved_isos?(%Expression{
        left: %Expression{} = left,
        operator: op,
        right: %Expression{} = right
      })
      when op in [:and, :or] do
    has_unresolved_isos?(left) or has_unresolved_isos?(right)
  end

  # Comparison
  def has_unresolved_isos?(%Expression{left: left, right: right}) do
    operand_has_unresolved_isos?(left) or operand_has_unresolved_isos?(right)
  end

  defp operand_has_unresolved_isos?({:field_with_isos, _name, isos}), do: any_unresolved?(isos)
  defp operand_has_unresolved_isos?({:self_with_isos, isos}), do: any_unresolved?(isos)
  defp operand_has_unresolved_isos?({:literal_with_isos, _value, isos}), do: any_unresolved?(isos)
  defp operand_has_unresolved_isos?(_), do: false

  defp any_unresolved?(isos) do
    Enum.any?(isos, fn
      %IsoRef{} -> true
      %Iso{} -> false
    end)
  end

  @doc """
  Resolves all unresolved isos in an expression using the provided opts and builtins.
  """
  # Logical NOT
  def resolve_expression_isos(%Expression{left: nil, operator: :not, right: right} = expr, opts) do
    %Expression{expr | right: resolve_expression_isos(right, opts)}
  end

  # Logical AND/OR
  def resolve_expression_isos(
        %Expression{left: %Expression{} = left, operator: op, right: %Expression{} = right} = expr,
        opts
      )
      when op in [:and, :or] do
    %Expression{
      expr
      | left: resolve_expression_isos(left, opts),
        right: resolve_expression_isos(right, opts)
    }
  end

  # Comparison
  def resolve_expression_isos(%Expression{left: left, right: right} = expr, opts) do
    %Expression{
      expr
      | left: resolve_operand_isos(left, opts),
        right: resolve_operand_isos(right, opts)
    }
  end

  defp resolve_operand_isos({:field_with_isos, name, isos}, opts) do
    {:field_with_isos, name, resolve_iso_list(isos, opts)}
  end

  defp resolve_operand_isos({:self_with_isos, isos}, opts) do
    {:self_with_isos, resolve_iso_list(isos, opts)}
  end

  defp resolve_operand_isos({:literal_with_isos, value, isos}, opts) do
    {:literal_with_isos, value, resolve_iso_list(isos, opts)}
  end

  defp resolve_operand_isos(operand, _opts), do: operand

  defp resolve_iso_list(isos, opts) do
    Enum.map(isos, fn iso_or_ref -> resolve_single_iso(iso_or_ref, opts) end)
  end

  # Already resolved Iso - pass through
  defp resolve_single_iso(%Iso{} = iso, _opts), do: iso

  # IsoRef - resolve from opts or builtins
  defp resolve_single_iso(%IsoRef{name: name}, opts) do
    case Keyword.get(opts, name) do
      %Iso{} = resolved ->
        resolved

      nil ->
        case Iso.Builtins.get(name) do
          %Iso{} = builtin -> builtin
          nil -> raise_unresolved_iso_error(name)
        end

      other ->
        raise ArgumentError,
              "Expected %Enzyme.Iso{} for '#{name}' in opts, got: #{inspect(other)}"
    end
  end

  defp raise_unresolved_iso_error(name) do
    builtins = Iso.Builtins.names() |> Enum.map_join(", ", &inspect/1)

    raise ArgumentError,
          "Iso '#{name}' is not resolved. " <>
            "Provide it via opts (e.g., #{name}: my_iso) or use a builtin. " <>
            "Available builtins: #{builtins}"
  end

  # Parse an operand: @, @.field, field, or literal (with optional ::iso chain)
  defp parse_operand("@." <> rest, opts) do
    # Field access with @ prefix
    {field_name, remaining} = parse_identifier(rest)
    # Check for iso chain after field
    {isos, remaining} = parse_iso_chain(remaining, opts)
    {wrap_with_isos({:field, field_name}, isos), remaining}
  end

  defp parse_operand("@" <> rest, opts) do
    # Check if it's just @ (self reference) or @. (field access)
    trimmed = String.trim_leading(rest)

    if String.starts_with?(trimmed, ".") do
      # Actually @. field access - but we already consumed @, so handle @.
      {field_name, remaining} = parse_identifier(String.trim_leading(trimmed, "."))
      # Check for iso chain after field
      {isos, remaining} = parse_iso_chain(remaining, opts)
      {wrap_with_isos({:field, field_name}, isos), remaining}
    else
      # Self reference - check for iso chain
      {isos, remaining} = parse_iso_chain(rest, opts)
      {wrap_with_isos({:self}, isos), remaining}
    end
  end

  defp parse_operand("'" <> rest, opts) do
    # Single-quoted string
    parse_string(rest, "'", opts)
  end

  defp parse_operand("\"" <> rest, opts) do
    # Double-quoted string
    parse_string(rest, "\"", opts)
  end

  defp parse_operand("true" <> rest, opts) do
    check_identifier_boundary(rest, "true")
    {isos, remaining} = parse_iso_chain(rest, opts)
    {wrap_with_isos({:literal, true}, isos), remaining}
  end

  defp parse_operand("false" <> rest, opts) do
    check_identifier_boundary(rest, "false")
    {isos, remaining} = parse_iso_chain(rest, opts)
    {wrap_with_isos({:literal, false}, isos), remaining}
  end

  defp parse_operand("nil" <> rest, opts) do
    check_identifier_boundary(rest, "nil")
    {isos, remaining} = parse_iso_chain(rest, opts)
    {wrap_with_isos({:literal, nil}, isos), remaining}
  end

  defp parse_operand(":" <> rest, opts) do
    # Atom literal
    {atom_name, remaining} = parse_identifier(rest)
    {isos, remaining} = parse_iso_chain(remaining, opts)
    {wrap_with_isos({:literal, String.to_atom(atom_name)}, isos), remaining}
  end

  defp parse_operand(<<char, _::binary>> = input, opts) when char in ?0..?9 or char == ?- do
    # Number
    parse_number(input, opts)
  end

  defp parse_operand(input, opts) do
    # Field name (bare identifier)
    {field_name, remaining} = parse_identifier(input)

    if field_name == "" do
      raise "Expected operand but found: #{input}"
    end

    # Check for iso chain after field
    {isos, remaining} = parse_iso_chain(remaining, opts)
    {wrap_with_isos({:field, field_name}, isos), remaining}
  end

  # Parse a chain of ::iso references
  defp parse_iso_chain("::" <> rest, opts) do
    {iso_name, remaining} = parse_identifier(rest)

    if iso_name == "" do
      raise "Expected iso name after ::"
    end

    iso = resolve_or_create_iso(String.to_atom(iso_name), opts)
    {more_isos, remaining} = parse_iso_chain(remaining, opts)
    {[iso | more_isos], remaining}
  end

  defp parse_iso_chain(input, _opts), do: {[], input}

  # Always create IsoRef - resolution happens at runtime
  defp resolve_or_create_iso(name, _opts) do
    IsoRef.new(name)
  end

  # Wrap operand with isos if any
  defp wrap_with_isos(operand, []), do: operand
  defp wrap_with_isos({:field, name}, isos), do: {:field_with_isos, name, isos}
  defp wrap_with_isos({:self}, isos), do: {:self_with_isos, isos}
  defp wrap_with_isos({:literal, value}, isos), do: {:literal_with_isos, value, isos}

  # Check that a keyword isn't part of a larger identifier
  defp check_identifier_boundary(rest, keyword) do
    case rest do
      "" ->
        :ok

      <<char, _::binary>> when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ ->
        raise "Expected operator after #{keyword} but found continuation"

      _ ->
        :ok
    end
  end

  # Parse a string literal until the closing quote
  defp parse_string(input, quote_char, opts) do
    case :binary.split(input, quote_char) do
      [content, rest] ->
        {isos, remaining} = parse_iso_chain(rest, opts)
        {wrap_with_isos({:literal, content}, isos), remaining}

      [_] ->
        raise "Unterminated string literal"
    end
  end

  # Parse a number (integer or float)
  defp parse_number(input, opts) do
    {num_str, rest} = consume_number(input)

    value =
      if String.contains?(num_str, ".") do
        case Float.parse(num_str) do
          {f, ""} -> f
          _ -> raise "Invalid number: #{num_str}"
        end
      else
        case Integer.parse(num_str) do
          {i, ""} -> i
          _ -> raise "Invalid number: #{num_str}"
        end
      end

    {isos, remaining} = parse_iso_chain(rest, opts)
    {wrap_with_isos({:literal, value}, isos), remaining}
  end

  defp consume_number(input) do
    consume_number(input, [])
  end

  defp consume_number("", acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp consume_number(<<char, rest::binary>>, acc)
       when char in ?0..?9 or char == ?- or char == ?. do
    consume_number(rest, [char | acc])
  end

  defp consume_number(rest, acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  # Parse an identifier
  defp parse_identifier(input) do
    consume_identifier(input, [])
  end

  defp consume_identifier("", acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp consume_identifier(<<char, rest::binary>>, acc)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ do
    consume_identifier(rest, [char | acc])
  end

  defp consume_identifier(rest, acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  # Parse a comparison operator
  # Note: Order matters - longer operators must come before shorter prefixes
  defp parse_cmp_operator("==" <> rest), do: {:eq, rest}
  defp parse_cmp_operator("!=" <> rest), do: {:neq, rest}
  defp parse_cmp_operator("~~" <> rest), do: {:str_eq, rest}
  defp parse_cmp_operator("!~" <> rest), do: {:str_neq, rest}
  defp parse_cmp_operator("<=" <> rest), do: {:lte, rest}
  defp parse_cmp_operator(">=" <> rest), do: {:gte, rest}
  defp parse_cmp_operator("<" <> rest), do: {:lt, rest}
  defp parse_cmp_operator(">" <> rest), do: {:gt, rest}

  defp parse_cmp_operator(input) do
    raise "Expected comparison operator (==, !=, <, <=, >, >=, ~~, !~) but found: #{String.slice(input, 0, 10)}"
  end

  # Resolve an operand value against an element
  defp resolve_operand({:self}, element), do: element

  defp resolve_operand({:self_with_isos, isos}, element) do
    apply_isos(element, isos)
  end

  defp resolve_operand({:field, name}, element) when is_map(element) do
    get_field(element, name)
  end

  defp resolve_operand({:field, _name}, _element), do: nil

  defp resolve_operand({:field_with_isos, name, isos}, element) when is_map(element) do
    value = get_field(element, name)
    apply_isos(value, isos)
  end

  defp resolve_operand({:field_with_isos, _name, _isos}, _element), do: nil

  defp resolve_operand({:literal, value}, _element), do: value

  defp resolve_operand({:literal_with_isos, value, isos}, _element) do
    apply_isos(value, isos)
  end

  # Get a field from a map (tries atom key first, then string key)
  defp get_field(map, name) when is_map(map) do
    atom_key = String.to_atom(name)

    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, name) -> Map.get(map, name)
      true -> nil
    end
  end

  # Apply a chain of isos to a value (forward direction for filtering)
  defp apply_isos(value, []), do: value

  defp apply_isos(value, [%Iso{forward: fwd} | rest]) do
    apply_isos(fwd.(value), rest)
  end

  defp apply_isos(_value, [%IsoRef{name: name} | _rest]) do
    raise ArgumentError,
          "Iso '#{name}' in filter expression is not resolved. " <>
            "Provide it via opts or ensure it's a builtin."
  end

  # Apply an operator to two values

  defp apply_operator(op, %schema{} = left, right) when op in [:eq, :neq, :lt, :lte, :gt, :gte] do
    if Code.ensure_loaded?(schema) and function_exported?(schema, :compare, 2) do
      case schema.compare(left, right) do
        :lt -> apply_operator(op, -1, 0)
        :eq -> apply_operator(op, 0, 0)
        :gt -> apply_operator(op, 1, 0)
      end
    else
      naively_apply_operator(op, left, right)
    end
  end

  defp apply_operator(op, left, right) do
    naively_apply_operator(op, left, right)
  end

  defp naively_apply_operator(:eq, left, right), do: left == right
  defp naively_apply_operator(:neq, left, right), do: left != right
  defp naively_apply_operator(:lt, left, right), do: left < right
  defp naively_apply_operator(:lte, left, right), do: left <= right
  defp naively_apply_operator(:gt, left, right), do: left > right
  defp naively_apply_operator(:gte, left, right), do: left >= right
  defp naively_apply_operator(:str_eq, left, right), do: to_string(left) == to_string(right)
  defp naively_apply_operator(:str_neq, left, right), do: to_string(left) != to_string(right)
end
