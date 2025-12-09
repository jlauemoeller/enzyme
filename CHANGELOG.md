# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

0.3.0 - 2025-12-09

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
