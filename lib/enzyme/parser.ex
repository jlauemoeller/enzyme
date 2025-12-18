defmodule Enzyme.Parser do
  @moduledoc false

  # Recursive descent parser for lens path expressions.

  # ## Syntax

  # The path syntax is inspired by JMESPath and JSONPath, providing a concise way
  # to navigate nested data structures.

  # ### Quick Reference

  # | Syntax          | Description                      | Example              |
  # |-----------------|----------------------------------|----------------------|
  # | `key`           | String map key                   | `name`, `user`       |
  # | `.`             | Path separator                   | `user.name`          |
  # | `[n]`           | Numeric index                    | `[0]`, `[-1]`        |
  # | `[n,m,...]`     | Multiple indices (slice)         | `[0,2,4]`            |
  # | `[*]`           | All elements (wildcard)          | `items[*]`           |
  # | `[key]`         | String key in brackets           | `[name]`             |
  # | `[a,b,...]`     | Multiple string keys             | `[name,email]`       |
  # | `[:atom]`       | Atom key                         | `[:ok]`              |
  # | `[:a,:b,...]`   | Multiple atom keys               | `[:name,:age]`       |
  # | `[?expr]`       | Filter expression                | `[?active == true]`  |

  # ### Formal Grammar (EBNF)

  # ```ebnf
  # path        = component , { separator , component } ;
  # separator   = "." | ε ;                           (* dot optional before brackets *)
  # component   = bracket_expr | key ;

  # key         = { char - ("." | "[") } ;            (* string key, whitespace trimmed *)

  # bracket_expr = "[" , bracket_content , "]" ;
  # bracket_content = wildcard
  #                 | filter
  #                 | atom_list
  #                 | index_list
  #                 | key_list ;

  # wildcard    = "*" ;

  # filter      = "?" , expression ;
  # expression  = operand , operator , operand ;
  # operand     = "@" , [ "." , field ]               (* self reference *)
  #             | field                               (* field access *)
  #             | literal ;
  # field       = identifier ;
  # literal     = string | number | boolean ;
  # string      = "'" , { char } , "'"
  #             | '"' , { char } , '"' ;
  # number      = [ "-" ] , digit , { digit } ;
  # boolean     = "true" | "false" ;
  # operator    = "==" | "!=" | "~~" | "!~" ;

  # atom_list   = ":" , atom , { "," , ":" , atom } ;
  # atom        = identifier ;

  # index_list  = integer , { "," , integer } ;
  # integer     = [ "-" ] , digit , { digit } ;

  # key_list    = identifier , { "," , identifier } ;
  # identifier  = char , { char } ;                   (* excluding delimiters *)
  # ```

  # ### Semantics

  # - **Keys**: Plain identifiers select string keys from maps. Whitespace is trimmed.
  # - **Numeric indices**: Select elements from lists/tuples by position. Negative indices
  #   count from the end.
  # - **Wildcards `[*]`**: Select all elements from a list, tuple, or map values.
  # - **Slices `[n,m,...]`**: Select multiple elements by index or key.
  # - **Atom keys `[:key]`**: Select using atom keys instead of strings.
  # - **Filters `[?expr]`**: Keep only elements matching the predicate expression.

  # ### Filter Operators

  # | Operator | Description                                        |
  # |----------|----------------------------------------------------|
  # | `==`     | Equality (Erlang term comparison)                  |
  # | `!=`     | Inequality                                         |
  # | `~~`     | String equality (converts both sides to string)    |
  # | `!~`     | String inequality                                  |

  # ### Examples

  # ```
  # users[0].name           # First user's name
  # users[*].email          # All user emails
  # users[0,2].name         # First and third user names
  # data[:status]           # Atom key access
  # items[?price == 0]      # Items with zero price
  # users[?active == true][?role == 'admin'].name  # Stacked filters
  # ```

  alias Enzyme.All
  alias Enzyme.Expression
  alias Enzyme.ExpressionParser
  alias Enzyme.Filter
  alias Enzyme.IsoRef
  alias Enzyme.One
  alias Enzyme.Slice

  @doc """
  Parses a path expression into a lens or sequence of lenses.

  Returns a single lens for simple paths, or a `Enzyme.Sequence` for
  paths with multiple components.

  ## Examples

      iex> Enzyme.Parser.parse("foo.bar")
      %Enzyme.Sequence{lenses: [%Enzyme.One{index: "foo"}, %Enzyme.One{index: "bar"}]}

      iex> Enzyme.Parser.parse("[*]")
      %Enzyme.All{}

      iex> Enzyme.Parser.parse("[0,1]")
      %Enzyme.Slice{indices: [0, 1]}

      iex> Enzyme.Parser.parse("users[0]")
      %Enzyme.Sequence{lenses: [%Enzyme.One{index: "users"}, %Enzyme.One{index: 0}]}

  """
  def parse(path), do: parse(path, [])

  @doc """
  Parses a path expression.

  Iso references in the path (e.g., `"value::cents"`) are stored as `IsoRef`
  structs for resolution at runtime. The opts parameter is ignored by the
  parser - iso resolution always happens at select/transform time.

  ## Examples

      iex> %Enzyme.Sequence{lenses: [%Enzyme.One{}, %Enzyme.IsoRef{name: :cents}]} = Enzyme.Parser.parse("price::cents")
      iex> true
      true

  """
  def parse(path, opts) when is_binary(path) and is_list(opts) do
    {components, rest} = parse_path(path, opts)

    if rest != "" do
      raise "Unexpected characters at end of path: #{rest}"
    end

    case components do
      [] -> raise "Empty path expression"
      [single] -> single
      list -> %Enzyme.Sequence{lenses: list}
    end
  end

  # Parse a complete path: component (("." | "[") component)*
  defp parse_path(input, opts) do
    {component, rest} = parse_component(input, opts)
    parse_more_components(rest, add_component([], component), opts)
  end

  # Continue parsing after a dot separator (next key is string)
  defp parse_more_components("." <> rest, acc, opts) do
    {component, rest} = parse_component(rest, opts)
    parse_more_components(rest, add_component(acc, component), opts)
  end

  # Handle bracket directly after identifier (no dot needed)
  defp parse_more_components("[" <> _ = rest, acc, opts) do
    {component, rest} = parse_bracket_expression(rest, opts)
    parse_more_components(rest, add_component(acc, component), opts)
  end

  # Handle iso directly after identifier (no dot needed)
  defp parse_more_components("::" <> rest, acc, opts) do
    {iso, rest} = parse_iso_reference(rest, opts)
    parse_more_components(rest, add_component(acc, iso), opts)
  end

  # Handle : as atom path separator (next key is atom)
  # Must come after :: and :{ patterns
  defp parse_more_components(":" <> <<char, _::binary>> = rest, acc, opts)
       when char in ?a..?z or char in ?A..?Z or char == ?_ do
    {component, rest} = parse_atom_key(rest, opts)
    parse_more_components(rest, add_component(acc, component), opts)
  end

  defp parse_more_components(rest, acc, _opts) do
    {Enum.reverse(acc), rest}
  end

  # Add component(s) to accumulator, handling lists from key::iso parsing
  defp add_component(acc, components) when is_list(components) do
    Enum.reverse(components) ++ acc
  end

  defp add_component(acc, component) do
    [component | acc]
  end

  # Parse a single component: "[...]" | "::iso" | ":atom" | key
  defp parse_component("[" <> _ = input, opts) do
    parse_bracket_expression(input, opts)
  end

  defp parse_component("::" <> rest, opts) do
    parse_iso_reference(rest, opts)
  end

  # Leading : for atom key (not :: or :{)
  defp parse_component(":" <> <<char, _::binary>> = input, opts)
       when char in ?a..?z or char in ?A..?Z or char == ?_ do
    parse_atom_key(input, opts)
  end

  defp parse_component(input, opts) do
    parse_key(input, opts)
  end

  # Parse bracket expression: consume "[", parse content, expect "]"
  defp parse_bracket_expression("[" <> rest, opts) do
    parse_bracket_content(rest, opts)
  end

  # Parse content inside brackets
  # [*] -> All
  # [?...] -> Filter
  # [:...] -> Atom(s)
  # [digit...] -> Numeric index(es)
  # [identifier...] -> String key(s)
  defp parse_bracket_content(input, opts) do
    # Trim leading whitespace and dispatch based on first char
    trimmed = String.trim_leading(input)
    parse_bracket_content_trimmed(trimmed, input, opts)
  end

  defp parse_bracket_content_trimmed("*]" <> rest, _original, _opts) do
    {%All{}, rest}
  end

  defp parse_bracket_content_trimmed("?" <> rest, _original, opts) do
    parse_filter_expression(rest, opts)
  end

  defp parse_bracket_content_trimmed(":" <> rest, _original, _opts) do
    parse_atom_list(rest)
  end

  defp parse_bracket_content_trimmed(<<char, _::binary>> = _trimmed, original, _opts)
       when char in ?0..?9 or char == ?- do
    parse_index_list(original)
  end

  defp parse_bracket_content_trimmed("]" <> _, _original, _opts) do
    raise "Empty brackets not allowed. Use [*] for all elements."
  end

  defp parse_bracket_content_trimmed(_trimmed, original, _opts) do
    parse_string_key_list(original)
  end

  # Parse filter expression: [?expr] -> Filter selector
  # The expression parsing is handled by the expression parser module
  defp parse_filter_expression(input, opts) do
    {expr_str, rest} = consume_until(input, "]")

    case rest do
      "]" <> remaining ->
        trimmed = String.trim(expr_str)

        if trimmed == "" do
          raise "Expected filter expression after ? in bracket"
        end

        # Parse the expression (may contain isos and/or function calls)
        expression = ExpressionParser.parse(trimmed, opts)
        filter = build_filter(expression)

        {filter, remaining}

      _ ->
        raise "Expected ] after filter expression"
    end
  end

  defp build_filter(%Expression{} = expression) do
    # Check if expression contains any isos or function calls
    # If so, store expression for runtime resolution
    # Otherwise, compile to predicate immediately
    if expression_has_isos?(expression) or expression_has_function_calls?(expression) do
      %Filter{predicate: nil, expression: expression}
    else
      # Compile immediately - predicate_fn expects (element, opts)
      # Wrap to pass empty opts for simple filters
      predicate_fn = ExpressionParser.compile(expression)
      predicate = fn element -> predicate_fn.(element, []) end
      %Filter{predicate: predicate, expression: expression}
    end
  end

  # Check if expression contains any isos
  defp expression_has_isos?(expression) do
    ExpressionParser.has_isos?(expression)
  end

  # Check if expression contains any function calls
  defp expression_has_function_calls?(expression) do
    ExpressionParser.has_function_calls?(expression)
  end

  # Parse comma-separated list of atoms: [:a] or [:a,:b]
  defp parse_atom_list(input) do
    {atoms, rest} = parse_atoms(input, [])

    case rest do
      "]" <> remaining ->
        selector =
          case atoms do
            [atom] -> %One{index: atom}
            atoms -> %Slice{indices: atoms}
          end

        {selector, remaining}

      _ ->
        raise "Expected ] at end of atom list"
    end
  end

  defp parse_atoms(input, acc) do
    parse_comma_separated(input, acc, &parse_atom!(String.trim(&1)), fn remaining, new_acc ->
      case String.trim_leading(remaining) do
        ":" <> trimmed -> parse_atoms(trimmed, new_acc)
        _ -> raise "Expected : after comma in atom list"
      end
    end)
  end

  defp parse_atom!(str) do
    case str do
      "" -> raise "Expected atom name after : in bracket expression"
      name -> String.to_atom(name)
    end
  end

  # Parse comma-separated list of numeric indices
  defp parse_index_list(input) do
    {indices, rest} = parse_indices(input, [])

    case rest do
      "]" <> remaining ->
        selector =
          case indices do
            [index] -> %One{index: index}
            indices -> %Slice{indices: indices}
          end

        {selector, remaining}

      _ ->
        raise "Expected ] at end of index list"
    end
  end

  defp parse_indices(input, acc) do
    parse_comma_separated(input, acc, &parse_integer!(String.trim(&1)), &parse_indices/2)
  end

  # Generic helper for parsing comma-separated lists
  defp parse_comma_separated(input, acc, item_parser, continue_fn) do
    {item_str, rest} = consume_until(input, ",]")
    item = item_parser.(item_str)

    case rest do
      "," <> remaining -> continue_fn.(remaining, [item | acc])
      _ -> {Enum.reverse([item | acc]), rest}
    end
  end

  defp parse_integer!(str) do
    case Integer.parse(str) do
      {n, ""} ->
        n

      {_, _} ->
        raise "Expected integer but found #{str} in index expression"

      :error ->
        raise "Expected integer but found #{str} in index expression"
    end
  end

  # Parse comma-separated list of string keys: [name] or [a,b,c]
  defp parse_string_key_list(input) do
    {names, rest} = parse_names(input, [])

    case rest do
      "]" <> remaining ->
        selector =
          case names do
            [name] -> %One{index: name}
            names -> %Slice{indices: names}
          end

        {selector, remaining}

      _ ->
        raise "Expected ] at end of key list"
    end
  end

  defp parse_names(input, acc) do
    parse_comma_separated(input, acc, &parse_name!/1, &parse_names/2)
  end

  defp parse_name!(str) do
    case String.trim(str) do
      "" -> raise "Expected name but found empty string in bracket expression"
      trimmed -> trimmed
    end
  end

  # Parse a plain key (until ".", "[", ":{", "::", ":", or end of string)
  # If followed by ::, also parses the iso reference
  defp parse_key(input, opts) do
    {key_str, rest} = consume_key(input, [])
    key = String.trim(key_str)

    case rest do
      "::" <> iso_rest ->
        # Key followed by iso reference
        {iso, remaining} = parse_iso_reference(iso_rest, opts)

        if key == "" do
          # Just ::iso_name at start
          {iso, remaining}
        else
          {[%One{index: key}, iso], remaining}
        end

      _ ->
        {%One{index: key}, rest}
    end
  end

  # Parse an atom key: :name (consumes the leading : and returns One with atom index)
  # Handles optional :: iso suffix
  defp parse_atom_key(":" <> rest, opts) do
    {atom_name, remaining} = consume_atom_name(rest, [])

    if atom_name == "" do
      raise "Expected atom name after : in path"
    end

    atom = String.to_atom(atom_name)

    case remaining do
      "::" <> iso_rest ->
        # Atom key followed by iso reference
        {iso, final_rest} = parse_iso_reference(iso_rest, opts)
        {[%One{index: atom}, iso], final_rest}

      _ ->
        {%One{index: atom}, remaining}
    end
  end

  # Consume atom name characters until we hit a delimiter
  defp consume_atom_name("", acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}
  end

  defp consume_atom_name("." <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_atom_name("[" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_atom_name(":{" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_atom_name("::" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  # Stop at : followed by identifier (atom path separator)
  defp consume_atom_name(":" <> <<char, _::binary>> = rest, acc)
       when char in ?a..?z or char in ?A..?Z or char == ?_ do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_atom_name(<<char::utf8, rest::binary>>, acc) do
    consume_atom_name(rest, [char | acc])
  end

  # Consume key characters until we hit a delimiter or special sequence
  defp consume_key("", acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}
  end

  defp consume_key(".[" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_key("." <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_key("[" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_key(":{" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_key("::" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  # Stop at : followed by identifier (atom path separator)
  defp consume_key(":" <> <<char, _::binary>> = rest, acc)
       when char in ?a..?z or char in ?A..?Z or char == ?_ do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_key(<<char::utf8, rest::binary>>, acc) do
    consume_key(rest, [char | acc])
  end

  # Parse an iso reference: consumes iso name and returns IsoRef
  # Resolution happens at runtime, not parse time
  defp parse_iso_reference(input, _opts) do
    {name_str, rest} = consume_iso_name(input, [])
    name = String.trim(name_str)

    if name == "" do
      raise "Expected iso name after :: in path"
    end

    {IsoRef.new(String.to_atom(name)), rest}
  end

  # Consume iso name until delimiter
  defp consume_iso_name("", acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}
  end

  defp consume_iso_name("::" <> _ = rest, acc) do
    # Chained iso - stop here
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_iso_name("." <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_iso_name("[" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_iso_name(":{" <> _ = rest, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  # Stop at : followed by identifier (atom path separator)
  defp consume_iso_name(":" <> <<char, _::binary>> = rest, acc)
       when char in ?a..?z or char in ?A..?Z or char == ?_ do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp consume_iso_name(<<char::utf8, rest::binary>>, acc) do
    consume_iso_name(rest, [char | acc])
  end

  # Consume characters until we hit one of the delimiter characters
  defp consume_until(input, delimiters) do
    consume_until(input, delimiters, [])
  end

  defp consume_until("", _delimiters, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}
  end

  defp consume_until(<<char::utf8, rest::binary>> = input, delimiters, acc) do
    char_str = <<char::utf8>>

    if String.contains?(delimiters, char_str) do
      {acc |> Enum.reverse() |> IO.iodata_to_binary(), input}
    else
      consume_until(rest, delimiters, [char | acc])
    end
  end
end
