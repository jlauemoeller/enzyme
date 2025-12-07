Core Optics Missing

1. Prisms - For working with sum types like {:ok, value} / {:error, reason}. Common in functional lens libraries for safe access to
   variant types.
2. Isos (Isomorphisms) - Bidirectional transformations (e.g., between a JSON string and a map, or encoding/decoding).
3. Affine/Optional - Explicit handling when a focus might not exist (returns {:ok, value} or :error rather than nil or raising).

Safe Access & Defaults

4. select_or_default/3 - Get with a fallback value when the path doesn't exist.
5. has_path?/2 - Check if a path exists before accessing.
6. Error handling modes - Currently unclear what happens on missing paths. Libraries often provide options: raise, return nil, or
   return {:ok, _}/{:error, _}.

Structural Modifications

7. delete/2 - Remove the element at the focus (different from filtering - this removes map keys or list elements entirely).
8. append/3 / prepend/3 - Add elements to a list at the focus.
9. upsert/3 or put_in_path/3 - Create intermediate structures if they don't exist during transform.

Filter Expression Enhancements

10. Comparison operators - Only ==, !=, ~~, !~ exist. Missing: >, <, >=, <=.
11. Logical operators - No and, or, not for combining predicates (e.g., [?age > 18 and status == 'active']).
12. In/membership operator - [?status in ['active', 'pending']].
13. Regex matching - [?name =~ /pattern/].

Advanced Selectors

14. Range slicing - [0..5] or [1..-1] Elixir-style ranges.
15. First/Last with predicate - first or last that matches a condition, not just index [0] or [-1].
16. Key pattern matching - Select map keys matching a regex or glob pattern.
17. Recursive descent - JSONPath's .. operator to search at any depth.

Fold/Aggregation Operations

18. fold/4 or reduce/4 - Reduce over focused elements (sum, count, etc.).
19. count/2 - Count matching elements.
20. any?/2 / all?/2 - Predicate checks across focused elements.

Transform Enhancements

21. transform_with_index/3 - Transformation function receives (value, index).
22. Map key transformation - Transform keys, not just values.

Other

23. Struct-aware accessors - Explicit struct field access with compile-time validation.
24. Enzyme caching - Memoize parsed path strings for performance with repeated use.
25. Inspect protocol implementation - For readable lens representation in IEx.
