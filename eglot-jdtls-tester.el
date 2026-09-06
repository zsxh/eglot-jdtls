;;; eglot-jdtls-tester.el --- Test utilities for eglot-jdtls -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Zsxh Chen

;; Author: Zsxh Chen <bnbvbchen@gmail.com>
;; Maintainer: Zsxh Chen <bnbvbchen@gmail.com>
;; URL: https://github.com/zsxh/eglot-jdtls
;; Version: 0.2.0
;; Keywords: eglot, tools, test

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
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Test utilities for eglot-jdtls.
;;
;; [Test Runner for Java extension](https://code.visualstudio.com/docs/java/java-testing)
;;

;;; Code:

(declare-function eglot-jdtls--test-items-cache "eglot-jdtls" (server))

(require 'cl-lib)
(require 'compat)
(require 'eglot)
(require 'jsonrpc)
(require 'dape)

(require 'eglot-jdtls-debugger)

(defconst eglot-jdtls-tester--test-level-alist
  '((root . 0)
    (workspace . 1)
    (workspace-folder . 2)
    (project . 3)
    (package . 4)
    (class . 5)
    (method . 6)
    (invocation . 7)))

(defconst eglot-jdtls-tester--test-kind-alist
  '((JUnit5 . 0)
    (JUnit . 1)
    (TestNG . 2)
    (JUnit6 . 3)
    (None . 100)))

(defconst eglot-jdtls-tester--junit-message-id-alist
  '((test-tree . "%TSTTREE")
    (test-start . "%TESTS")
    (test-end . "%TESTE")
    (test-failed . "%FAILED")
    (test-error . "%ERROR")
    (expect-start . "%EXPECTS")
    (expect-end . "%EXPECTE")
    (actual-start . "%ACTUALS")
    (actual-end . "%ACTUALE")
    (trace-start . "%TRACES")
    (trace-end . "%TRACEE")
    (ignore-test-prefix . "@Ignore: ")
    (assumption-failed-prefix . "@AssumptionFailure: "))
  "Alist mapping JUnit message types to their protocol tags.

Each element is a cons cell (TYPE . TAG), where TYPE is a symbol
representing the message intent and TAG is the string prefix used in
the JUnit RemoteTestRunner wire protocol.

The `test-tree' tag (%TSTTREE) is followed by comma-separated fields:
  TEST-ID, TEST-NAME, IS-SUITE, TEST-COUNT, IS-DYNAMIC,
  PARENT-ID, DISPLAY-NAME, PARAM-TYPES, UNIQUE-ID.

- IS-SUITE: \"true\" or \"false\".
- IS-DYNAMIC: \"true\" or \"false\".
- PARENT-ID: Unique ID of the parent for dynamic tests, else \"-1\".
- DISPLAY-NAME: The display name of the test.
- PARAM-TYPES: Comma-separated method parameter types, or empty.
- UNIQUE-ID: Unique ID from JUnit launcher, or empty.")

(defconst eglot-jdtls-tester-result-buffer "*eglot-jdtls-test-result*"
  "Buffer name for displaying test results.")

(defvar eglot-jdtls-tester--runner-cache nil
  "Cons cell (TEST-KIND . PROCESS) caching the current test runner.")


(defun eglot-jdtls-tester--test-source-paths (uri)
  "Resolve test source paths for the file at URI via jdtls.

Returns a list of directory paths that contain test sources."
  (when-let* ((server (eglot-current-server)))
    (eglot-execute server `(:command "vscode.java.test.get.testpath"
                            :arguments [[,uri]]))))

(defun eglot-jdtls-tester--test-type-and-methods (uri &optional server)
  "Find test types and methods in the file at URI via jdtls.

SERVER defaults to the current eglot server.  Returns a vector of
test-item plists, each containing `:id', `:label', `:range',
`:children', `:testKind', and `:testLevel' properties."
  (when-let* ((server (or server (eglot-current-server))))
    (eglot-execute server `(:command "vscode.java.test.findTestTypesAndMethods"
                            :arguments [,uri ,nil]))))

(defun eglot-jdtls-tester--get-launch-args (test-item test-names unique-id
                                                    &optional server)
  "Get launch arguments for running TEST-ITEM via jdtls.

TEST-NAMES is a vector of fully qualified test names to run.
UNIQUE-ID is the unique test identifier, or nil.  SERVER defaults
to the current eglot server.  Returns the `:body' plist from the
`vscode.java.test.junit.argument' command response, containing
`:mainClass', `:projectName', `:classpath', `:modulepath',
`:vmArguments', and `:programArguments'."
  (when-let* ((server (or server (eglot-current-server))))
    (pcase-let*
        (((map :projectName :testLevel :testKind) test-item)
         (params (list :projectName projectName
                       :testLevel testLevel
                       :testKind testKind
                       :testNames test-names
                       :uniqueId unique-id))
         (params-str (json-encode params))
         (res (eglot-execute server
                             `(:command "vscode.java.test.junit.argument"
                               :arguments [,params-str]))))
      (plist-get res :body))))


(defun eglot-jdtls-tester--test-level-value (level)
  "Get numeric value for LEVEL symbol."
  (alist-get level eglot-jdtls-tester--test-level-alist))

(defun eglot-jdtls-tester--test-level-name (value)
  "Get symbol name for numeric VALUE."
  (car (rassoc value eglot-jdtls-tester--test-level-alist)))

(defun eglot-jdtls-tester--test-kind-value (kind)
  "Get numeric value for KIND symbol."
  (alist-get kind eglot-jdtls-tester--test-kind-alist))

(defun eglot-jdtls-tester--test-kind-name (value)
  "Get symbol name for numeric VALUE."
  (car (rassoc value eglot-jdtls-tester--test-kind-alist)))

(defun eglot-jdtls-tester--on-test-path-p (file test-paths)
  "Return non-nil if FILE is inside one of TEST-PATHS directories."
  (when (and file test-paths (length> test-paths 0))
    (cl-some
     (lambda (path) (file-in-directory-p file path))
     test-paths)))

(defun eglot-jdtls-tester--test-name (test-item)
  "Return the display name for TEST-ITEM.

For class-level or TestNG tests, returns the fully qualified name.
Otherwise returns the JDT handler identifier."
  (pcase-let*
      (((map :testLevel :testKind :fullName :jdtHandler) test-item))
    (if (or (= testLevel (eglot-jdtls-tester--test-level-value 'class))
            (= testKind (eglot-jdtls-tester--test-kind-value 'TestNG)))
        fullName
      jdtHandler)))

(defun eglot-jdtls-tester--current-test-item-cache (&optional server uri)
  "Return the hash table cache for test items at URI.

SERVER defaults to the current eglot server.  URI defaults to the
current buffer's document URI.  Creates the cache entry if it does
not yet exist."
  (let* ((server (or server (eglot-current-server)))
         (test-items-cache (eglot-jdtls--test-items-cache server))
         (uri (or uri (plist-get (eglot--TextDocumentIdentifier) :uri)))
         (cache (gethash uri test-items-cache)))
    (unless cache
      (setq cache (make-hash-table :test 'equal))
      (puthash uri cache test-items-cache))
    cache))


(defvar-local eglot-jdtls-tester--junit-test-kind nil
  "The JUnit test kind symbol for the current result buffer.")

(defvar-local eglot-jdtls-tester--junit-test-output-mapping nil
  "Hash table mapping test IDs to test item.")

;; TODO: Analyze junit test result
;; - visualize test cases fail or pass
;; - create dynamic tests
;;
;; link: https://github.com/microsoft/vscode-java-test/blob/main/src/runners/junitRunner/JUnitRunnerResultAnalyzer.ts
(defun eglot-jdtls-tester--junit-result-analyzer ()
  "Analyze JUnit test results."
  (let ((buf (get-buffer-create eglot-jdtls-tester-result-buffer))
        (_output-map eglot-jdtls-tester--junit-test-output-mapping))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let ((lines (split-string (buffer-string) "\r?\n" nil))
              (case-fold-search nil)
              (_reg-exp (rx (one-or-more
                            (or (not (any "\\,"))
                                (seq "\\" (opt ",")))))))
          (dolist (_line lines)
            ;; TODO: unincompleted
            ))))))

(defun eglot-jdtls-tester--junit-filter (_proc string)
  "Process filter for the JUnit test runner.

Appends STRING output from PROC to the test result buffer."
  (let ((buf (get-buffer-create eglot-jdtls-tester-result-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (insert string)))))

(defun eglot-jdtls-tester--junit-sentinel (_proc event)
  "Process sentinel for the JUnit test runner.

PROC and EVENT are the standard sentinel arguments.
When the runner server opens, initializes and displays the test
result buffer.  When the connection is closed, triggers the JUnit
result analyzer to process the output."
  (let ((event (string-trim-right event)))
    (cond
     ((string-match-p "open" event)
      (let ((buf (get-buffer-create eglot-jdtls-tester-result-buffer))
            (test-kind (car eglot-jdtls-tester--runner-cache)))
        (with-current-buffer buf
          (dape-shell-mode)
          (setq buffer-read-only t)
          (setq eglot-jdtls-tester--junit-test-kind test-kind)
          (let ((inhibit-read-only t))
            (erase-buffer)))
        (dape--display-buffer buf)))
     ((string-match-p "connection broken by remote peer" event)
      (eglot-jdtls-tester--junit-result-analyzer))
     (t nil))))

(defun eglot-jdtls-tester--testng-filter (_proc string)
  "Process filter for the TestNG test runner.

Appends STRING output from PROC to the test result buffer."
  (let ((buf (get-buffer-create eglot-jdtls-tester-result-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (insert string)))))

(defun eglot-jdtls-tester--testng-sentinel (_proc event)
  "Process sentinel for the TestNG test runner.

PROC and EVENT are the standard sentinel arguments.
When the runner server opens, initializes and displays the test
result buffer.  When the connection is closed, the TestNG result
is currently not analyzed."
  (let ((event (string-trim-right event)))
    (cond
     ((string-match-p "open" event)
      (let ((buf (get-buffer-create eglot-jdtls-tester-result-buffer)))
        (with-current-buffer buf
          (dape-shell-mode)
          (setq buffer-read-only t)
          (let ((inhibit-read-only t))
            (erase-buffer)))
        (dape--display-buffer buf)))
     ((string-match-p "connection broken by remote peer" event)
      ;; TODO: analyze testng test buffer
      )
     (t nil))))

(defun eglot-jdtls-tester--create-server (filter sentinel &optional port)
  "Create a local TCP server process for the test runner.

FILTER and SENTINEL are the process filter and sentinel functions.
PORT is the port number, or nil to let the OS assign one.
Returns the newly created network process."
  (let ((common-args (list :name "eglot-jdtls-test-runner"
                           :server t
                           :host 'local
                           :filter filter
                           :sentinel sentinel
                           :noquery t)))
    (condition-case nil
        (apply #'make-network-process :service (or port 0) common-args)
      (error
       (apply #'make-network-process :service 0 common-args)))))

(defun eglot-jdtls-tester--runner (test-kind)
  "Create a new test runner process for TEST-KIND."
  (cond
   ((memq test-kind '(JUnit JUnit5 JUnit6))
    (eglot-jdtls-tester--create-server #'eglot-jdtls-tester--junit-filter
                                       #'eglot-jdtls-tester--junit-sentinel))
   ((eq test-kind 'TestNG)
    (eglot-jdtls-tester--create-server #'eglot-jdtls-tester--testng-filter
                                       #'eglot-jdtls-tester--testng-sentinel))
   (t (user-error "Failed to get suitable runner for the test kind: %s"
                  test-kind))))

(defun eglot-jdtls-tester--cached-runner (test-kind)
  "Return a cached test runner for TEST-KIND, creating one if necessary.
TEST-KIND is a symbol value as defined in
`eglot-jdtls-tester--test-kind-alist'."
  (let ((cache eglot-jdtls-tester--runner-cache))
    (if (and cache (eq test-kind (car cache))
             (process-live-p (cdr cache)))
        (cdr cache)
      (when cache
        (delete-process (cdr cache)))
      (let ((runner (eglot-jdtls-tester--runner test-kind)))
        (setq eglot-jdtls-tester--runner-cache (cons test-kind runner))
        runner))))

(defun eglot-jdtls-tester--stop-runner (&rest _)
  "Stop and clear the cached test runner process.

Intended as advice for `dape-quit' and `dape-disconnect-quit'."
  (let ((cache eglot-jdtls-tester--runner-cache))
    (when cache
      (let ((runner (cdr cache)))
        (when (and runner (process-live-p runner))
          (delete-process runner)))
      (setq eglot-jdtls-tester--runner-cache nil))))

(defun eglot-jdtls-tester--ensure-runner ()
  "Ensure test runner is available for the current dape debug session.
If a test runner is needed but not yet running, create one and update
the dape configuration with the runner's port.  On error, kill the
newly created runner to prevent resource leaks."
  (when-let*
      ((dape-active-p dape-active-mode)
       (conn (eglot-jdtls-debugger--connection))
       (dape-conf (dape--config conn))
       (java-type-p (string= "java" (plist-get dape-conf :type)))
       (launch-request-p (string= "launch" (plist-get dape-conf :request)))
       (test-kind
        (pcase (plist-get dape-conf :mainClass)
          ("com.microsoft.java.test.runner.Launcher" 'TestNG)
          ("org.eclipse.jdt.internal.junit.runner.RemoteTestRunner" 'JUnit)
          (_ nil)))
       (no-runner-p (not (and eglot-jdtls-tester--runner-cache
                               (process-live-p
                                (cdr eglot-jdtls-tester--runner-cache)))))
       (args (plist-get dape-conf :args)))
    (let (test-runner)
      (condition-case err
          (progn
            (setq test-runner (eglot-jdtls-tester--cached-runner test-kind))
            (let* ((port (number-to-string
                          (process-contact test-runner :service)))
                   (new-args
                    (if (eq test-kind 'TestNG)
                        (replace-regexp-in-string
                         "^[0-9]+\\( testng\\)" (concat port "\\1") args)
                      (replace-regexp-in-string
                       "\\(-port \\)[0-9]+" (concat "\\1" port) args))))
              (setq dape-conf (plist-put dape-conf :args new-args))
              (setf (dape--config conn) dape-conf)))
        (error
         (when (and test-runner (process-live-p test-runner))
           (delete-process test-runner)
           (setq eglot-jdtls-tester--runner-cache nil))
         (user-error "[eglot-jdtls]: Cannot launch test runner server - %s"
                     (error-message-string err)))))))

(add-hook 'dape-active-mode-hook #'eglot-jdtls-tester--ensure-runner)
(advice-add 'dape-quit :after #'eglot-jdtls-tester--stop-runner)
(advice-add 'dape-disconnect-quit :after #'eglot-jdtls-tester--stop-runner)

(defvar eglot-jdtls-config)
(defun eglot-jdtls-tester--find-bundle (name)
  "Find a bundle JAR file ending with NAME from jdtls init options.

Returns the truename of the matching JAR, or nil if not found."
  (when-let* ((init-options (plist-get eglot-jdtls-config :init-options))
              (bundles (plist-get init-options :bundles))
              (runner-jar (cl-find-if
                           (lambda (jar)
                             (string-suffix-p name jar))
                           bundles)))
    (file-truename runner-jar)))

(defun eglot-jdtls-tester--testng-collect-method-ids (test-items)
  "Collect all method-level test-item IDs from TEST-ITEMS.
TEST-ITEMS is a list of test-item plists.  Returns a list of IDs for
test-items with :testLevel equal to `method' (value 6), including
nested children."
  (let ((method-level (eglot-jdtls-tester--test-level-value 'method))
        (result '())
        (queue (append test-items '()))
        (cache (eglot-jdtls-tester--current-test-item-cache)))
    (while queue
      (let* ((item (car queue))
             (test-level (plist-get item :testLevel)))
        (setq queue (cdr queue))
        (if (eq test-level method-level)
            (when-let* ((id (plist-get item :id))
                        (at-pos (string-search "@" id))
                        (method-id (substring id (1+ at-pos)))
                        (method-id (format "\"%s\"" method-id)))
              (push method-id result))
          (when-let*
              ((children (plist-get item :children))
               (child-items (mapcar
                             (lambda (child-id) (gethash child-id cache))
                             children)))
            (setq queue (append queue child-items))))))
    result))

(defun eglot-jdtls-tester--resolve-test-args (test-item
                                              launch-args debug-p port)
  "Resolve test configuration for launching via dape.

TEST-ITEM is the test-item plist from the test cache.
LAUNCH-ARGS is the launch arguments plist from jdtls containing
`:mainClass', `:projectName', `:classpath', `:modulepath',
`:vmArguments', and `:programArguments'.
DEBUG-P controls whether to launch in debug mode.
PORT is the test runner server port number.
Returns a plist suitable for `eglot-jdtls-debugger--debug'."
  (pcase-let*
      (((map :mainClass :projectName :classpath :modulepath :vmArguments
             :programArguments) launch-args)
       ((map
         (:id _)
         :label :uri
         (:children _)
         (:testKind test-kind)
         (:testLevel _)) test-item)
       (test-kind (eglot-jdtls-tester--test-kind-name test-kind)))
    (let (main-class class-path args)
      (cond
       ;; TestNG
       ((eq test-kind 'TestNG)
        (let* ((runner-jar-name
                "com.microsoft.java.test.runner-jar-with-dependencies.jar")
               (runner-jar (eglot-jdtls-tester--find-bundle runner-jar-name))
               (test-method-ids (eglot-jdtls-tester--testng-collect-method-ids
                                 (list test-item))))
          (unless runner-jar
            (user-error "[eglot-jdtls]: Can not find %s in bundles"
                        runner-jar-name))
          (setq main-class "com.microsoft.java.test.runner.Launcher"
                class-path (vconcat classpath (vector runner-jar))
                args (vconcat
                      (vector (number-to-string port) "testng")
                      test-method-ids))))
       ;; JUnit
       (t
        (let* ((port (number-to-string port))
               (p-args programArguments)
               (port-index (cl-position "-port" p-args :test #'string=)))
          (if (and port-index (< (1+ port-index) (length p-args)))
              (aset p-args (1+ port-index) port)
            (setq p-args (vconcat p-args `["-port" ,port])))
          (setq main-class mainClass
                class-path classpath
                args p-args))))
      (list :name (format "Java Test - %s" label)
            :uri uri
            :main-class main-class
            :project-name projectName
            :module-paths modulepath
            :class-paths class-path
            :args args
            :vm-args vmArguments
            :debug-p debug-p
            :test-p t))))

;; https://github.com/microsoft/vscode-java-test/blob/main/src/utils/launchUtils.ts
;; https://github.com/microsoft/vscode-java-test/blob/main/src/controller/testController.ts
(defun eglot-jdtls-tester--run-test (args debug-p)
  "Run or debug a test identified by ARGS.

ARGS is a vector whose first element is the test-item ID.
When DEBUG-P is non-nil, launch in debug mode; otherwise run
without debugging.  A local TCP server is created to listen for
test result output from the JUnit/TestNG runner process.  Resolves
the test item from the cache, obtains launch arguments from jdtls,
builds the workspace, and delegates to `eglot-jdtls-debugger--debug'."
  (when-let* ((server (eglot-current-server))
              (id (aref args 0))
              (test-item-cache
               (eglot-jdtls-tester--current-test-item-cache server))
              (test-item (gethash id test-item-cache))
              (test-names (vector (eglot-jdtls-tester--test-name test-item)))
              (test-kind (eglot-jdtls-tester--test-kind-name
                          (plist-get test-item :testKind))))
    (let (test-runner-server)
      (condition-case err
          (progn
            (setq test-runner-server (eglot-jdtls-tester--cached-runner test-kind))
            (let* ((port (process-contact test-runner-server :service))
                   (unique-id nil)
                   (launch-args (eglot-jdtls-tester--get-launch-args
                                 test-item test-names unique-id))
                   (test-conf (eglot-jdtls-tester--resolve-test-args
                               test-item launch-args debug-p port))
                   (build-succeed-p (eglot-jdtls-debugger--build-workspace
                                     (plist-get test-conf :main-class)
                                     (plist-get test-conf :project-name)
                                     nil server)))
              (unless build-succeed-p
                (user-error "Failed to build workspace"))
              (eglot-jdtls-debugger--debug test-conf server)))
        (error
         (when (and test-runner-server
                    (process-live-p test-runner-server))
           (delete-process test-runner-server)
           (setq eglot-jdtls-tester--runner-cache nil))
         (user-error "[eglot-jdtls]: Cannot run test - %s"
                     (error-message-string err)))))))

(defun eglot-jdtls-tester--provide-codelens (uri)
  "Provide Run and Debug CodeLenses for test methods in the file at URI.

Discovers all test types and methods via jdtls, caches them, and
returns a list of CodeLens objects each with Run and Debug actions.
Traverses nested test items to include all levels."
  (when-let* ((server (eglot-current-server))
              (test-items (eglot-jdtls-tester--test-type-and-methods uri server)))
    (let ((cache (eglot-jdtls-tester--current-test-item-cache server uri))
          (queue (append test-items '()))
          codelens)
      (clrhash cache)
      (while queue
        (cl-loop for test-item in queue
                 for children = (plist-get test-item :children)
                 for id = (plist-get test-item :id)
                 for range = (plist-get test-item :range)
                 for child-ids = (mapcar (lambda (c) (plist-get c :id)) children)
                 do (puthash id (plist-put test-item :children child-ids) cache)
                 nconc (append children '()) into next-items
                 nconc `((:range ,range
                          :command (:title "Run"
                                    :command "_java.test.run"
                                    :arguments [,id]))
                         (:range ,range
                          :command (:title "Debug"
                                    :command "_java.test.debug"
                                    :arguments [,id]))
                         ;; TODO: Test Coverage Support
                         ;; (:range ,range
                         ;;  :command (:title "Coverage"
                         ;;            :command "_java.test.coverage"
                         ;;            :arguments [,id]))
                         ) into lenses
                 finally (setq codelens (nconc codelens lenses)
                               queue next-items)))
      codelens)))


(provide 'eglot-jdtls-tester)
;;; eglot-jdtls-tester.el ends here
