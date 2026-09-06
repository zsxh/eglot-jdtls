;;; eglot-jdtls-debugger.el --- Debug utilities for eglot-jdtls -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Zsxh Chen

;; Author: Zsxh Chen <bnbvbchen@gmail.com>
;; Maintainer: Zsxh Chen <bnbvbchen@gmail.com>
;; URL: https://github.com/zsxh/eglot-jdtls
;; Version: 0.2.0
;; Keywords: eglot, tools, debug

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either major-version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Debug utilities for eglot-jdtls.
;;
;; [Java Debug Server](https://github.com/Microsoft/java-debug)
;; [Java Debugger for Visual Studio Code](https://github.com/microsoft/vscode-java-debug)
;; [Running and debugging Java](https://code.visualstudio.com/docs/java/java-debugging)

;;; Code:

(require 'cl-lib)
(require 'compat)
(require 'eglot)
(require 'jsonrpc)
(require 'dape)


(defgroup eglot-jdtls-debugger nil
  "Debug utilities for running and debugging Java via jdtls."
  :group 'eglot
  :prefix "eglot-jdtls-debugger-")

(defcustom eglot-jdtls-debugger-args '()
  "Arguments passed to the main class when running or debugging.
TESTNG args issue: https://github.com/microsoft/vscode-java-test/issues/1297"
  :type '(repeat string)
  :group 'eglot-jdtls-debugger)

(defcustom eglot-jdtls-debugger-vm-args '()
  "JVM arguments passed when running or debugging."
  :type '(repeat string)
  :group 'eglot-jdtls-debugger)

(defcustom eglot-jdtls-debugger-env '()
  "Environment variables passed when running or debugging."
  :type '(plist :key-type symbol
                :value-type (choice string number))
  :group 'eglot-jdtls-debugger)


(defun eglot-jdtls-debugger--autobuild-p ()
  "Return non-nil if Java autobuild is enabled in workspace configuration."
  (when-let*
      ((workspace-conf (plist-get eglot-workspace-configuration :java))
       (autobuild (plist-get workspace-conf :autobuild))
       (autobuild-enabled (plist-get autobuild :enabled)))
    (equal autobuild-enabled t)))

(defun eglot-jdtls-debugger--connection ()
  "Return the active dape debug connection, or nil if there is none.
Prefers the selected connection and falls back to the most recently
created session with an active thread; see `dape--live-connection'."
  (dape--live-connection 'last t))

;;;###autoload
(defun eglot-jdtls-debugger-hot-code-replace ()
  "Reload changed classes in a running Java debug session.

If the current session is in debug mode, trigger a hot code replace
via the Debug Adapter Protocol.  If autobuild is disabled, build the
workspace first.  If the session is in run mode (no debug), prompt to
restart with debug enabled."
  (interactive)
  (when dape-active-mode
    (let* ((dape-conn (eglot-jdtls-debugger--connection))
           (dape-conf (dape--config dape-conn))
           (debug-p (equal (dape-config-get dape-conf :noDebug) :json-false)))
      (if debug-p
          (progn
            (unless (eglot-jdtls-debugger--autobuild-p)
              (eglot-jdtls-debugger--build-workspace nil nil nil))
            (dape-request
             dape-conn "redefineClasses" eglot-{}
             (lambda (body errMsg)
               (if errMsg
                   (message (format "[eglot-jdtls]: %s" errMsg))
                 (let* ((changedClasses (plist-get body :changedClasses))
                        (changed-len (length changedClasses)))
                   (pcase changed-len
                     (0 (message "Cannot find any changed classes for hot replace!"))
                     (1 (message "1 changed class is reloaded"))
                     (_ (message (format "%d changed classes are reloaded" changed-len)))))))))
        (when (y-or-n-p "Failed to apply the changes because hot code replace \
is not supported by run mode, would you like to restart the program?")
          (setq dape-conf (plist-put dape-conf :noDebug :json-false))
          (dape dape-conf))))))

(defvar dape-toolbar-buttons)
(defvar dape-toolbar-info-mode-map)

(when (require 'dape-toolbar nil t)
  (add-to-list 'dape-toolbar-buttons
               '(java-hot-code-replace
                 .
                 ("nf-cod-symbol_event"
                  eglot-jdtls-debugger-hot-code-replace
                  "Hot Code Replace"
                  nerd-icons-yellow
                  (lambda ()
                    (when-let* ((dape-conn (eglot-jdtls-debugger--connection))
                                (dape-conf (dape--config dape-conn))
                                (dape-type (dape-config-get dape-conf :type)))
                      (string-equal dape-type "java")))))
               t)
  (define-key dape-toolbar-info-mode-map "R"
    #'eglot-jdtls-debugger-hot-code-replace))

(defun eglot-jdtls-debugger--resolve-main-method (uri)
  "Resolve main methods in the file identified by URI via jdtls.

Returns a vector of main method descriptors, each containing
`:range', `:mainClass', and `:projectName' properties."
  (when-let* ((server (eglot-current-server)))
    (eglot-execute server `(:command "vscode.java.resolveMainMethod"
                            :arguments [,uri]))))

(defun eglot-jdtls-debugger--on-classpath-p (uri &optional server)
  "Return non-nil if the file at URI is on the project classpath.

Queries the jdtls SERVER (or the current server) via the
`vscode.java.isOnClasspath' command."
  (let* ((server (or server (eglot-current-server)))
         (res (eglot-execute server
                             `(:command "vscode.java.isOnClasspath"
                               :arguments [,uri]))))
    (cond
     ((eq res t) t)
     ((eq res :json-false) nil)
     (t nil))))

(defun eglot-jdtls-debugger--build-workspace
    (main-class project-name full-build-p &optional server)
  "Build the workspace for MAIN-CLASS in PROJECT-NAME via jdtls.

When FULL-BUILD-P is non-nil, perform a full build; otherwise
perform an incremental build.  SERVER defaults to the current
eglot server.  Return non-nil if the build succeeded."
  (let* ((server (or server (eglot-current-server)))
         (params `(:mainClass ,main-class
                   :projectName ,project-name
                   :isFullBuild ,(if full-build-p t :json-false)))
         (params-str (json-encode params))
         (build-status (eglot-execute server
                                      `(:command "vscode.java.buildWorkspace"
                                        :arguments [,params-str]))))
    ;; CompileWorkspaceStatus.SUCCEED = 1
    (= build-status 1)))

(defun eglot-jdtls-debugger--resolve-java-executable
    (main-class project-name &optional server)
  "Resolve the Java executable path for MAIN-CLASS in PROJECT-NAME.

Queries jdtls via the `vscode.java.resolveJavaExecutable' command.
SERVER defaults to the current eglot server."
  (let ((server (or server (eglot-current-server))))
    (eglot-execute server
                   `(:command "vscode.java.resolveJavaExecutable"
                     :arguments [,main-class ,project-name]))))

(defun eglot-jdtls-debugger--start-debug-session (&optional server)
  "Start a debug session on jdtls and return the debug port number.

SERVER defaults to the current eglot server.  Uses the
`vscode.java.startDebugSession' command to obtain a port for
the Java Debug Server."
  (let ((server (or server (eglot-current-server))))
    (eglot-execute server
                   '(:command "vscode.java.startDebugSession"
                     :arguments []))))

(defun eglot-jdtls-debugger--java-version (java-exec)
  "Return the major Java version number for JAVA-EXEC path.

Parses the `release' file in the Java home directory to extract
the major version.  Returns 0 if the version cannot be determined."
  (if-let* ((_ java-exec)
            (java-exec (expand-file-name java-exec))
            (bin-dir (file-name-directory (directory-file-name java-exec)))
            (java-home (file-name-directory (directory-file-name bin-dir)))
            (release-file (expand-file-name "release" java-home))
            (_ (file-readable-p release-file))
            (version-str (with-temp-buffer
                           (insert-file-contents release-file)
                           (goto-char (point-min))
                           (when (re-search-forward
                                  "^JAVA_VERSION=\"\\(.*\\)\"" nil t)
                             (match-string 1))))
            (version-str (if (string-prefix-p "1." version-str)
                             (substring version-str 2)
                           version-str))
            (major-version (when (string-match "^\\([0-9]+\\)" version-str)
                       (string-to-number (match-string 1 version-str)))))
      major-version
    0))

(defun eglot-jdtls-debugger--resolve-classpath
    (main-class project-name &optional scope server)
  "Resolve the classpath for MAIN-CLASS in PROJECT-NAME via jdtls.

SCOPE can be \"runtime\" or \"test\".  When nil, no scope filter is
applied.  SERVER defaults to the current eglot server.  Returns an
array whose first element is module paths and second is class paths."
  (let ((server (or server (eglot-current-server)))
        (args (if scope
                  (vector main-class project-name scope)
                (vector main-class project-name))))
    (eglot-execute server
                   `(:command "vscode.java.resolveClasspath"
                     :arguments ,args))))

;; NOTE: https://github.com/microsoft/vscode-java-debug/blob/23e5598341c819e2b41b8c126a130758e9d67e6f/src/configurationProvider.ts#L214
(defun eglot-jdtls-debugger--debug (conf &optional server)
  "Launch or run a Java program using dape according to CONF.

CONF is a plist with keys:
  `:uri'          - file URI of the main class
  `:name'         - display name for the debug session
  `:main-class'   - fully qualified main class name
  `:project-name' - project name
  `:module-paths' - list of module paths
  `:class-paths'  - list of class paths
  `:args'         - list of program arguments
  `:vm-args'      - list of JVM arguments
  `:debug-p'      - non-nil to enable debug mode
  `:test-p'       - non-nil for test execution

SERVER defaults to the current eglot server.  Resolves the Java
executable, starts a debug session, and invokes `dape'."
  (pcase-let*
      (((map (:uri _) :name :main-class :project-name
             :module-paths :class-paths :args
             :vm-args :debug-p :test-p) conf)
       (server (or server (eglot-current-server)))
       (cwd (dape-cwd))
       (java-exec (eglot-jdtls-debugger--resolve-java-executable
                   main-class project-name server))
       (runtime-version (eglot-jdtls-debugger--java-version java-exec))
       (args (append args eglot-jdtls-debugger-args))
       (vm-args (append vm-args
                        (when (>= runtime-version 14)
                          '("-XX:+ShowCodeDetailsInExceptionMessages"))
                        eglot-jdtls-debugger-vm-args))
       (env (and (plistp eglot-jdtls-debugger-env)
                 eglot-jdtls-debugger-env))
       ;; Always give a shorten approach here to save my mantain energy,
       ;; do not bother to caculate cli length.
       (shorten-approach (if (<= runtime-version 8)
                             "jarmanifest"
                           "argfile"))
       (port (eglot-jdtls-debugger--start-debug-session server))
       (console-conf (if test-p
                         '(:console "internalConsole")
                       '(:console "integratedTerminal"
                         :internalConsoleOptions "neverOpen")))
       (dape-config (list 'modes '(java-ts-mode java-mode)
                          'host "localhost"
                          'port port
                          :name name
                          :type "java"
                          :request "launch"
                          :cwd cwd
                          :mainClass main-class
                          :projectName project-name
                          :modulePaths module-paths
                          :classPaths class-paths
                          :javaExec java-exec
                          :env (or env (make-hash-table :size 0))
                          :args (string-join args " ")
                          :vmArgs (string-join vm-args " ")
                          :shortenCommandLine shorten-approach
                          :noDebug (if debug-p :json-false t))))
    (setq dape-config (append dape-config console-conf))
    (dape dape-config)))

(defun eglot-jdtls-debugger--run-codelens (args debug-p)
  "Handle a Run or Debug CodeLens action.

ARGS is a vector of [MAIN-CLASS PROJECT-NAME URI].
When DEBUG-P is non-nil, launch in debug mode; otherwise run without
debugging.  Validates the classpath, builds the workspace, resolves
the classpath, and delegates to `eglot-jdtls-debugger--debug'."
  (pcase-let* ((`[,main-class ,project-name ,uri] args))
    (when-let*
        ((server (eglot-current-server))
         (on-classpath-p (eglot-jdtls-debugger--on-classpath-p uri server))
         (build-succeed-p (eglot-jdtls-debugger--build-workspace
                           main-class project-name nil server))
         (paths (eglot-jdtls-debugger--resolve-classpath
                 main-class project-name nil server))
         (conf (list :name main-class
                     :uri uri
                     :main-class main-class
                     :project-name project-name
                     :debug-p debug-p
                     :module-paths (aref paths 0)
                     :class-paths (aref paths 1)
                     :args '())))
      (eglot-jdtls-debugger--debug conf server))))

(defun eglot-jdtls-debugger--provide-codelens (uri)
  "Provide Run and Debug CodeLenses for the file at URI.

Returns a list of CodeLens objects for each main method found in
the file, each containing both a Run and a Debug action."
  (when-let* ((main-methods (eglot-jdtls-debugger--resolve-main-method uri)))
    (cl-loop for method across main-methods
             for range = (plist-get method :range)
             for main-class = (plist-get method :mainClass)
             for project-name = (plist-get method :projectName)
             nconc
             `((:range ,range
                :command (:title "Run"
                          :command "java.debug.runCodeLens"
                          :arguments [,main-class ,project-name ,uri]))
               (:range ,range
                :command (:title "Debug"
                          :command "java.debug.debugCodeLens"
                          :arguments [,main-class ,project-name ,uri]))))))


(provide 'eglot-jdtls-debugger)
;;; eglot-jdtls-debugger.el ends here
