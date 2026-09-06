# eglot-jdtls

[![license](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.txt)

## Overview

**eglot-jdtls** integrates the [Eclipse JDT Language Server](https://github.com/eclipse-jdtls/eclipse.jdt.ls) (jdtls) with [Eglot](https://github.com/joaotavora/eglot), providing advanced Java development features in Emacs including code generation, refactoring, debugging, testing, and navigation.

## Screenshots

<img width=70% height=70% alt="Image" src="https://github.com/user-attachments/assets/04b27f12-f927-4bbb-9023-80b87f41c065" />

### Key Components

| File                      | Description                                                                                        |
|---------------------------|----------------------------------------------------------------------------------------------------|
| `eglot-jdtls.el`          | Core integration: server class, code actions, refactoring, navigation, URI handler                 |
| `eglot-jdtls-debugger.el` | Debugger support via [dape](https://github.com/svaante/dape): run/debug sessions, hot code replace |
| `eglot-jdtls-tester.el`   | Test runner support: JUnit 4/5/6, TestNG, test result output                                       |

## Architecture

eglot-jdtls extends Eglot's LSP client through several mechanisms:

1. **Server Class** (`eglot-jdtls-server`): A subclass of `eglot-lsp-server` that provides JDTLS-specific initialization options, extended client capabilities, and bundle management for conditional feature activation (debugging/testing).

2. **Eglot Method Overrides**: The package overrides key Eglot methods:
   - `eglot-handle-request` — handles JDTLS-specific requests (class file contents, organize imports, code actions)
   - `eglot-execute :around` — intercepts LSP commands to provide interactive Emacs UI for JDTLS code actions and refactorings
   - `eglot-codelens-provide-codelens :around` — adds Run/Debug CodeLenses on main methods and test methods

3. **URI Handler** (`eglot-jdtls-uri-handler`): Handles `jdt://` URIs for navigating into JAR files and JDK sources, with automatic decompilation and local caching.

4. **Feature Modules**: Debugging and testing are loaded conditionally based on whether the required bundles are configured in `eglot-jdtls-config`.

## Requirements

- Emacs 30.1 or later
- [Eglot](https://github.com/joaotavora/eglot) 1.23 or later
- [Eclipse JDT Language Server](https://github.com/eclipse-jdtls/eclipse.jdt.ls) (jdtls)
- [dape](https://github.com/svaante/dape) 0.27.1 or later (for debugging and testing)
- [eglot-codelens](https://github.com/zsxh/eglot-codelens) (optional, for Run/Debug CodeLenses)
- [dape-toolbar](https://github.com/zsxh/dape-toolbar) (optional, dape toolbar)

## Getting Started

### Installation

#### Using package-vc

```emacs-lisp
(unless (package-installed-p 'eglot-jdtls)
  (package-vc-install
   '(eglot-jdtls :url "https://github.com/zsxh/eglot-jdtls")))
```

#### Manual Installation

Download the `.el` files and add to your load path:

```emacs-lisp
(add-to-list 'load-path "/path/to/eglot-jdtls")
(require 'eglot-jdtls)
```

### Basic Configuration

The simplest setup uses the default `jdtls` command:

```emacs-lisp
(require 'eglot-jdtls)

(push '((java-mode java-ts-mode) . (eglot-jdtls-server . eglot-jdtls-cmd))
      eglot-server-programs)
```

Then enable `eglot` in Java buffers with `M-x eglot`.

### Advanced Configuration

For custom JDTLS initialization (Lombok, multiple JDKs, debugging, testing):

```emacs-lisp
(setq eglot-jdtls-config
      '(:cmd ("jdtls"
              "--jvm-arg=-javaagent:/path/to/lombok.jar"
              "--jvm-arg=-XX:+UseStringDeduplication")
        :init-options (:bundles ["/path/to/debug-bundle.jar"
                                 "/path/to/test-bundle.jar"])))

;; Multiple JDK runtimes via JavaConfigurationSettings
(setq-default eglot-workspace-configuration
              '(:java
                (:configuration
                 (:runtimes [(:name "JavaSE-1.8"
                              :path "/path/to/JDK_8_HOME")
                             (:name "JavaSE-17"
                              :path "/path/to/JDK_17_HOME")
                             (:name "JavaSE-21"
                              :path "/path/to/JDK_21_HOME"
                              :default t)]))))
```

## Features

### Code Generation

Available through `M-x eglot-code-actions`:

| Feature                        | Description                                           |
|--------------------------------|-------------------------------------------------------|
| Override Methods               | Select methods from superclass/interfaces to override |
| Generate toString()            | Select fields to include in the generated method      |
| Generate hashCode() & equals() | Select fields for comparison                          |
| Generate Getters & Setters     | Select fields to generate accessors for               |
| Generate Constructors          | Select constructors and fields to initialize          |
| Generate Delegate Methods      | Create wrapper methods delegating to field methods    |

### Refactoring

Available via code actions or specific commands:

| Feature                                | Description                                                                                                             |
|----------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Move File                              | Move `.java` files between packages                                                                                     |
| Move Instance Method                   | Move method to a field's type or parameter's type                                                                       |
| Move Static Member                     | Move static fields/methods/types to other classes                                                                       |
| Move Type                              | Move nested types to new files or other classes                                                                         |
| Extract Interface                      | Create interface from selected class members                                                                            |
| Change Signature                       | Interactive buffer for modifying method parameters, return types, exceptions, and access modifiers (`C-c C-c` to apply) |
| Extract Method/Variable/Constant/Field | Infer selection and extract                                                                                             |
| Introduce Parameter                    | Convert local variable to method parameter                                                                              |
| Convert Anonymous to Nested            | Convert anonymous class to named nested class                                                                           |

### Debugging

Requires [dape](https://github.com/svaante/dape) and the [java-debug](https://github.com/Microsoft/java-debug) bundle.

> **Recommand**: Download debug bundles via [mason](https://github.com/mason-org/mason.el).

1. Add the debug bundle to `eglot-jdtls-config`:

```emacs-lisp
(setq eglot-jdtls-config
      '(:init-options (:bundles ["/path/to/com.microsoft.java.debug.plugin-*.jar"])))
```

2. Install [eglot-codelens](https://github.com/zsxh/eglot-codelens) for Run/Debug CodeLenses.

**Features:**

- **Run/Debug CodeLenses**: Click the Run or Debug lens above `main` methods to launch programs via dape
- **Hot Code Replace**: During a debug session, use `eglot-jdtls-debugger-hot-code-replace` (or `R` in [dape-toolbar](https://github.com/zsxh/dape-toolbar)) to reload changed classes without restarting

### Testing

Requires [dape](https://github.com/svaante/dape) and the [java-test](https://github.com/microsoft/vscode-java-test) bundle.

> **Recommand**: Download test bundles via [mason](https://github.com/mason-org/mason.el).

1. Add the test bundle to `eglot-jdtls-config`:

```emacs-lisp
(setq eglot-jdtls-config
      '(:init-options (:bundles ["/path/to/com.microsoft.java.test.plugin-*.jar"])))
```

2. Install [eglot-codelens](https://github.com/zsxh/eglot-codelens) for Run/Debug CodeLenses on test methods.

**Supported Frameworks:**

- JUnit 4
- JUnit 5 (Jupiter)
- JUnit 6
- TestNG

**Features:**

- **Run/Debug Test CodeLenses**: Click the Run or Debug lens above test methods
- **Test result output**: Results displayed in the `*eglot-jdtls-test-result*` buffer

### Navigation

- **Jump to definitions in JAR files**: Navigate into JAR contents with automatic decompilation
- **Find references and implementations**: Standard LSP navigation enhanced for Java projects

## Configuration Reference

### Core Options

| Variable                    | Description                                       | Default                  |
|-----------------------------|---------------------------------------------------|--------------------------|
| `eglot-jdtls-cache-dir`     | Directory for caching JAR source files            | `~/.emacs.d/eglot-jdtls` |
| `eglot-jdtls-crm-separator` | Separator for multiple selections in code actions | `"[ \t]*;[ \t]*"`        |
| `eglot-jdtls-config`        | JDTLS server configuration plist                  | `nil`                    |

### Run/Debug Options

| Variable                       | Description                                 | Default |
|--------------------------------|---------------------------------------------|---------|
| `eglot-jdtls-debugger-args`    | Arguments passed to the main class          | `nil`   |
| `eglot-jdtls-debugger-vm-args` | JVM arguments when running/debugging        | `nil`   |
| `eglot-jdtls-debugger-env`     | Environment variables for running/debugging | `nil`   |

### `eglot-jdtls-config` plist

The `eglot-jdtls-config` plist supports:

- `:cmd` — JDTLS command (list of strings or a function returning a list)
- `:init-options` — Initialization options:
  - `:extendedClientCapabilities` — JDTLS extended capabilities
  - `:bundles` — List of paths to JDTLS extension bundles (debug, test, etc.)

## Commands Reference

### Interactive Commands

| Command                                 | Description                                       |
|-----------------------------------------|---------------------------------------------------|
| `eglot-jdtls-organize-imports`          | Organize and optimize imports in current buffer   |
| `eglot-jdtls-clear-cache`               | Clear the cached decompiled Java source files     |
| `eglot-jdtls-debugger-hot-code-replace` | Reload changed classes in a running debug session |

### Format Options

Refactoring operations respect `tab-width` and `indent-tabs-mode`. Set these before executing refactoring commands for custom formatting.

## Troubleshooting

### JDTLS Fails to Start

- Ensure `jdtls` is in your PATH, or provide the full path:

```emacs-lisp
(setq eglot-jdtls-config '(:cmd ("/full/path/to/jdtls")))
```

### Class File Navigation Issues

Clear the decompilation cache:

```emacs-lisp
M-x eglot-jdtls-clear-cache
```

### Debugging JDTLS Communication

Inspect LSP events:

```emacs-lisp
M-x eglot-events-buffer
```

### Bundles Not Detected

Ensure the bundle JAR paths in `eglot-jdtls-config` are correct and the files exist. The debugger and tester features are only activated when their respective bundles are detected in the server's initialization options.

## Development

### Project Structure

```
eglot-jdtls/
├── eglot-jdtls.el           # Core integration
├── eglot-jdtls-debugger.el  # Debugger support
├── eglot-jdtls-tester.el    # Test runner support
├── tests/
│   └── eglot-jdtls-test.el  # Test suite
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## TODOs

- [ ] **Analyze test results** - Visualize test case pass/fail status and create dynamic tests in the result buffer (JUnit/TestNG)
- [ ] **Test coverage support** - Add test coverage support

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### License

GPL-3.0

## Author

**Zsxh Chen** <[bnbvbchen@gmail.com](mailto:bnbvbchen@gmail.com)>

## Links

- [GitHub Repository](https://github.com/zsxh/eglot-jdtls)
- [Eclipse JDT Language Server](https://github.com/eclipse-jdtls/eclipse.jdt.ls)
- [Eglot](https://github.com/joaotavora/eglot)
- [dape](https://github.com/svaante/dape)
