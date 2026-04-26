# eglot-jdtls

[![license](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.txt)

**Eclipse JDT Language Server integration with Eglot**

This package provides seamless integration between Eglot (the Emacs LSP client) and the Eclipse JDT Language Server, enabling advanced Java language features including code generation, refactoring, debugging, testing, and navigation.

## Features

- **Code Generation**
  - Override methods
  - Generate `toString()`
  - Generate `hashCode()` and `equals()`
  - Generate getters and setters
  - Generate constructors
  - Generate delegate methods

- **Advanced Refactoring**
  - Move files between packages
  - Move instance/static members
  - Move types to new files or other classes
  - Extract methods, variables, constants, and fields
  - Change method signature interactively
  - Extract interfaces
  - Introduce parameters
  - Convert anonymous classes to nested classes

- **Debugging** (requires [dape](https://github.com/svaante/dape) and [java-debug](https://github.com/Microsoft/java-debug) bundle)
  - Run and debug Java programs via [dape](https://github.com/svaante/dape)
  - Hot code replace in running debug sessions
  - Run/Debug CodeLenses on `main` methods

- **Testing** (requires [dape](https://github.com/svaante/dape) and [java-test](https://github.com/microsoft/vscode-java-test) bundle)
  - Run and debug JUnit 4/5/6 and TestNG tests
  - Run/Debug CodeLenses on test methods (requires [eglot-codelens](https://github.com/zsxh/eglot-codelens))

- **Navigation**
  - Jump to definitions in JAR files with automatic decompilation
  - Find references and implementations

- **Extended LSP Capabilities**
  - Class file contents support (decompile from JARs)
  - Advanced import organization
  - Infer selection for code actions

## Requirements

- Emacs 30.1 or later
- [Eglot](https://github.com/joaotavora/eglot) 1.23 or later
- [Eclipse JDT Language Server](https://github.com/eclipse-jdtls/eclipse.jdt.ls) (jdtls)
- [dape](https://github.com/svaante/dape) 0.26.0 or later (for debugging and testing)
- [eglot-codelens](https://github.com/zsxh/eglot-codelens) (optional, for Run/Debug CodeLenses)
- [dape-toolbar](https://github.com/zsxh/dape-toolbar) (optional, dape toolbar)

## Installation

### Using package-vc

```emacs-lisp
(unless (package-installed-p 'eglot-jdtls)
  (package-vc-install
   '(eglot-jdtls :url "https://github.com/zsxh/eglot-jdtls")))
```

### Manual Installation

Download `eglot-jdtls.el` and add it to your load path:

```emacs-lisp
(add-to-list 'load-path "/path/to/eglot-jdtls")
(require 'eglot-jdtls)
```

## Configuration

### Basic Setup

The simplest configuration uses the default `jdtls` command:

```emacs-lisp
(require 'eglot-jdtls)

(push '((java-mode java-ts-mode) . (eglot-jdtls-server . eglot-jdtls-cmd))
        eglot-server-programs)
```

Then enable `eglot` in Java buffers with `M-x eglot`.

### Advanced Configuration

For custom JDTLS initialization (e.g., Lombok support, multiple JDKs, debugging, testing):

```emacs-lisp
(setq eglot-jdtls-config
      '(:cmd ("jdtls"
              "--jvm-arg=-javaagent:/path/to/lombok.jar"
              "--jvm-arg=-XX:+UseStringDeduplication")
        :init-options (:bundles ["/path/to/bundles.jar"])))

;; JDTLS JavaConfigurationSettings
;; https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
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

### Configuration Options

| Variable                       | Description                                       | Default                  |
|--------------------------------|---------------------------------------------------|--------------------------|
| `eglot-jdtls-cache-dir`        | Directory for caching JAR source files            | `~/.emacs.d/eglot-jdtls` |
| `eglot-jdtls-crm-separator`    | Separator for multiple selections in code actions | `"[ \t]*;[ \t]*"`        |
| `eglot-jdtls-config`           | JDTLS server configuration plist                  | `nil`                    |
| `eglot-jdtls-debugger-args`    | Arguments passed to the main class                | `nil`                    |
| `eglot-jdtls-debugger-vm-args` | JVM arguments passed when running/debugging       | `nil`                    |
| `eglot-jdtls-debugger-env`     | Environment variables for running/debugging       | `nil`                    |

The `eglot-jdtls-config` plist supports:
- `:cmd` - JDTLS command (list or function returning list)
- `:init-options` - Initialization options including `extendedClientCapabilities` and `bundles`

## Usage

### Code Generation

Code generation features are available through Eglot's code action interface (`M-x eglot-code-actions`):

- **Override Methods**: Prompts to select methods from superclass/interfaces
- **Generate toString()**: Select fields to include
- **Generate hashCode() & equals()**: Select fields for comparison
- **Generate Getters & Setters**: Select fields to generate accessors for
- **Generate Constructors**: Select constructors and fields to initialize
- **Generate Delegate Methods**: Create wrapper methods delegating to field methods

### Refactoring

Refactoring operations are available via code actions or specific commands:

- **Move File**: Move `.java` files between packages
- **Move Instance Method**: Move method to a field's type or parameter's type
- **Move Static Member**: Move static fields/methods/types to other classes
- **Move Type**: Move nested types to new files or other classes
- **Extract Interface**: Create interface from selected class members
- **Change Signature**: Interactive buffer for modifying method parameters, return types, exceptions, and access modifiers (press `C-c C-c` to apply)
- **Extract Method/Variable/Constant/Field**: Infer selection and extract
- **Introduce Parameter**: Convert local variable to method parameter
- **Convert Anonymous to Nested**: Convert anonymous class to named nested class

### Debugging

To enable debugging and testing, add the [java-debug](https://github.com/Microsoft/java-debug) bundle to `eglot-jdtls-config`, you can also install debug bundle via [mason](https://github.com/mason-org/mason.el):

```emacs-lisp
(setq eglot-jdtls-config
      '(:init-options (:bundles ["/path/to/com.microsoft.java.debug.plugin-*.jar"])))
```

Install [eglot-codelens](https://github.com/zsxh/eglot-codelens).

- **Run/Debug CodeLenses**: Click the Run or Debug lens above `main` methods to launch programs via [dape](https://github.com/svaante/dape)
- **Hot Code Replace**: During a debug session, use `eglot-jdtls-debugger-hot-code-replace` (or `R` in dape-toolbar) to reload changed classes without restarting

### Testing

To enable testing, add the [java-test](https://github.com/microsoft/vscode-java-test) bundle to `eglot-jdtls-config`, you can also install debug bundle via [mason](https://github.com/mason-org/mason.el):

```emacs-lisp
(setq eglot-jdtls-config
      '(:init-options (:bundles ["/path/to/com.microsoft.java.test.plugin-*.jar"])))
```

Install [eglot-codelens](https://github.com/zsxh/eglot-codelens).

- **Run/Debug Test CodeLenses**: Click the Run or Debug lens above test methods to execute JUnit 4/5/6 or TestNG tests via [dape](https://github.com/svaante/dape) (requires [eglot-codelens](https://github.com/zsxh/eglot-codelens))
- **Test result output** is displayed in the `*eglot-jdtls-test-result*` buffer

### Commands

| Command                                 | Description                                       |
|-----------------------------------------|---------------------------------------------------|
| `eglot-jdtls-organize-imports`          | Organize and optimize imports in current buffer   |
| `eglot-jdtls-clear-cache`               | Clear the cached decompiled Java source files     |
| `eglot-jdtls-debugger-hot-code-replace` | Reload changed classes in a running debug session |

### Format Options

The package respects `tab-width` and `indent-tabs-mode` for refactoring. Set these before executing refactoring commands if you need custom formatting.

## URI Handler

The package handles `jdt://` URIs automatically, fetching and caching decompiled source files from the JDT Language Server. This enables navigation into JAR file contents and JDK sources.

Cached files are stored in `eglot-jdtls-cache-dir` (default: `~/.emacs.d/eglot-jdtls`).

## Troubleshooting

### JDTLS Fails to Start

- Ensure the `jdtls` command is in your PATH
- Or provide the full path in `eglot-jdtls-config`:

```emacs-lisp
(setq eglot-jdtls-config
      '(:cmd ("/full/path/to/jdtls")))
```

### Class File Navigation Issues

Try clearing the cache:

```emacs-lisp
M-x eglot-jdtls-clear-cache
```

### Debugging

Check JDTLS logs with:

```emacs-lisp
M-x eglot-events-buffer
```

## TODOs

- [ ] **Analyze test results** - Visualize test case pass/fail status and create dynamic tests in the result buffer (JUnit/TestNG)
- [ ] **Test coverage support** - Add test coverage support

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See [LICENSE](LICENSE) for details.

## Author

**Zsxh Chen** <[bnbvbchen@gmail.com](mailto:bnbvbchen@gmail.com)>

## Links

- [GitHub Repository](https://github.com/zsxh/eglot-jdtls)
- [Eclipse JDT Language Server](https://github.com/eclipse-jdtls/eclipse.jdt.ls)
- [Eglot](https://github.com/joaotavora/eglot)
- [dape](https://github.com/svaante/dape)
