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
  # | `:{:tag, ...}`  | Prism (extract all after tag)    | `:{:ok, ...}`        |
  # | `:{:tag, a, b}` | Prism (extract named positions)  | `:{:ok, v}`          |
  # | `:{:tag, _, b}` | Prism (ignore positions with _)  | `:{:rect, _, h}`     |
  # | `:{:tag, _, _}` | Prism (filter only)              | `:{:ok, _}`          |

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

  # prism       = ":{" , ":" , atom , prism_tail , "}" ;
  # prism_tail  = ε                                      (* tag only, same as ... *)
  #             | "," , "..."                            (* rest pattern *)
  #             | "," , prism_elem , { "," , prism_elem } ;
  # prism_elem  = "_" | identifier ;                     (* _ ignores, name extracts *)

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

  # ### Prism Examples

  # Prisms match tagged tuples (sum types) and extract values:

  # ```
  # results[*]:{:ok, v}              # Extract values from all {:ok, v} tuples
  # results[*]:{:error, r}           # Extract reasons from {:error, r} tuples
  # data:{:ok, v}.user.name          # Extract from {:ok, _}, then traverse
  # shapes[*]:{:circle, r}           # Extract radius from circle tuples
  # shapes[*]:{:rectangle, w, h}     # Extract {w, h} from rectangles
  # shapes[*]:{:rectangle, _, h}     # Extract only height (ignore width)
  # shapes[*]:{:point, ...}          # Extract all elements after :point tag
  # results[*]:{:ok, _}              # Filter to only :ok tuples (no extraction)
  # ```

  alias Enzyme.All
  alias Enzyme.Filter
  alias Enzyme.IsoRef
  alias Enzyme.One
  alias Enzyme.Prism
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

  # Handle prism directly after identifier (no dot needed)
  defp parse_more_components(":{" <> _ = rest, acc, opts) do
    {component, rest} = parse_prism_expression(rest)
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

  # Parse a single component: "[...]" | ":{...}" | "::iso" | ":atom" | key
  defp parse_component("[" <> _ = input, opts) do
    parse_bracket_expression(input, opts)
  end

  defp parse_component(":{" <> _ = input, _opts) do
    parse_prism_expression(input)
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

        # Parse the expression (may contain isos)
        expression = Enzyme.ExpressionParser.parse(trimmed, opts)

        # Check if expression contains any isos (resolved or not)
        # If so, store expression for potential runtime override
        # Otherwise, compile to predicate immediately
        filter =
          if expression_has_isos?(expression) do
            %Filter{predicate: nil, expression: expression}
          else
            predicate = Enzyme.ExpressionParser.compile(expression)
            %Filter{predicate: predicate, expression: nil}
          end

        {filter, remaining}

      _ ->
        raise "Expected ] after filter expression"
    end
  end

  # Check if expression contains any isos
  defp expression_has_isos?(expression) do
    Enzyme.ExpressionParser.has_isos?(expression)
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

  # Parse prism expression: :{:tag, pattern...}
  # Examples:
  #   :{:ok, v}           -> Prism matching {:ok, _}, extracting v
  #   :{:rectangle, w, h} -> Prism matching {:rectangle, _, _}, extracting {w, h}
  #   :{:rectangle, _, h} -> Prism matching {:rectangle, _, _}, extracting h only
  #   :{:ok, ...}         -> Prism matching {:ok, ...}, extracting all after tag
  #   :{:ok, _}           -> Prism matching {:ok, _}, filter only (returns whole tuple)
  defp parse_prism_expression(":{" <> rest) do
    # Expect :tag first
    case rest do
      ":" <> tag_rest ->
        {tag_name, after_tag} = consume_until(tag_rest, ",}")

        tag =
          case String.trim(tag_name) do
            "" -> raise "Expected atom name after : in prism expression"
            name -> String.to_atom(name)
          end

        # Check what comes after the tag
        case String.trim_leading(after_tag) do
          "}" <> remaining ->
            # Just a tag, no pattern - treat as rest pattern
            prism = %Prism{tag: tag, pattern: nil, rest: true}
            parse_prism_retag(prism, remaining)

          "," <> pattern_rest ->
            parse_prism_pattern(tag, String.trim_leading(pattern_rest))

          other ->
            raise "Expected , or } after tag in prism expression, got: #{inspect(other)}"
        end

      _ ->
        raise "Expected :atom after :{ in prism expression"
    end
  end

  # Parse the pattern part of a prism: name | _ | ...
  defp parse_prism_pattern(tag, "..." <> rest) do
    # Rest pattern - consume closing }
    case String.trim_leading(rest) do
      "}" <> remaining ->
        prism = %Prism{tag: tag, pattern: nil, rest: true}
        parse_prism_retag(prism, remaining)

      _ ->
        raise "Expected } after ... in prism expression"
    end
  end

  defp parse_prism_pattern(tag, input) do
    {elements, rest} = parse_prism_elements(input, [])

    case rest do
      "}" <> remaining ->
        pattern =
          Enum.map(elements, fn
            "_" -> nil
            name -> String.to_atom(name)
          end)

        prism = %Prism{tag: tag, pattern: pattern, rest: false}
        parse_prism_retag(prism, remaining)

      _ ->
        raise "Expected } at end of prism expression"
    end
  end

  defp parse_prism_elements(input, acc) do
    {element, rest} = consume_until(input, ",}")
    trimmed = String.trim(element)

    if trimmed == "" do
      raise "Expected element name or _ in prism pattern"
    end

    case rest do
      "," <> more ->
        parse_prism_elements(String.trim_leading(more), [trimmed | acc])

      _ ->
        {Enum.reverse([trimmed | acc]), rest}
    end
  end

  # Parse optional prism retagging: -> :tag or -> {:tag, assembly}
  defp parse_prism_retag(prism, input) do
    case String.trim_leading(input) do
      "->" <> rest ->
        parse_prism_output(prism, rest)

      other ->
        # No retagging - return prism as-is
        {prism, other}
    end
  end

  # Parse prism output: :tag (shorthand) or {:tag, assembly}
  # First trim leading whitespace, then check for : or {
  defp parse_prism_output(prism, input) do
    case String.trim_leading(input) do
      ":" <> rest ->
        # Check if it's shorthand (:atom) or full form ({:atom, ...})
        case rest do
          "{" <> full_rest ->
            # Full form: {:tag, assembly}
            parse_prism_output_assembly(prism, "{:" <> full_rest)

          _shorthand_rest ->
            # Shorthand: just :tag
            parse_prism_output_shorthand(prism, rest)
        end

      other ->
        raise "Expected : after -> in prism retagging, got: #{inspect(String.slice(other, 0, 10))}"
    end
  end

  # Parse shorthand retagging: -> :tag
  defp parse_prism_output_shorthand(prism, input) do
    {tag_name, remaining} = consume_identifier(input, [])

    if tag_name == "" do
      raise "Expected atom name after : in prism retagging"
    end

    output_tag = String.to_atom(tag_name)
    {%{prism | output_tag: output_tag, output_pattern: nil}, remaining}
  end

  # Parse explicit assembly: -> :{:tag, x, z}
  defp parse_prism_output_assembly(prism, "{:" <> rest) do
    # After "{:" we should have the tag name
    {tag_name, after_tag} = consume_until(rest, ",}")

    output_tag =
      case String.trim(tag_name) do
        "" -> raise "Expected atom name after :{ in prism output"
        # Strip leading : if present
        ":" <> name -> String.to_atom(name)
        name -> String.to_atom(name)
      end

    case String.trim_leading(after_tag) do
      "}" <> remaining ->
        # Empty assembly - treat as rest pattern
        {%{prism | output_tag: output_tag, output_pattern: :rest}, remaining}

      "," <> pattern_rest ->
        trimmed = String.trim_leading(pattern_rest)

        # Check for rest pattern
        {output_pattern, remaining} =
          if String.starts_with?(trimmed, "...") do
            parse_prism_rest(trimmed)
          else
            parse_prism_assembly_pattern(prism, trimmed)
          end

        {%{prism | output_tag: output_tag, output_pattern: output_pattern}, remaining}

      _ ->
        raise "Expected , or } after tag in prism output assembly"
    end
  end

  defp parse_prism_rest(trimmed) do
    case String.trim_leading(String.slice(trimmed, 3..-1//1)) do
      "}" <> remaining ->
        {:rest, remaining}

      _ ->
        raise "Expected } after ... in prism output assembly"
    end
  end

  def parse_prism_assembly_pattern(prism, trimmed) do
    # Parse explicit assembly pattern
    {elements, rest} = parse_prism_output_elements(trimmed, [])

    case rest do
      "}" <> remaining ->
        # Validate that all names exist in input pattern
        output_pattern = Enum.map(elements, &String.to_atom/1)
        validate_output_pattern(prism, output_pattern)
        {output_pattern, remaining}

      _ ->
        raise "Expected } at end of prism output assembly"
    end
  end

  # Parse output assembly elements
  defp parse_prism_output_elements(input, acc) do
    {element, rest} = consume_until(input, ",}")
    trimmed = String.trim(element)

    if trimmed == "" do
      raise "Expected element name in prism output assembly"
    end

    case rest do
      "," <> more ->
        parse_prism_output_elements(String.trim_leading(more), [trimmed | acc])

      _ ->
        {Enum.reverse([trimmed | acc]), rest}
    end
  end

  # Validate that output pattern names exist in input pattern
  defp validate_output_pattern(%Prism{pattern: pattern}, output_pattern) when is_list(pattern) do
    # Get list of extracted names from input pattern
    extracted_names =
      pattern
      |> Enum.filter(fn spec -> spec != nil end)

    # Check that all output names are in extracted names
    Enum.each(output_pattern, fn name ->
      unless name in extracted_names do
        raise "Output pattern references '#{name}' which was not extracted in input pattern"
      end
    end)
  end

  defp validate_output_pattern(%Prism{rest: true}, _output_pattern) do
    # For rest patterns, we can't validate names since we don't know what will be extracted
    # This is okay - runtime will handle it
    :ok
  end

  # Helper to consume an identifier (for shorthand tag parsing)
  defp consume_identifier("", acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp consume_identifier(<<char, rest::binary>>, acc)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ do
    consume_identifier(rest, [char | acc])
  end

  defp consume_identifier(rest, acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
end
