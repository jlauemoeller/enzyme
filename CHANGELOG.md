# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

0.4.0 - 2025-12-11

### Breaking

- BREAKING: Removed Prism lens - The Prism lens for matching tagged tuples has been removed. Use function calls in filter expressions instead (e.g., `[?is_ok(@)]` instead of `:{:ok, v}`). Function calls provide more flexibility and can match any pattern, not just tagged tuples.
- BREAKING: The [*] selector (All lens) now flattens nested lists in its output. For example, selecting "matrix[\*][*].v" from a structure with a matrix of values will return a flat list of all "v" values instead of a list of lists. This change improves usability and consistency with common expectations for "all" selectors.
- BREAKING: Filter expressions now require explicit `@.` prefixes for field access on the current item. For example, use `[?@.active == true]` instead of `[?active == true]`. This change enhances clarity and avoids ambiguity in filter expressions.

### Changed

- Updated documentation and examples to reflect changes in filter expression syntax and [*] selector behavior.
- Updated tracing output format for improved clarity and consistency.
- Refactored tracing implementation to use a dedicated `Enzyme.Tracing` module for better organization and maintainability.
- Enhanced tracing functionality to support custom indentation levels and output devices.

### Added

- Support for chained filter expressions, allowing more complex filtering logic in selections.
- New function calls in filter expressions for common operations (e.g., `is_ok/1`, `is_error/1`).

  0.3.1 - 2025-12-10

### Added

- Basic tracing support

- 0.3.0 - 2025-12-09

### Changed

- Unified internal API: all lens operations now consistently receive and return wrapped values (`%Single{}`, `%Many{}`,
  `%None{}`), improving consistency and error handling
- Entry points (`select/3`, `transform/4`) now wrap input before passing to protocol implementations
- Removed `select_wrapped/2` and `transform_wrapped/3` helper functions from `Wraps` module; each lens now handles wrapping
  directly
- Made `single/1` and `many/1` idempotent (return unchanged if already wrapped)
- Improved Prism documentation
- Added more comprehensive tests for wrapping behavior across all lens modules

### Added

- `unwrap!/1` function that raises `ArgumentError` on non-wrapped values
- Explicit `ArgumentError` when lens operations receive invalid (unwrapped) input

### Fixed

- Various code cleanups and simplifications across lens modules
  0.2.1 - 2025-12-08

- FIX: `One` fails when transforming lists of records.

  0.2.0 - 2025-12-07

- Switched to using `%Enzyme.Single{}` and `%Enzyme.Many{}` structs for wrapped values instead of tuples to avoid potential conflicts with input data.
- Added explicit handling of "no value" with `%Enzyme.None{}` struct.
- Introduced `Enzyme.Types` module to define common types used across the library.
- Improved tests and documentation for better clarity.
- Simplified and updated type specs
- Bugfixes

  0.1.0 - 2025-12-07

- Initial release
