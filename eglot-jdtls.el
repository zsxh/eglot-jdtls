;;; eglot-jdtls.el --- Eclipse JDT Language Server integration with Eglot -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Zsxh Chen

;; Author: Zsxh Chen <bnbvbchen@gmail.com>
;; Maintainer: Zsxh Chen <bnbvbchen@gmail.com>
;; URL: https://github.com/zsxh/eglot-jdtls
;; Version: 0.2.0
;; Package-Requires: ((emacs "30.1") (compat "30.1.0.1") (eglot "1.23") (jsonrpc "1.0.28") (dape "0.26.0"))
;; Keywords: eglot, tools

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; eglot-jdtls provides integration between Eglot and the Eclipse JDT Language Server.
;; It enables advanced Java language features including code generation, refactoring,
;; debugging, testing, and navigation through Eglot's LSP client interface.
;;
;; Installation
;; ------------
;; Put this file in your load path and require it:
;;
;;   (require 'eglot-jdtls)
;;
;; Basic Configuration
;; ------------------
;; The simplest configuration uses the default jdtls command:
;;
;;   (push '((java-mode java-ts-mode) . (eglot-jdtls-server . eglot-jdtls-cmd))
;;         eglot-server-programs)
;;
;; For custom JDTLS initialization (e.g., Lombok support, debugging, testing), configure `eglot-jdtls-config':
;;
;;   (setq eglot-jdtls-config
;;         '(:cmd ("jdtls"
;;                 "--jvm-arg=-javaagent:/path/to/lombok.jar"
;;                 "--jvm-arg=-XX:+UseStringDeduplication")
;;           :init-options (:bundles ["/path/to/bundles.jar"])))
;;
;;   ;; JDTLS JavaConfigurationSettings
;;   ;; https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
;;   (setq-default eglot-workspace-configuration
;;                 '(:java
;;                   (:configuration
;;                     (:runtimes [(:name "JavaSE-1.8"
;;                                  :path "/path/to/JDK_8_HOME")
;;                                 (:name "JavaSE-17"
;;                                  :path "/path/to/JDK_17_HOME")
;;                                 (:name "JavaSE-21"
;;                                  :path "/path/to/JDK_21_HOME"
;;                                  :default t)]))))
;;
;; Configuration Options
;; ---------------------
;; * `eglot-jdtls-cache-dir' - Directory for caching JAR source files (default: ~/.emacs.d/eglot-jdtls)
;; * `eglot-jdtls-crm-separator' - Separator for multiple selections in code actions
;; * `eglot-jdtls-config' - JDTLS server configuration plist
;;   - :cmd - JDTLS command (list or function returning list)
;;   - :init-options - Initialization options including extendedClientCapabilities and bundles
;; * `eglot-jdtls-debugger-args' - Arguments passed to the main class when running/debugging
;; * `eglot-jdtls-debugger-vm-args' - JVM arguments passed when running/debugging
;; * `eglot-jdtls-debugger-env' - Environment variables for running/debugging
;;
;; Extended Client Capabilities
;; ----------------------------
;; The package enables advanced JDTLS features by default:
;; - Class file contents support (decompile from JARs)
;; - Override/hashCode/equals/toString generation prompts
;; - Advanced import organization
;; - Constructor/accessor/delegate method generation
;; - Advanced refactoring (extract, move, change signature)
;; - Infer selection for code actions
;;
;; Key Features
;; ------------
;;
;; **Code Generation**
;; Generate common Java patterns via code actions:
;; - Override Methods: Prompts to select methods from superclass/interfaces
;; - Generate toString(): Select fields to include
;; - Generate hashCode() & equals(): Select fields for comparison
;; - Generate Getters & Setters: Select fields to generate accessors for
;; - Generate Constructors: Select constructors and fields to initialize
;; - Generate Delegate Methods: Create wrapper methods delegating to field methods
;;
;; **Refactoring**
;; Advanced refactoring operations:
;; - Move File: Move .java files between packages
;; - Move Instance Method: Move method to a field's type or parameter's type
;; - Move Static Member: Move static fields/methods/types to other classes
;; - Move Type: Move nested types to new files or other classes
;; - Extract Interface: Create interface from selected class members
;; - Change Signature: Interactive buffer for modifying method parameters,
;;   return types, exceptions, and access modifiers (C-c C-c to apply)
;; - Extract Method/Variable/Constant/Field: Infer selection and extract
;; - Introduce Parameter: Convert local variable to method parameter
;; - Convert Anonymous to Nested: Convert anonymous class to named nested class
;;
;; **Debugging** (requires dape and java-debug bundle)
;; - Run and debug Java programs via dape
;; - Hot code replace in running debug sessions
;; - Run/Debug CodeLenses on main methods
;;
;; **Testing** (requires dape, java-test bundle, and eglot-codelens)
;; - Run and debug JUnit 4/5/6 and TestNG tests via dape
;; - Run/Debug CodeLenses on test methods
;;
;; **Navigation**
;; - Jump to definitions in JAR files (automatic decompilation via jdt:// URIs)
;; - Find references and implementations
;;
;; Available Commands
;; ------------------
;; * `eglot-jdtls-organize-imports' - Organize and optimize imports in current buffer
;; * `eglot-jdtls-clear-cache' - Clear the cached decompiled Java source files
;; * `eglot-jdtls-debugger-hot-code-replace' - Reload changed classes in a running debug session
;;
;; URI Handler
;; -----------
;; The package handles jdt:// URIs automatically, fetching and caching
;; decompiled source files from the JDT Language Server.  This enables
;; navigation into JAR file contents and JDK sources.
;;
;; Customization Examples
;; ----------------------
;; **Custom format options**
;;   The package respects `tab-width' and `indent-tabs-mode' for refactoring.
;;   Set these before executing refactoring commands.
;;
;; Integration with Vertico
;; ------------------------
;; The package temporarily disables `vertico-sort-function' for code action
;; selections to preserve the order returned by JDTLS, ensuring consistent
;; and predictable completion candidates.
;;
;; Troubleshooting
;; ---------------
;; - If JDTLS fails to start, ensure the jdtls command is in your PATH
;;   or provide the full path in `eglot-jdtls-config'
;; - For class file navigation issues, try `eglot-jdtls-clear-cache'
;; - Check JDTLS logs with `M-x eglot-events-buffer'
;; - Ensure your Java project has proper build configuration (Maven/Gradle)
;;   for accurate code completion and navigation
;;

;;; Code:

(require 'cl-lib)
(require 'compat)
(require 'eglot)
(require 'jsonrpc)
(require 'dape)

(require 'eglot-jdtls-debugger)
(require 'eglot-jdtls-tester)

;; Declare external variables to suppress byte-compile warnings
(defvar crm-separator)
(defvar vertico-sort-function)

;; Declare internal Eglot functions to suppress byte-compile warnings
(declare-function eglot--languages "eglot")
(declare-function eglot--servers-by-project "eglot")
(declare-function eglot--current-project "eglot")
(declare-function eglot--apply-workspace-edit "eglot")
(declare-function eglot--goto "eglot")
(declare-function eglot--current-server-or-lose "eglot")
(declare-function eglot--collecting-xrefs "eglot")
(declare-function eglot--xref-make-match "eglot")
(declare-function eglot-uri-to-path "eglot")
(declare-function eglot-path-to-uri "eglot")
(declare-function eglot-execute "eglot")
(declare-function eglot-current-server "eglot")


(defgroup eglot-jdtls nil
  "Settings for Eclipse JDT Language Server integration with Eglot."
  :group 'eglot
  :prefix "eglot-jdtls-"
  :link '(url-link :tag "GitHub" "https://github.com/zsxh/eglot-jdtls"))

;;;###autoload
(defclass eglot-jdtls-server (eglot-lsp-server)
  ((bundles-loaded
    :initform nil
    :documentation "Flag indicating if bundles have been loaded."
    :accessor eglot-jdtls--bundles-loaded)
   (bundles-contain-debug
    :initform nil
    :documentation "Flag indicating if debug bundle is present."
    :accessor eglot-jdtls--bundles-contain-debug)
   (bundles-contain-test
    :initform nil
    :documentation "Flag indicating if test bundle is present."
    :accessor eglot-jdtls--bundles-contain-test)
   (test-source-paths
    :initform nil
    :documentation "Test source paths for the project."
    :accessor eglot-jdtls--test-source-paths)
   (test-items-cache
    :initform nil
    :documentation "Hash table mapping URI strings to test-item hash tables.
Each value is a hash-table where each key is a test-item ID and \
each value is a test-item plist:
:id - unique identifier
:uri - test file URI
:label - display name
:fullName - fully qualified name
:testLevel - test level (root=0, workspace=1, workspace-folder=2,
             project=3, package=4, class=5, method=6, invocation=7)
:testKind - test framework kind (JUnit5=0, JUnit=1, TestNG=2,
            JUnit6=3, None=100)
:projectName - project name
:range - location range
:jdtHandler - JDT handler identifier
:children - list of child test-item id"
    :accessor eglot-jdtls--test-items-cache))
  :documentation "eclipse's jdt langserver."
  :group 'eglot-jdtls)

;; Variables

(defcustom eglot-jdtls-cache-dir
  (expand-file-name "eglot-jdtls" user-emacs-directory)
  "Directory to cache Java source files from jdt:// URIs."
  :type 'directory
  :group 'eglot-jdtls)

(defcustom eglot-jdtls-crm-separator "[ \t]*;[ \t]*"
  "Separator for `completing-read-multiple' in Java code actions."
  :type 'string
  :group 'eglot-jdtls)

(defcustom eglot-jdtls-config nil
  "JDTLS server config for eglot."
  :type '(plist :key-type (restricted-sexp
                           :match-alternatives (keywordp)
                           :tag "Keyword")
                :value-type sexp)
  :group 'eglot-jdtls)

(defvar eglot-jdtls--default-config
  '(:cmd ("jdtls")
    :init-options (:bundles []
                   :extendedClientCapabilities
                   (:classFileContentsSupport t
                    :overrideMethodsPromptSupport t
                    :hashCodeEqualsPromptSupport t
                    :executeClientCommandSupport t
                    :advancedOrganizeImportsSupport t
                    :generateConstructorsPromptSupport t
                    :generateToStringPromptSupport t
                    :advancedGenerateAccessorsSupport t
                    :generateDelegateMethodsPromptSupport t
                    :advancedExtractRefactoringSupport t
                    :inferSelectionSupport ["extractMethod"
                                            "extractVariable"
                                            "extractField"]
                    :moveRefactoringSupport t
                    :extractInterfaceSupport t
                    :advancedIntroduceParameterRefactoringSupport t)))
  "JDTLS server default config for eglot.")

(defconst eglot-jdtls--symbol-kind-type 55
  "LSP SymbolKind for Type.")
(defconst eglot-jdtls--symbol-kind-enum 71
  "LSP SymbolKind for Enum.")
(defconst eglot-jdtls--symbol-kind-annotation 81
  "LSP SymbolKind for Annotation Type.")

(defconst eglot-jdtls--change-signature-buffer-name
  "*eglot-jdtls:Change Method Signature*"
  "Buffer name for change signature editing.")

;; Eglot jdtls config

(defun eglot-jdtls-cmd (&optional _interactive &rest _args)
  "Return the JDT Language Server command for Eglot."
  (let ((cmd (or (plist-get eglot-jdtls-config :cmd)
                 (plist-get eglot-jdtls--default-config :cmd))))
    (cond
     ((functionp cmd)
      (funcall cmd))
     ((listp cmd)
      (let* ((program (car cmd))
             (exec (executable-find program)))
        (unless exec
          (user-error "[eglot-jdtls] can not find executable cmd"))
        (cons exec (cdr cmd))))
     (t
      (user-error "[eglot-jdtls] eglot-jdtls-config :cmd should be either a function or list")))))

(defun eglot-jdtls--plist-merge (&rest plists)
  "Merge multiple PLISTS into one, with later values overriding earlier ones.
Each argument should be a property list.  Returns a new plist."
  (let ((result nil))
    (dolist (plist plists)
      (while plist
        (setq result (plist-put result (car plist) (cadr plist)))
        (setq plist (cddr plist))))
    result))

(cl-defmethod eglot-initialization-options ((_server eglot-jdtls-server))
  "Return initialization options for JDT LS SERVER."
  (let* ((user-init (plist-get eglot-jdtls-config :init-options))
         (default-init (plist-get eglot-jdtls--default-config :init-options))
         (init-options (eglot-jdtls--plist-merge default-init user-init)))
    (list
     :extendedClientCapabilities (plist-get init-options
                                            :extendedClientCapabilities)
     :bundles (plist-get init-options :bundles))))

(defun eglot-jdtls--update-server-state (server)
  "Update SERVER state from init options."
  (let* ((init-options (plist-get eglot-jdtls-config :init-options))
         (bundles (plist-get init-options :bundles)))
    (setf (eglot-jdtls--bundles-loaded server) t)
    ;; TODO: allow user customize regex list
    (setf (eglot-jdtls--bundles-contain-debug server)
          (cl-some (lambda (bundle)
                     (string-match-p
                      "com\\.microsoft\\.java\\.debug\\.plugin[^/]*\\.jar$"
                      bundle))
                   bundles))
    (setf (eglot-jdtls--bundles-contain-test server)
          (cl-some (lambda (bundle)
                     (string-match-p
                      "com\\.microsoft\\.java\\.test\\.plugin[^/]*\\.jar$"
                      bundle))
                   bundles))
    (when-let* ((_ (eglot-jdtls--bundles-contain-test server))
                (project (project-current))
                (proj-root (project-root project))
                (workspace-folder-uri (eglot-path-to-uri proj-root))
                (test-path-items (eglot-jdtls-tester--test-source-paths
                                  workspace-folder-uri))
                (test-paths (seq-map
                             (lambda (item)
                               (plist-get item :testSourcePath))
                             test-path-items)))
      (setf (eglot-jdtls--test-source-paths server) test-paths)
      (setf (eglot-jdtls--test-items-cache server)
            (make-hash-table :test 'equal)))))

;; CodeAction / Commands

(defun eglot-jdtls--select (items prompt display-item-fn
                                   &optional multiple-p transform-fn)
  "Select an item from ITEMS using PROMPT.
DISPLAY-ITEM-FN is a function of one argument used to display items
in completion.
If MULTIPLE-P is non-nil, select multiple items.
TRANSFORM-FN is a function of one argument applied to selected item
before returning them."
  (let* ((cands (mapcar
                 (lambda (item)
                   (cons (funcall display-item-fn item) item))
                 items))
         (item-fn (lambda (choice)
                    (let ((item (alist-get choice cands nil nil 'equal)))
                      (if transform-fn
                          (funcall transform-fn item)
                        item))))
         (crm-separator (or eglot-jdtls-crm-separator crm-separator)))
    (if multiple-p
        (cl-map 'vector
                item-fn
                (delete-dups
                 (completing-read-multiple prompt cands)))
      (funcall item-fn (completing-read prompt cands)))))

(defun eglot-jdtls--format-options ()
  "Return formatting options for Java code actions."
  (list
   :tabSize tab-width
   :insertSpaces (if indent-tabs-mode
                     :json-false
                   t)))

(defun eglot-jdtls--find-jdt-server ()
  "Find the active JDT Language Server for the current project."
  (let ((filter-fn (lambda (server)
                     (cl-loop for (_mode . languageid) in
                              (eglot--languages server)
                              when (string= languageid "java")
                              return languageid)))
        (servers (gethash (eglot--current-project) eglot--servers-by-project)))
    (cl-find-if filter-fn servers)))

(defun eglot-jdtls-uri-handler (operation &rest args)
  "Handle file operations for Eclipse JDT Language Server `jdt://' URIs.

This URI handler enables Emacs to access Java source files that are
bundled in JAR files or stored in the JDT server's virtual filesystem.
It fetches source content from the JDT LS and caches it locally.

OPERATION is the file operation to perform.
ARGS contains the operation arguments, typically starting with the URI.

Supported operations:
  - `expand-file-name': Return the local cached file path
  - `file-truename': Return the local cached file path
  - `file-local-name': Return the local cached file path
  - `file-remote-p': Return nil (files are always local after caching)

Unrecognized operations are forwarded to the default file handlers."
  (let* ((uri (car args))
         (cache-dir eglot-jdtls-cache-dir)
         (_ (unless (string-match "jdt://contents/\\([^/]+\\)/\\(.+\\)\\.\\([^.]+\\)\\?" uri)
              (error "Invalid JDT URI format: %s" uri)))
         (jar-file (substring uri (match-beginning 1) (match-end 1)))
         (jar-class-name (replace-regexp-in-string "/" "." (substring uri (match-beginning 2) (match-end 2)) t t))
         (jar-class-ext (substring uri (match-beginning 3) (match-end 3)))
         (jar-class-file (format "%s.%s" jar-class-name
                                 (if (string-equal jar-class-ext "class")
                                     "java"
                                   jar-class-ext)))
         (jar-dir (concat (file-name-as-directory cache-dir)
                          (file-name-as-directory jar-file)))
         (source-file (expand-file-name (concat jar-dir jar-class-file))))
    (unless (file-readable-p source-file)
      (let* ((server (or (eglot-current-server)
                         ;; NOTE: dape https://github.com/svaante/dape/issues/78#issuecomment-1966786597
                         (eglot-jdtls--find-jdt-server)))
             (_ (unless server
                  (error "No JDT language server running")))
             (content (jsonrpc-request
                       server :java/classFileContents (list :uri uri))))
        (unless content
          (error "No class file contents found"))
        (unless (file-directory-p jar-dir) (make-directory jar-dir t))
        (with-temp-file source-file (insert content))))
    (cond
     ((eq operation 'expand-file-name) source-file)
     ((eq operation 'file-truename) source-file)
     ((eq operation 'file-local-name) source-file)
     ((eq operation 'file-remote-p) nil)
     ;; Handle any operation we don’t know about.
     (t (let ((inhibit-file-name-handlers
               (cons 'eglot-jdtls-uri-handler
                     (and (eq inhibit-file-name-operation operation)
                          inhibit-file-name-handlers)))
              (inhibit-file-name-operation operation))
          (apply operation args))))))

(add-to-list 'file-name-handler-alist '("\\`jdt://" . eglot-jdtls-uri-handler))

(defun eglot-jdtls--apply-workspaceEdit (arguments)
  "Apply workspace edit(s) ARGUMENTS from JDT LS command.
Command is `java.apply.workspaceEdit'."
  (mapc (lambda (edit)
          (eglot--apply-workspace-edit edit this-command))
        arguments))

(defun eglot-jdtls--override-methods-prompt (server arguments)
  "Handle JDT LS command `java.action.overrideMethodsPrompt'.

Prompt user to select methods to override and generate override method stubs.

SERVER is the JDT Language Server instance.
ARGUMENTS is the context information for where to add the override methods."
  (let* ((argument (seq-elt arguments 0))
         (list-methods-result (jsonrpc-request server :java/listOverridableMethods argument))
         (methods (plist-get list-methods-result :methods))
         (selected-methods (eglot-jdtls--select
                            methods
                            "Select methods: "
                            (lambda (method)
                              (pcase-let*
                                  (((map :name :parameters
                                      (:declaringClass class)) method))
                                (format "%s(%s): %s"
                                        name
                                        (mapconcat #'identity parameters ", ")
                                        class)))
                            t))
         (add-methods-result (jsonrpc-request
                              server
                              :java/addOverridableMethods
                              (list :overridableMethods selected-methods
                                    :context argument))))
    (eglot--apply-workspace-edit add-methods-result this-command)))

(defun eglot-jdtls--show-references (command arguments)
  "Display Java references using Emacs xref interface.

COMMAND is the JDT LS command name
ARGUMENTS is a list containing reference information"
  (if-let* ((refs (seq-elt arguments 2))
            (_ (length> refs 0)))
      (xref-show-xrefs
       (eglot--collecting-xrefs (collect)
         (mapc
          (lambda (ref)
            (pcase-let* (((map :uri :range) ref))
              (collect (eglot--xref-make-match "" uri range))))
          refs))
       nil)
    (message "%s returned no references" command)))

(defun eglot-jdtls--rename (arguments)
  "Execute Java rename action using Eglot's interactive rename interface.

ARGUMENTS is a list containing a map with uri, offset, and length
identifying the element to rename."
  (pcase-let* (((map :uri :offset :length) (seq-elt arguments 0)))
    (with-current-buffer (find-file (eglot-uri-to-path uri))
      (deactivate-mark)
      (goto-char (1+ offset))
      (set-mark (point))
      (goto-char (+ (point) length))
      (exchange-point-and-mark)
      ;; (sit-for 0.5)
      (call-interactively 'eglot-rename)
      (deactivate-mark))))

(defun eglot-jdtls--generate-toString-prompt (server arguments)
  "Prompt user to generate toString method for Java class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (pcase-let* ((params (seq-elt arguments 0))
               (check-resp (jsonrpc-request
                            server :java/checkToStringStatus
                            params))
               ((map :fields :exists) check-resp))
    (when (or (eq exists :json-false)
              (y-or-n-p "The toString() method already exists.  Replace?"))
      (let* ((selected-fields (eglot-jdtls--select
                               fields
                               "Select fields to include: "
                               (lambda (field)
                                 (pcase-let* (((map :name :type) field))
                                   (format "%s: %s" name type)))
                               t))
             (result (jsonrpc-request
                               server :java/generateToString
                               (list :fields selected-fields
                                     :context params))))
        (eglot--apply-workspace-edit result this-command)))))

(defun eglot-jdtls--hashCode-equals-prompt (server arguments)
  "Prompt user to generate hashCode and equals methods for Java class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (pcase-let* ((params (seq-elt arguments 0))
               (check-resp (jsonrpc-request
                            server :java/checkHashCodeEqualsStatus
                            params))
               ((map :fields :existingMethods) check-resp))
    (when (or (seq-empty-p existingMethods)
              (y-or-n-p (format "The %s method already exists.  Replace?"
                                existingMethods)))
      (let* ((selected-fields (eglot-jdtls--select
                               fields
                               "Select fields to include: "
                               (lambda (field)
                                 (pcase-let* (((map :name :type) field))
                                   (format "%s: %s" name type)))
                               t))
             (result (jsonrpc-request
                               server :java/generateHashCodeEquals
                               (list
                                :fields selected-fields
                                :context params
                                :regenerate (not (seq-empty-p existingMethods))))))
        (eglot--apply-workspace-edit result this-command)))))

(defun eglot-jdtls--generate-accessors-prompt (server arguments)
  "Prompt user to generate accessor methods (getters and setters) for Java fields.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (let* ((params (seq-elt arguments 0))
         (accessor-fields (jsonrpc-request
                           server :java/resolveUnimplementedAccessors
                           params))
         (selected-accessors (eglot-jdtls--select
                              accessor-fields
                              "Select fields to generate: "
                              (lambda (field)
                                (pcase-let*
                                    (((map (:fieldName field)
                                           (:typeName type)) field))
                                  (format "%s: %s" field type)))
                              t))
         (result (jsonrpc-request
                  server :java/generateAccessors
                  (list :accessors selected-accessors
                        :context params))))
    (eglot--apply-workspace-edit result this-command)))

(defun eglot-jdtls--generate-constructors-prompt (server arguments)
  "Prompt user to generate constructors for Java class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (pcase-let*
      ((params (seq-elt arguments 0))
       (check-resp (jsonrpc-request
                    server :java/checkConstructorsStatus
                    params))
       ((map :constructors :fields) check-resp)
       (selected-constructors (eglot-jdtls--select
                               constructors
                               "Select constructors to generate: "
                               (lambda (constructor)
                                 (pcase-let*
                                     (((map :name :parameters) constructor))
                                   (format
                                    "%s(%s)" name
                                    (mapconcat #'identity parameters ", "))))
                               t))
       (selected-fields (eglot-jdtls--select
                         fields
                         "Select fields to generate: "
                         (lambda (field)
                           (pcase-let* (((map :name :type) field))
                             (format "%s: %s" name type)))
                         t))
       (result (jsonrpc-request server :java/generateConstructors
                                (list :context params
                                      :constructors selected-constructors
                                      :fields selected-fields))))
    (eglot--apply-workspace-edit result this-command)))

(defun eglot-jdtls--generate-delegate-methods-prompt-support (server arguments)
  "Prompt user to generate delegate methods for Java fields.

Delegate methods are wrapper methods that delegate calls to methods of a field.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (pcase-let*
      ((params (seq-elt arguments 0))
       (check-resp (jsonrpc-request
                    server :java/checkDelegateMethodsStatus params))
       (delegate-fields (plist-get check-resp :delegateFields))
       (selected-field (eglot-jdtls--select
                        delegate-fields
                        "Select target to generate delegates for: "
                        (lambda (item)
                          (pcase-let*
                              ((field (plist-get item :field))
                               ((map :name :type) field))
                            (format "%s: %s" name type)))))
       ((map :field (:delegateMethods delegate-methods)) selected-field)
       (field-name (plist-get field :name))
       (selected-methods (eglot-jdtls--select
                          delegate-methods
                          "Select methods to generate delegates for: "
                          (lambda (method)
                            (pcase-let*
                                (((map :name :parameters) method))
                              (format
                               "%s.%s(%s)" field-name name
                               (mapconcat #'identity parameters ", "))))
                          t
                          (lambda (method)
                            (list :field field :delegateMethod method))))
       (result (jsonrpc-request
                server :java/generateDelegateMethods
                (list :context params
                      :delegateEntries selected-methods))))
    (eglot--apply-workspace-edit result this-command)))

(defun eglot-jdtls--refactor-edit (server refactor-edit)
  "Apply a JDT LS refactoring edit result to the workspace.

SERVER is the JDT Language Server instance.
REFACTOR-EDIT is a map containing the refactoring result with:
  - `edit': Workspace edit to apply (optional)
  - `command': Follow-up command to execute after the edit (optional)
  - `errorMessage': Error message if the refactoring failed (optional)"
  (pcase-let*
      (((map :edit :command (:errorMessage err)) refactor-edit))
    (when err
      (message "%s" err))
    (when edit
      (eglot--apply-workspace-edit edit this-command))
    (when command
      (eglot-execute server command))))

(defun eglot-jdtls--move-file (server arguments)
  "Move Java source file to a different package.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing the move operation context from JDT LS
command, with the file URI at index 2."
  (pcase-let* ((uris (vector (plist-get (seq-elt arguments 2) :uri)))
               (move-dest-resp (jsonrpc-request
                                server :java/getMoveDestinations
                                (list :moveKind "moveResource"
                                      :sourceUris uris
                                      :params nil)))
               ((map (:errorMessage err-msg)
                     :destinations) move-dest-resp))
    (cond
     (err-msg (message "%s" err-msg))
     ((not (and (vectorp destinations) (length> destinations 0)))
      (message "Cannot find available Java packages to move the selected files to."))
     (t (let* ((destination (eglot-jdtls--select
                             destinations
                             (format "Choose the target package for %s: "
                                     (file-name-nondirectory (buffer-file-name)))
                             (lambda (item)
                               (format "%s - %s"
                                       (plist-get item :displayName)
                                       (plist-get item :path)))))
               (result (jsonrpc-request
                        server :java/move
                        (list :moveKind "moveResource"
                              :sourceUris uris
                              :params nil
                              :destination destination
                              :updateReferences t))))
          (eglot-jdtls--refactor-edit server result))))))

(defun eglot-jdtls--instant-method (server arguments)
  "Move an instance method to a different class (field or method parameter).

The method is moved to either a field's type or a method parameter's type,
converting it to a static method in the target class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing the move operation context from JDT LS
command, with parameters at index 1 and display info at index 2."
  (pcase-let* ((params (seq-elt arguments 1))
               (uris (vector (plist-get (plist-get params :textDocument) :uri)))
               (move-dest-resp (jsonrpc-request
                                server :java/getMoveDestinations
                                (list :moveKind "moveInstanceMethod"
                                      :sourceUris uris
                                      :params params)))
               ((map (:errorMessage err-msg)
                     :destinations) move-dest-resp))
    (cond
     (err-msg (message "%s" err-msg))
     ((not (and (vectorp destinations) (length> destinations 0)))
      (message "Cannot find available Java packages to move the selected files to"))
     (t
      (let* ((display-name (or (plist-get (seq-elt arguments 2) :displayName) ""))
             (destination (eglot-jdtls--select
                           destinations
                           (format
                            "Select the new class for the instance method %s: "
                            display-name)
                           (lambda (item)
                             (pcase-let*
                                 (((map :name :type (:isField is-field)) item))
                               (format "%s %s %s"
                                       (if (eq is-field :json-false)
                                           "[Method Parameter]"
                                         "[Field]           ")
                                       type name)))))
             (result (jsonrpc-request server :java/move
                                      (list :moveKind "moveInstanceMethod"
                                            :sourceUris uris
                                            :params params
                                            :destination destination
                                            :updateReferences t))))
        (eglot-jdtls--refactor-edit server result))))))

(defun eglot-jdtls--select-target-class (server prompt project-name excludes)
  "Select a target class from symbols in PROJECT-NAME.

SERVER is the JDT Language Server instance used to search for symbols.
PROMPT is the completion prompt to display to the user.
PROJECT-NAME is the name of the project to search for symbols.
EXCLUDES is a list of fully-qualified class names to exclude from selection."
  (let* ((symbols (jsonrpc-request
                   server :java/searchSymbols
                   (list :query "*"
                         :projectName project-name
                         :sourceOnly t)))
         (filtered-symbols (seq-filter
                            (lambda (item)
                              (pcase-let*
                                  (((map :name :containerName) item)
                                   (name (if containerName
                                             (format "%s.%s" containerName name)
                                           name)))
                                (not (member name excludes))))
                            symbols)))
    (when (length> filtered-symbols 0)
      (eglot-jdtls--select
       filtered-symbols
       prompt
       (lambda (item)
         (pcase-let* (((map :name :containerName) item))
           (format "%s %s" name containerName)))))))

(defun eglot-jdtls--move-static-member (server arguments)
  "Move a static member (field, method, or type) to another class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (pcase-let*
      ((`[_cmd ,params ,cmd-info] arguments)
       (uris (vector (plist-get (plist-get params :textDocument) :uri)))
       ((map (:displayName display-name "")
             (:projectName project-name "")
             (:enclosingTypeName type-name)
             :memberType) cmd-info)
       (excludes (when type-name
                   (if (memq memberType
                             (list eglot-jdtls--symbol-kind-type
                                   eglot-jdtls--symbol-kind-enum
                                   eglot-jdtls--symbol-kind-annotation))
                       (list type-name (format "%s.%s" type-name display-name))
                     (list type-name))))
       (target-class (eglot-jdtls--select-target-class
                      server
                      (format "Select the new class for the static member %s: "
                              display-name)
                      project-name
                      excludes)))
    (if target-class
        (let ((result (jsonrpc-request
                       server :java/move
                       (list :moveKind "moveStaticMember"
                             :sourceUris uris
                             :params params
                             :destination target-class))))
          (eglot-jdtls--refactor-edit server result))
      (message "No destination found"))))

(defun eglot-jdtls--move-type (server arguments)
  "Move a type (class, interface, enum, or annotation type) to another location.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (pcase-let*
      ((`[_cmd ,params ,cmd-info] arguments)
       (uris (vector (plist-get (plist-get params :textDocument) :uri)))
       ((map
         (:displayName display-name "")
         (:projectName project-name "")
         (:supportedDestinationKinds kinds)
         (:enclosingTypeName type-name)) cmd-info))
    (if (length= kinds 0)
        (message "No available destination kinds")
      (let* ((kind (eglot-jdtls--select
                    kinds
                    "What would you like to do?"
                    (lambda (item)
                      (pcase item
                        ("newFile" (format "Move type %s to new file" display-name))
                        (_ (format "Move type %s to another class" display-name))))))
             (move-type-params
              (pcase kind
                ("newFile" (list :moveKind "moveTypeToNewFile"
                                 :sourceUris uris
                                 :params params))
                (_ (let* ((excludes (when type-name
                                      (list type-name
                                            (format "%s.%s" type-name
                                                    display-name))))
                          (target-class (eglot-jdtls--select-target-class
                                         server
                                         (format
                                          "Select the new class for the type %s: "
                                          display-name)
                                         project-name
                                         excludes)))
                     (list :moveKind "moveTypeToClass"
                           :sourceUris uris
                           :params params
                           :destination target-class)))))
             (result (jsonrpc-request server :java/move move-type-params)))
        (eglot-jdtls--refactor-edit server result)))))

(defun eglot-jdtls--change-signature-make-label (str)
  "Create a read-only label from STR for the change signature buffer."
  (propertize str
              'read-only t
              'face 'font-lock-keyword-face
              'front-sticky t
              'rear-nonsticky t))

(defun eglot-jdtls--change-signature-make-comment (&rest strs)
  "Create a read-only comment section from STRS for the change signature buffer."
  (propertize (mapconcat #'identity strs "\n")
              'read-only t
              'face 'font-lock-comment-face
              'front-sticky t
              'rear-nonsticky t))

(defun eglot-jdtls--change-signature-build-content (sig-info)
  "Build the edit buffer content lines from SIG-INFO.
Returns a list of strings to be inserted into the buffer."
  (pcase-let (((map :modifier :returnType :methodName
                    :parameters :exceptions) sig-info))
    (let ((label #'eglot-jdtls--change-signature-make-label))
      `(,(concat (funcall label "Access modifier: ") modifier)
        ,(concat (funcall label "Return type: ") returnType)
        ,(concat (funcall label "Method name: ") methodName)
        ,(funcall label "Parameters:")
        ,@(cl-loop for param across parameters
                   collect
                   (pcase-let (((map :type :name :originalIndex) param))
                     (format "- %d: %s %s" originalIndex type name)))
        ,(funcall label "Exceptions:")
        ,@(cl-loop for exception across exceptions
                   for id from 0
                   collect
                   (pcase-let (((map :type) exception))
                     (format "- %d: %s" id type)))
        ,(concat (funcall label "IsDelegate: ") "false")
        ""
        ,(eglot-jdtls--change-signature-make-comment
          "---"
          "Labels are used to parse the values. Ensure they remain at the beginning of each line."
          "Usage:"
          " - [C-c C-c] refactor"
          " - [C-c C-k] quit"
          " - [C-c C-r] reset"
          ""
          "Parameters:"
          " - Order sensitive"
          " - New param format: '- <type> <name> [defaultValue]'"
          " - Existing param format: '- <n>: <type> <name>'"
          " - <n> marks the original index, don't add it for new entries, don't change for moved params"
          ""
          "Exceptions:"
          " - Order insensitive"
          " - New exception format: '- <type>'"
          " - Existing exception format: '- <n>: <type>'"
          " - <n> marks the original type id, don't add it for new entries, don't change for moved exception"
          ""
          "Access modifier: ['public'|'protected'|'private'|'']"
          ""
          "IsDelegate: ['true'|'false']"
          " - Keep original method as delegate to changed method"
          "---")))))

(defun eglot-jdtls--change-signature-set-buffer-content (buf lines)
  "Set the content of buffer BUF to LINES.
LINES is a list of strings to insert."
  (with-current-buffer buf
    (let ((inhibit-read-only t))
      (erase-buffer))
    (dolist (line lines)
      (insert line)
      (newline))
    (goto-char (point-min))))

(defun eglot-jdtls--change-signature-parse-line-item (line section sig-exceptions)
  "Parse a single LINE item based on current SECTION.
SIG-EXCEPTIONS are the original exceptions for type ID lookup.
Returns a plist for parameters or exceptions, or nil if not applicable."
  (pcase section
    ('parameters
     (when (string-match "\\-\\(?: \\([0-9]+\\):\\)? \\(\\S-+\\) \\(\\S-+\\)\\(?: \\(\\S-+\\)\\)?" line)
       (let ((idx (match-string 1 line))
             (type (match-string 2 line))
             (name (match-string 3 line))
             (default-val (match-string 4 line)))
         (list :type type
               :name name
               :defaultValue (if idx "" (or default-val "null"))
               :originalIndex (if idx (string-to-number idx) -1)))))
    ('exception
     (when (string-match "\\-\\(?: \\([0-9]+\\):\\)? \\(\\S-+\\)" line)
       (let* ((idx (match-string 1 line))
              (type (match-string 2 line))
              (type-id (when idx
                         (let ((idx-num (string-to-number idx)))
                           (when (and (>= idx-num 0)
                                      (< idx-num (length sig-exceptions)))
                             (plist-get (seq-elt sig-exceptions idx-num)
                                        :typeHandleIdentifier))))))
         (if type-id
             (list :type type :typeHandleIdentifier type-id)
           (list :type type)))))
    (_ nil)))

(defun eglot-jdtls--change-signature-parse-buffer (buf method-id sig-exceptions)
  "Parse the change signature edit buffer BUF.
METHOD-ID is the method identifier.
SIG-EXCEPTIONS are the original exceptions for type ID lookup.
Returns a vector of refactoring parameters."
  (with-current-buffer buf
    (save-excursion
      (goto-char (point-min))
      (let (access-modifier return-type method-name
            parameters exceptions is-delegate section)
        ;; Parse each line until we hit the comment section
        (cl-block parse-loop
          (while (not (eobp))
            (let ((line (thing-at-point 'line t)))
              (when (string-prefix-p "---" line)
                (cl-return-from parse-loop))
              (cond
               ((string-prefix-p "Access modifier: " line)
                (setq access-modifier
                      (string-trim (substring line (length "Access modifier: ")))))
               ((string-prefix-p "Return type: " line)
                (setq return-type
                      (string-trim (substring line (length "Return type: ")))))
               ((string-prefix-p "Method name: " line)
                (setq method-name
                      (string-trim (substring line (length "Method name: ")))))
               ((string-prefix-p "IsDelegate: " line)
                (setq is-delegate
                      (string-trim (substring line (length "IsDelegate: ")))))
               ((string-prefix-p "Parameters:" line)
                (setq section 'parameters))
               ((string-prefix-p "Exceptions:" line)
                (setq section 'exception))
               ((string-prefix-p "-" line)
                (when-let* ((item (eglot-jdtls--change-signature-parse-line-item
                                   line section sig-exceptions)))
                  (pcase section
                    ('parameters (push item parameters))
                    ('exception (push item exceptions)))))))
            (forward-line)))
        ;; Build result vector
        (vector method-id
                (if (equal is-delegate "true") t :json-false)
                method-name
                access-modifier
                return-type
                (vconcat (nreverse parameters))
                (vconcat (nreverse exceptions))
                :json-false)))))

(defun eglot-jdtls--change-signature-send-request (server cmd params cmd-params
                                                          on-success-window
                                                          on-success-buffer)
  "Send the change signature refactoring request to SERVER.
CMD is the refactoring command name.
PARAMS is the context parameters.
CMD-PARAMS are the parsed command parameters from the edit buffer.
ON-SUCCESS-WINDOW and ON-SUCCESS-BUFFER are the window and buffer
to clean up on success."
  (message "[eglot-jdtls] Sending async changeSignature request, \
it might take a few seconds to complete.")
  (jsonrpc-async-request
   server :java/getRefactorEdit
   (list :command cmd
         :context params
         :options (eglot-jdtls--format-options)
         :commandArguments cmd-params)
   :success-fn
   (lambda (result)
     (let ((edit (plist-get result :edit)))
       (when (or (plist-get edit :changes)
                 (plist-get edit :documentChanges))
         (eglot-jdtls--refactor-edit server result)
         (when (window-live-p on-success-window)
           (delete-window on-success-window))
         (when (buffer-live-p on-success-buffer)
           (kill-buffer on-success-buffer)))))
   :error-fn
   (lambda (err)
     (message "[eglot-jdtls] Change signature failed: %s"
              (plist-get err :message)))))

(defun eglot-jdtls--change-signature-setup-buffer (buf lines sig-info server cmd params)
  "Setup the change signature edit buffer BUF.
LINES is the initial content.
SIG-INFO contains the method signature information.
SERVER, CMD, and PARAMS are needed for the refactoring request."
  (let ((method-id (plist-get sig-info :methodIdentifier))
        (exceptions (plist-get sig-info :exceptions)))
    (with-current-buffer buf
      (eglot-jdtls--change-signature-set-buffer-content buf lines)
      ;; Set up keybindings
      (local-set-key
       (kbd "C-c C-c")
       (lambda ()
         (interactive)
         (let ((cmd-params (eglot-jdtls--change-signature-parse-buffer
                            buf method-id exceptions)))
           (eglot-jdtls--change-signature-send-request
            server cmd params cmd-params
            (selected-window) (current-buffer)))))
      (local-set-key
       (kbd "C-c C-r")
       (lambda ()
         (interactive)
         (eglot-jdtls--change-signature-set-buffer-content buf lines)))
      (local-set-key
       (kbd "C-c C-k")
       (lambda ()
         (interactive)
         (kill-buffer-and-window))))))

(defun eglot-jdtls--change-signature (server arguments)
  "Change method signature interactively using a dedicated edit buffer.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (pcase-let* ((`[,cmd ,params] arguments)
               (sig-info (jsonrpc-request server :java/getChangeSignatureInfo params)))
    ;; Check for errors
    (if-let* ((err-msg (plist-get sig-info :errorMessage)))
        (message "%s" err-msg)
      ;; Build and display the edit buffer
      (let* ((edit-buf (get-buffer-create eglot-jdtls--change-signature-buffer-name))
             (lines (eglot-jdtls--change-signature-build-content sig-info)))
        (eglot-jdtls--change-signature-setup-buffer
         edit-buf lines sig-info server cmd params)
        (switch-to-buffer-other-window edit-buf)))))

(defun eglot-jdtls--resolve-scopes (scopes)
  "Resolve initialization scope from available SCOPES.

SCOPES is a list of scope identifiers."
  (pcase (length scopes)
    (0 nil)
    (1 (seq-elt scopes 0))
    (_ (completing-read
        "Initialize the field in: "
        (append scopes nil)))))

(defun eglot-jdtls--get-expression (cmd params server)
  "Infer and select an expression for refactoring operations.

CMD is the refactoring command name (e.g., \"extractMethod\",
\"extractVariable\", \"extractConstant\", \"extractField\").
PARAMS is the context parameters for the refactoring operation.
SERVER is the JDT Language Server instance."
  (let ((expressions (jsonrpc-request
                      server :java/inferSelection
                      (list :command cmd
                            :context params))))
    (pcase (length expressions)
      (0 nil)
      (1 (seq-elt expressions 0))
      (_ (eglot-jdtls--select
          expressions
          (format "extract to %s:"
                  (pcase cmd
                    ("extractMethod" "method")
                    ("extractVariable" "variable")
                    ("extractVariableAllOccurrence" "variable")
                    ("extractConstant" "constant")
                    ("extractField" "field")
                    (_ "")))
          (lambda (expression)
            (plist-get expression :name)))))))

(defun eglot-jdtls--extract-interface (server arguments)
  "Extract an interface from a class by selecting members and destination.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (pcase-let*
      ((`[,cmd ,params] arguments)
       (check-resp (jsonrpc-request
                    server :java/checkExtractInterfaceStatus
                    params))
       ((map :members :subTypeName :destinationResponse) check-resp))
    (when-let* ((destinations (plist-get destinationResponse :destinations))
                (_ (or (and (vectorp members) (length> members 0))
                       (ignore (message "Cannot find available members to declare in the interface"))))
                (_ (or (and (vectorp destinations) (length> destinations 0))
                       (ignore (message "Cannot find available Java packages to extract interface to"))))
                (member-ids (eglot-jdtls--select
                             members
                             "Select members: "
                             (lambda (m)
                               (pcase-let*
                                   (((map :name :typeName :parameters) m)
                                    (params-str (mapconcat #'identity parameters ", ")))
                                 (format "%s(%s) %s" name params-str typeName)))
                             t
                             (lambda (m)
                               (plist-get m :handleIdentifier))))
                (interface-name (read-string "Specify interface name: " subTypeName))
                (_ (and interface-name (not (string-empty-p interface-name))))
                (destination (eglot-jdtls--select
                              destinations
                              (format "Specify package: ")
                              (lambda (item)
                                (format "%s - %s"
                                        (plist-get item :displayName)
                                        (plist-get item :path)))))
                (cmd-args (vector member-ids interface-name destination))
                (result (jsonrpc-request
                         server :java/getRefactorEdit
                         (list :command cmd
                               :commandArguments (vconcat cmd-args)
                               :context params
                               :options (eglot-jdtls--format-options)))))
      (eglot-jdtls--refactor-edit server result)
      (pcase-let* (((map :edit) result)
                   ((map :documentChanges) edit))
        (dolist (doc-change (append documentChanges nil))
          (when-let* ((kind (plist-get doc-change :kind))
                      (_ (equal kind "create"))
                      (uri (plist-get doc-change :uri))
                      (file (eglot-uri-to-path uri))
                      (_ (file-exists-p file)))
            (find-file-other-window file)))))))

(defun eglot-jdtls--apply-refactoring-command (server arguments)
  "Apply Java refactoring command by dispatching to appropriate handler.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (let* ((cmd (seq-elt arguments 0))
         (params (seq-elt arguments 1)))
    (cond
     ((equal cmd "moveFile") (eglot-jdtls--move-file server arguments))
     ((equal cmd "moveInstanceMethod") (eglot-jdtls--instant-method server arguments))
     ((equal cmd "moveStaticMember") (eglot-jdtls--move-static-member server arguments))
     ((equal cmd "moveType") (eglot-jdtls--move-type server arguments))
     ((equal cmd "changeSignature") (eglot-jdtls--change-signature server arguments))
     ((equal cmd "extractInterface") (eglot-jdtls--extract-interface server arguments))
     ((member cmd '("extractVariable"
                    "assignVariable"
                    "extractVariableAllOccurrence"
                    "extractConstant"
                    "extractMethod"
                    "extractField"
                    "assignField"
                    "convertVariableToField"
                    "invertVariable"
                    "introduceParameter"
                    "convertAnonymousClassToNestedCommand"))
      (cl-block nil
        (let* ((cmd-args (cond
                          ((equal cmd "extractField")
                           (cond
                            ((use-region-p)
                             (unless (length> arguments 2)
                               (cl-return))
                             (let* ((cmd-info (seq-elt arguments 2))
                                    (scopes (plist-get cmd-info :initializedScopes))
                                    (scope (when scopes (eglot-jdtls--resolve-scopes scopes))))
                               (cond
                                ((not scopes) nil)
                                ((and scopes scope) (vector scope))
                                (t (cl-return)))))
                            (t
                             (let* ((expr (eglot-jdtls--get-expression cmd params server))
                                    (scopes (plist-get expr :params))
                                    (scope (when scopes (eglot-jdtls--resolve-scopes scopes))))
                               (cond
                                ((and expr scopes scope)
                                 (vector scope expr))
                                ((and expr (not scopes))
                                 (vector expr))
                                (t (cl-return)))))))
                          ((equal cmd "convertVariableToField")
                           (unless (length> arguments 2)
                             (cl-return))
                           (let* ((cmd-info (seq-elt arguments 2))
                                  (scopes (plist-get cmd-info :initializedScopes))
                                  (scope (when scopes (eglot-jdtls--resolve-scopes scopes))))
                             (cond
                              ((not scopes) nil)
                              ((and scopes scope) (vector scope))
                              (t (cl-return)))))
                          ((member cmd '("extractMethod"
                                         "extractVariableAllOccurrence"
                                         "extractVariable"
                                         "extractConstant"))
                           (when-let* ((_ (not (use-region-p)))
                                       (expr (eglot-jdtls--get-expression cmd params server)))
                             (vector expr)))
                          (t nil)))
               (result (jsonrpc-request
                        server :java/getRefactorEdit
                        (list :command cmd
                              :commandArguments (vconcat cmd-args)
                              :context params
                              :options (eglot-jdtls--format-options)))))
          (eglot-jdtls--refactor-edit server result))))
     (t nil))))

(cl-defmethod eglot-handle-request
  ((_server eglot-jdtls-server)
   (_method (eql workspace/executeClientCommand))
   &key command arguments &allow-other-keys)
  "Handle workspace/executeClientCommand requests from JDT Language Server.

_SERVER is the JDT Language Server instance.
_METHOD is always `workspace/executeClientCommand' (via method specialization).
COMMAND is the client command name to execute.
ARGUMENTS is a keyword argument containing the command arguments."
  (pcase command
    ("java.action.organizeImports.chooseImports"
     (pcase-let*
         ((`[,documentUri ,selections _restoreExistingImports] arguments)
          (select-candidate-fn (lambda (selection)
                                 (pcase-let* (((map :candidates :range) selection))
                                   (eglot--goto range)
                                   (let* ((selected-item (eglot-jdtls--select
                                                          candidates
                                                          "Select class to import: "
                                                          (lambda (cand)
                                                            (plist-get cand :fullyQualifiedName)))))
                                     selected-item)))))
       (with-current-buffer (find-file (eglot-uri-to-path documentUri))
         (save-excursion
           (cl-map 'vector select-candidate-fn selections)))))
    ("_java.reloadBundles.command" [])
    (_ (message "Unknown client command: %s" command))))

(when (require 'eglot-codelens nil 'noerror)
  (cl-defmethod eglot-codelens-provide-codelens :around
    ((server eglot-jdtls-server) codelens uri)
    "Provide CodeLenses for SERVER by appending debug and test lenses
to CODELENS.

Ensures the server state is up to date.  Appends Run/Debug CodeLenses
from `eglot-jdtls-debugger--provide-codelens' if the debug bundle is
present, and test Run/Debug CodeLenses from
`eglot-jdtls-tester--provide-codelens' if the test bundle is present and
 the current file is on a test source path.
URI is the document URI to provide CodeLenses for."
    (unless (eglot-jdtls--bundles-loaded server)
      (eglot-jdtls--update-server-state server))
    (let* (debug-codelens test-codelens)
      (when (eglot-jdtls--bundles-contain-debug server)
        (setq debug-codelens (eglot-jdtls-debugger--provide-codelens uri)))
      (when-let* ((file buffer-file-name)
                  (_ (eglot-jdtls--bundles-contain-test server))
                  (test-paths (eglot-jdtls--test-source-paths server))
                  (_ (eglot-jdtls-tester--on-test-path-p file test-paths)))
        (setq test-codelens (eglot-jdtls-tester--provide-codelens uri)))
      (vconcat codelens debug-codelens test-codelens))))

(cl-defmethod eglot-execute :around
  ((server eglot-jdtls-server) action)
  "Custom handler for performing JDT client commands.

SERVER is the JDT Language Server instance.
ACTION is a plist containing:
  - `command': The client command name to execute
  - `arguments': Command arguments

Disables vertico-sort-function to preserve order for selection prompts."
  (let ((command (plist-get action :command))
        (arguments (plist-get action :arguments))
        (vertico-sort-function nil))
    (pcase command
      ("java.apply.workspaceEdit" (eglot-jdtls--apply-workspaceEdit arguments))
      ("java.action.overrideMethodsPrompt" (eglot-jdtls--override-methods-prompt server arguments))
      ("java.action.generateToStringPrompt" (eglot-jdtls--generate-toString-prompt server arguments))
      ("java.action.hashCodeEqualsPrompt" (eglot-jdtls--hashCode-equals-prompt server arguments))
      ("java.action.generateAccessorsPrompt" (eglot-jdtls--generate-accessors-prompt server arguments))
      ("java.action.generateConstructorsPrompt" (eglot-jdtls--generate-constructors-prompt server arguments))
      ("java.action.generateDelegateMethodsPrompt" (eglot-jdtls--generate-delegate-methods-prompt-support server arguments))
      ("java.action.applyRefactoringCommand" (eglot-jdtls--apply-refactoring-command server arguments))
      ("java.action.rename" (eglot-jdtls--rename arguments))
      ("java.show.references" (eglot-jdtls--show-references command arguments))
      ("java.show.implementations" (eglot-jdtls--show-references command arguments))
      ;; vscode-java-debug extension
      ("java.debug.runCodeLens" (eglot-jdtls-debugger--run-codelens arguments nil))
      ("java.debug.debugCodeLens" (eglot-jdtls-debugger--run-codelens arguments t))
      ;; vscode-java-test extension
      ("_java.test.run" (eglot-jdtls-tester--run-test arguments nil))
      ("_java.test.debug" (eglot-jdtls-tester--run-test arguments t))
      ("_java.test.coverage" nil)
      (_ (cl-call-next-method)))))

;;;###autoload
(defun eglot-jdtls-organize-imports ()
  "Organize imports in the current Java buffer using Eglot LSP."
  (interactive)
  (jsonrpc-async-request
   (eglot--current-server-or-lose)
   :java/organizeImports
   `(:textDocument (:uri ,(eglot-path-to-uri (buffer-file-name) :truenamep t))
     :range (:start (:line 0 :character 0)
             :end (:line 0 :character 0))
     :context (:diagnostics []))
   :success-fn (lambda (result)
                 (eglot--apply-workspace-edit result this-command))))

;;;###autoload
(defun eglot-jdtls-clear-cache ()
  "Clear the JDT source file cache."
  (interactive)
  (when (and (file-directory-p eglot-jdtls-cache-dir)
             (yes-or-no-p (format "Delete cache directory %s? "
                                  eglot-jdtls-cache-dir)))
    (delete-directory eglot-jdtls-cache-dir t)
    (message "Cache cleared.")))


(provide 'eglot-jdtls)
;;; eglot-jdtls.el ends here
