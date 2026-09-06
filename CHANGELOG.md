# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- Compatibility with eglot 1.24, which changed `eglot--apply-workspace-edit` from `(wedit origin)` to `(server wedit origin)`. All workspace edits now go through `eglot-jdtls--apply-edit`, which dispatches on eglot's signature at load time

## [0.2.0] - 2026-04-25

### Added

- Debugger support via [dape](https://github.com/svaante/dape) integration
  - Run and debug Java programs with auto-resolved classpath and workspace build
  - Hot code replace (`eglot-jdtls-debugger-hot-code-replace`) in running debug sessions
  - Run/Debug CodeLenses on `main` methods (requires `eglot-codelens`)
  - Configuration options: `eglot-jdtls-debugger-args`, `eglot-jdtls-debugger-vm-args`, `eglot-jdtls-debugger-env`
  - New file: `eglot-jdtls-debugger.el`

- Test runner support for JUnit 4/5/6 and TestNG via dape
  - Run/Debug CodeLenses on test methods (requires `eglot-codelens`)
  - Local TCP server for receiving test runner output
  - Test result output buffer (`*eglot-jdtls-test-result*`)
  - New file: `eglot-jdtls-tester.el`

### Changed

- `eglot-jdtls-server` class now tracks bundle state for conditional feature activation
- Updated dependencies: Eglot 1.23, jsonrpc 1.0.28, compat 30.1.0.1, added dape 0.26.0

## [0.1.0] - 2026-02-11

### Added

- Code generation: override methods, `toString()`, `hashCode()`/`equals()`, getters/setters, constructors, delegate methods
- Advanced refactoring: move files/members/types, extract methods/variables/constants/fields/interfaces, change signature, introduce parameters, convert anonymous to nested
- Navigation: jump to definitions in JAR files with automatic decompilation, find references and implementations
- Extended LSP capabilities: class file contents support, advanced import organization, infer selection for code actions
- URI handler for `jdt://` URIs with local caching
- Configuration options: `eglot-jdtls-cache-dir`, `eglot-jdtls-crm-separator`, `eglot-jdtls-config`
- Commands: `eglot-jdtls-organize-imports`, `eglot-jdtls-clear-cache`

### Changed

- Vertico sort function temporarily disabled during selection prompts to preserve JDTLS order
