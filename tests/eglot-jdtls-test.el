;;; eglot-jdtls-test.el --- Tests for eglot-jdtls -*- lexical-binding: t; -*-

;; Copyright (C) 2026  zsxh

;; Author: zsxh <bnbvbchen@gmail.com>
;; Maintainer: zsxh <bnbvbchen@gmail.com>
;; URL: https://github.com/zsxh/eglot-jdtls
;; Version: 0.0.1
;; Package-Requires: ((emacs "30.1"))

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

;; Tests for eglot-jdtls.el

;;; Code:

(require 'ert)
(require 'eglot-jdtls)

;;; Tests for eglot-jdtls-cmd

(ert-deftest eglot-jdtls-cmd ()
  "Test eglot-jdtls-cmd with various configurations."
  (let* ((custom-cmd-fn (lambda () '("/opt/jdtls" "--debug")))
         (test-cases
          `(;; (name config exec-find-result expected-result)
            ("default config"
             nil
             "/usr/bin/jdtls"
             ("/usr/bin/jdtls"))
            ("custom list config"
             (:cmd ("/custom/path/jdtls" "--data=/tmp"))
             "/custom/path/jdtls"
             ("/custom/path/jdtls" . ("--data=/tmp")))
            ("custom function config"
             (:cmd ,custom-cmd-fn)
             t
             ("/opt/jdtls" "--debug"))
            ("preserves all args"
             (:cmd ("/usr/bin/jdtls"
                    "-data" "/workspace"
                    "--jvm-arg=-Xmx1g"
                    "--jvm-arg=-javaagent:/path/to/lombok.jar"))
             "/usr/bin/jdtls"
             ("/usr/bin/jdtls" . ("-data" "/workspace"
                                  "--jvm-arg=-Xmx1g"
                                  "--jvm-arg=-javaagent:/path/to/lombok.jar")))))
         (error-test-cases
          '(;; (name config)
            ("executable not found"
             (:cmd ("nonexistent-jdtls")))
            ("invalid config type"
             (:cmd "invalid-string-type")))))

    ;; Test normal cases
    (dolist (test-case test-cases)
      (pcase-let* ((`(,name ,config ,exec-find-result ,expected-result) test-case))
        (let ((eglot-jdtls-config config))
          (cl-letf (((symbol-function 'executable-find) (lambda (_prog) exec-find-result)))
            (should (equal (eglot-jdtls-cmd nil) expected-result))
            (when (fboundp 'custom-cmd-fn)
              (fmakunbound 'custom-cmd-fn))))))

    ;; Test error cases
    (dolist (test-case error-test-cases)
      (pcase-let* ((`(,name ,config) test-case))
        (let ((eglot-jdtls-config config))
          (cl-letf (((symbol-function 'executable-find)
                     (lambda (_prog) nil)))
            (should-error (eglot-jdtls-cmd nil)
                          :type 'user-error)))))))

;;; Tests for eglot-jdtls--plist-merge

(ert-deftest eglot-jdtls--plist-merge ()
  "Test eglot-jdtls--plist-merge with various scenarios."
  (let ((test-cases
         '(;; (name input-plists expected-result)
           ("basic merge"
            ((:a 1 :b 2))
            (:a 1 :b 2))
           ("override - later overrides earlier"
            ((:a 1 :b 2) (:b 3 :c 4))
            (:a 1 :b 3 :c 4))
           ("merge with empty plist 1"
            (nil (:a 1))
            (:a 1))
           ("merge with empty plist 2"
            ((:a 1) nil)
            (:a 1))
           ("merge multiple plists"
            ((:a 1) (:b 2) (:c 3) (:b 4))
            (:a 1 :b 4 :c 3)))))

    (dolist (test-case test-cases)
      (pcase-let* ((`(,name ,input-plists ,expected-result) test-case))
        (let ((result (apply #'eglot-jdtls--plist-merge input-plists)))
          (should (equal result expected-result)))))))

;;; Tests for eglot-initialization-options

(ert-deftest eglot-initialization-options ()
  "Test eglot-initialization-options with various configurations."
  ;; Test by verifying the core merge logic directly since
  ;; eglot-initialization-options is a CLOS method.
  (let ((test-cases
         '(;; (name config expected-result)
           ("default config"
            nil
            (:extendedClientCapabilities
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
              :advancedIntroduceParameterRefactoringSupport t)
             :bundles []))
           ("custom bundles"
            (:init-options (:bundles ["/path/to/java-debug.jar"
                                      "/path/to/java-test.jar"]))
            (:extendedClientCapabilities
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
              :advancedIntroduceParameterRefactoringSupport t)
             :bundles ["/path/to/java-debug.jar"
                       "/path/to/java-test.jar"]))
           ("override extendedClientCapabilities"
            (:init-options (:extendedClientCapabilities
                            (:classFileContentsSupport :json-false
                             :customCapability t)))
            (:extendedClientCapabilities
             (:classFileContentsSupport :json-false
              :customCapability t)
             :bundles []))
           ("merge bundles and extendedClientCapabilities"
            (:init-options (:bundles ["/custom.jar"]
                            :extendedClientCapabilities
                            (:classFileContentsSupport t)))
            (:extendedClientCapabilities
             (:classFileContentsSupport t)
             :bundles ["/custom.jar"])))))

    (dolist (test-case test-cases)
      (pcase-let* ((`(,name ,config ,expected-result) test-case))
        (let ((eglot-jdtls-config config))
          ;; Test the core logic: merge user config with default
          (let* ((user-init (plist-get eglot-jdtls-config :init-options))
                 (default-init (plist-get eglot-jdtls--default-config :init-options))
                 (init-options (eglot-jdtls--plist-merge default-init user-init))
                 (result (list
                          :extendedClientCapabilities (plist-get init-options
                                                                 :extendedClientCapabilities)
                          :bundles (plist-get init-options :bundles))))
            (should (equal result expected-result))))))))

;;; Tests for eglot-jdtls--select

(ert-deftest eglot-jdtls--select ()
  "Test eglot-jdtls--select with various scenarios."
  (let* ((test-items
          '((:name "Item1" :value 1)
            (:name "Item2" :value 2)
            (:name "Item3" :value 3)))
         (display-fn (lambda (item)
                       (plist-get item :name)))
         (transform-fn (lambda (item)
                         (plist-get item :value)))
         (test-cases
          '(;; (name multiple-p transform-p select expect)
            ("Test single selection without transform"
             nil nil "Item1" (:name "Item1" :value 1))
            ("Test single selection with transform"
             nil t "Item2" 2)
            ("Test multiple selection without transform"
             t nil ("Item1" "Item3") [(:name "Item1" :value 1)
                                      (:name "Item3" :value 3)])
            ("Test multiple selection with transform"
             t t ("Item2" "Item3") [2 3])
            ("Test multiple selection with duplicates (delete-dups)"
             t t ("Item1" "Item2" "Item1" "Item2") [1 2]))))

    (dolist (test-case test-cases)
      (pcase-let* ((`(,name ,multiple-p ,transform-p ,select ,expect) test-case))
        (cl-letf (((symbol-function 'completing-read) (lambda (&rest _args) select))
                  ((symbol-function 'completing-read-multiple) (lambda (&rest _args) select)))
          (let ((result (eglot-jdtls--select test-items "Select: " display-fn multiple-p
                                             (when transform-p transform-fn))))
            (should (equal result expect))))))

    ;; Test complex display function
    (let ((complex-items
           '((:method "toString" :params ["String"])
             (:method "equals" :params ["Object"])
             (:method "hashCode" :params [])))
          (complex-display-fn (lambda (item)
                                (format "%s(%s)"
                                        (plist-get item :method)
                                        (mapconcat #'identity
                                                   (plist-get item :params)
                                                   ", ")))))
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (_prompt _collection &rest _args)
                   "equals(Object)")))
        (let ((result (eglot-jdtls--select complex-items "Method: "
                                           complex-display-fn)))
          (should (equal result '(:method "equals" :params ["Object"]))))))

    ;; Test transform that extracts nested values
    (let ((nested-items
           '((:field (:name "name" :type "String"))
             (:field (:name "age" :type "int"))))
          (nested-display-fn (lambda (item)
                               (let ((field (plist-get item :field)))
                                 (format "%s: %s"
                                         (plist-get field :name)
                                         (plist-get field :type)))))
          (nested-transform-fn (lambda (item)
                                 (plist-get item :field))))
      (cl-letf (((symbol-function 'completing-read-multiple)
                 (lambda (_prompt _collection &rest _args)
                   '("age: int"))))
        (let ((result (eglot-jdtls--select nested-items "Select field: "
                                           nested-display-fn t
                                           nested-transform-fn)))
          (should (equal result [(:name "age" :type "int")])))))

    ;; Test crm-separator customization
    (let ((eglot-jdtls-crm-separator ","))
      (cl-letf (((symbol-function 'completing-read-multiple)
                 (lambda (prompt collection &rest args)
                   ;; Verify the custom separator is used
                   (should (string= eglot-jdtls-crm-separator ","))
                   '("Item1" "Item2"))))
        (let ((result (eglot-jdtls--select test-items "Select: " display-fn
                                           t transform-fn)))
          (should (equal result [1 2])))))))

;;; Tests for eglot-jdtls--override-methods-prompt

(ert-deftest eglot-jdtls--override-methods-prompt/normal-flow ()
  "Test eglot-jdtls--override-methods-prompt - select multiple methods."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-methods
         [(:name "toString" :parameters [] :declaringClass "java.lang.Object")
          (:name "equals" :parameters ["Object"] :declaringClass "java.lang.Object")
          (:name "hashCode" :parameters [] :declaringClass "java.lang.Object")])
        (selected-methods
         [(:name "toString" :parameters [] :declaringClass "java.lang.Object")
          (:name "equals" :parameters ["Object"] :declaringClass "java.lang.Object")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/listOverridableMethods)
                    (list :methods test-methods))
                   ((eq method :java/addOverridableMethods)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (methods prompt display-fn multiple-p &rest _args)
                  (should (equal methods test-methods))
                  (should (string-match "Select methods" prompt))
                  (should multiple-p)
                  selected-methods))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--override-methods-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/listOverridableMethods (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/addOverridableMethods (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--override-methods-prompt/single-method ()
  "Test eglot-jdtls--override-methods-prompt - single method selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-methods
         [(:name "toString" :parameters [] :declaringClass "java.lang.Object")
          (:name "equals" :parameters ["Object"] :declaringClass "java.lang.Object")
          (:name "hashCode" :parameters [] :declaringClass "java.lang.Object")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/listOverridableMethods)
                    (list :methods test-methods))
                   ((eq method :java/addOverridableMethods)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_methods _prompt _display-fn _multiple-p &rest _args)
                  (vector (aref test-methods 0))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--override-methods-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2)))))

(ert-deftest eglot-jdtls--override-methods-prompt/empty-methods ()
  "Test eglot-jdtls--override-methods-prompt - empty methods list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (push method jsonrpc-request-calls)
                  (cond
                   ((eq method :java/listOverridableMethods)
                    (list :methods []))
                   ((eq method :java/addOverridableMethods)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (methods prompt display-fn multiple-p &rest _args)
                  (should (equal methods []))
                  (should multiple-p)
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--override-methods-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/listOverridableMethods jsonrpc-request-calls))
      (should (member :java/addOverridableMethods jsonrpc-request-calls)))))

(ert-deftest eglot-jdtls--override-methods-prompt/display-format ()
  "Test eglot-jdtls--override-methods-prompt - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-methods
         [(:name "toString" :parameters [] :declaringClass "java.lang.Object")
          (:name "equals" :parameters ["Object"] :declaringClass "java.lang.Object")
          (:name "hashCode" :parameters [] :declaringClass "java.lang.Object")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/listOverridableMethods)
                    (list :methods test-methods))
                   ((eq method :java/addOverridableMethods)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               (display-calls nil)
               ((symbol-function 'eglot-jdtls--select)
                (lambda (methods prompt display-fn multiple-p &rest _args)
                  (dolist (method (append methods nil))
                    (push (funcall display-fn method) display-calls))
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--override-methods-prompt mock-server test-arguments)

      (should (member "toString(): java.lang.Object" display-calls))
      (should (member "equals(Object): java.lang.Object" display-calls))
      (should (member "hashCode(): java.lang.Object" display-calls)))))

;;; Tests for eglot-jdtls--generate-toString-prompt

(ert-deftest eglot-jdtls--generate-toString-prompt/normal-flow ()
  "Test eglot-jdtls--generate-toString-prompt - normal flow with multiple fields."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (selected-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkToStringStatus)
                    (list :fields test-fields :exists :json-false))
                   ((eq method :java/generateToString)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (should (equal fields test-fields))
                  (should (string-match "Select fields to include" prompt))
                  (should multiple-p)
                  selected-fields))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-toString-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkToStringStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateToString (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--generate-toString-prompt/confirm-replacement ()
  "Test eglot-jdtls--generate-toString-prompt - toString exists, user confirms replacement."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (selected-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkToStringStatus)
                    (list :fields test-fields :exists t))
                   ((eq method :java/generateToString)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'y-or-n-p)
                (lambda (prompt)
                  (should (string-match "already exists" prompt))
                  t))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  selected-fields))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-toString-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkToStringStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateToString (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--generate-toString-prompt/decline-replacement ()
  "Test eglot-jdtls--generate-toString-prompt - toString exists, user declines replacement."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")]))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkToStringStatus)
                    (list :fields test-fields :exists t))
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'y-or-n-p)
                (lambda (prompt)
                  (should (string-match "already exists" prompt))
                  nil))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  (should-error "Select should not be called when user declines"))))

      (eglot-jdtls--generate-toString-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/checkToStringStatus)))))

(ert-deftest eglot-jdtls--generate-toString-prompt/empty-fields ()
  "Test eglot-jdtls--generate-toString-prompt - empty fields list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkToStringStatus)
                    (list :fields [] :exists :json-false))
                   ((eq method :java/generateToString)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (should (equal fields []))
                  (should multiple-p)
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-toString-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkToStringStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateToString (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--generate-toString-prompt/display-format ()
  "Test eglot-jdtls--generate-toString-prompt - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/checkToStringStatus)
                    (list :fields test-fields :exists :json-false))
                   ((eq method :java/generateToString)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               (display-calls nil)
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (dolist (field (append fields nil))
                    (push (funcall display-fn field) display-calls))
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-toString-prompt mock-server test-arguments)

      (should (member "name: String" display-calls))
      (should (member "age: int" display-calls))
      (should (member "email: String" display-calls)))))

;;; Tests for eglot-jdtls--hashCode-equals-prompt

(ert-deftest eglot-jdtls--hashCode-equals-prompt/normal-flow ()
  "Test eglot-jdtls--hashCode-equals-prompt - methods don't exist, select multiple fields."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")
          (:name "email" :type "String")])
        (selected-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkHashCodeEqualsStatus)
                    (list :fields test-fields :existingMethods []))
                   ((eq method :java/generateHashCodeEquals)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (should (equal fields test-fields))
                  (should (string-match "Select fields to include" prompt))
                  (should multiple-p)
                  selected-fields))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--hashCode-equals-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkHashCodeEqualsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateHashCodeEquals (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--hashCode-equals-prompt/confirm-replacement ()
  "Test eglot-jdtls--hashCode-equals-prompt - methods exist, user confirms replacement."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")
          (:name "email" :type "String")])
        (selected-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkHashCodeEqualsStatus)
                    (list :fields test-fields :existingMethods ["equals" "hashCode"]))
                   ((eq method :java/generateHashCodeEquals)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'y-or-n-p)
                (lambda (prompt)
                  (should (string-match "already exists" prompt))
                  t))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  selected-fields))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--hashCode-equals-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkHashCodeEqualsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateHashCodeEquals (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--hashCode-equals-prompt/decline-replacement ()
  "Test eglot-jdtls--hashCode-equals-prompt - methods exist, user declines replacement."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")
          (:name "email" :type "String")]))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkHashCodeEqualsStatus)
                    (list :fields test-fields :existingMethods ["equals" "hashCode"]))
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'y-or-n-p)
                (lambda (prompt)
                  (should (string-match "already exists" prompt))
                  nil))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--hashCode-equals-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/checkHashCodeEqualsStatus)))))

(ert-deftest eglot-jdtls--hashCode-equals-prompt/empty-fields ()
  "Test eglot-jdtls--hashCode-equals-prompt - empty fields list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkHashCodeEqualsStatus)
                    (list :fields [] :existingMethods []))
                   ((eq method :java/generateHashCodeEquals)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (should (equal fields []))
                  (should multiple-p)
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--hashCode-equals-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkHashCodeEqualsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateHashCodeEquals (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--hashCode-equals-prompt/display-format ()
  "Test eglot-jdtls--hashCode-equals-prompt - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")
          (:name "email" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/checkHashCodeEqualsStatus)
                    (list :fields test-fields :existingMethods []))
                   ((eq method :java/generateHashCodeEquals)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               (display-calls nil)
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (dolist (field (append fields nil))
                    (push (funcall display-fn field) display-calls))
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--hashCode-equals-prompt mock-server test-arguments)

      (should (member "id: long" display-calls))
      (should (member "name: String" display-calls))
      (should (member "email: String" display-calls)))))

(ert-deftest eglot-jdtls--hashCode-equals-prompt/single-field ()
  "Test eglot-jdtls--hashCode-equals-prompt - single field selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "id" :type "long")
          (:name "name" :type "String")
          (:name "email" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkHashCodeEqualsStatus)
                    (list :fields test-fields :existingMethods []))
                   ((eq method :java/generateHashCodeEquals)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  (vector (aref test-fields 0))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--hashCode-equals-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2)))))


;;; Tests for eglot-jdtls--generate-accessors-prompt

(ert-deftest eglot-jdtls--generate-accessors-prompt/normal-flow ()
  "Test eglot-jdtls--generate-accessors-prompt - normal flow with multiple fields."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-accessor-fields
         [(:fieldName "name" :typeName "String")
          (:fieldName "age" :typeName "int")
          (:fieldName "email" :typeName "String")])
        (selected-accessors
         [(:fieldName "name" :typeName "String")
          (:fieldName "age" :typeName "int")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/resolveUnimplementedAccessors)
                    test-accessor-fields)
                   ((eq method :java/generateAccessors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (should (equal fields test-accessor-fields))
                  (should (string-match "Select fields to generate" prompt))
                  (should multiple-p)
                  selected-accessors))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-accessors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/resolveUnimplementedAccessors (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateAccessors (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--generate-accessors-prompt/single-field ()
  "Test eglot-jdtls--generate-accessors-prompt - single field selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-accessor-fields
         [(:fieldName "name" :typeName "String")
          (:fieldName "age" :typeName "int")
          (:fieldName "email" :typeName "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/resolveUnimplementedAccessors)
                    test-accessor-fields)
                   ((eq method :java/generateAccessors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  (vector (aref test-accessor-fields 0))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-accessors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2)))))

(ert-deftest eglot-jdtls--generate-accessors-prompt/empty-fields ()
  "Test eglot-jdtls--generate-accessors-prompt - empty fields list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (push method jsonrpc-request-calls)
                  (cond
                   ((eq method :java/resolveUnimplementedAccessors)
                    [])
                   ((eq method :java/generateAccessors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (should (equal fields []))
                  (should multiple-p)
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-accessors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/resolveUnimplementedAccessors jsonrpc-request-calls))
      (should (member :java/generateAccessors jsonrpc-request-calls)))))

(ert-deftest eglot-jdtls--generate-accessors-prompt/display-format ()
  "Test eglot-jdtls--generate-accessors-prompt - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-accessor-fields
         [(:fieldName "name" :typeName "String")
          (:fieldName "age" :typeName "int")
          (:fieldName "email" :typeName "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/resolveUnimplementedAccessors)
                    test-accessor-fields)
                   ((eq method :java/generateAccessors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               (display-calls nil)
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (dolist (field (append fields nil))
                    (push (funcall display-fn field) display-calls))
                  []))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-accessors-prompt mock-server test-arguments)

      (should (member "name: String" display-calls))
      (should (member "age: int" display-calls))
      (should (member "email: String" display-calls)))))

(ert-deftest eglot-jdtls--generate-accessors-prompt/verify-parameters ()
  "Test eglot-jdtls--generate-accessors-prompt - verify parameters passed to generateAccessors."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-accessor-fields
         [(:fieldName "name" :typeName "String")
          (:fieldName "age" :typeName "int")
          (:fieldName "email" :typeName "String")])
        (selected-accessors
         [(:fieldName "name" :typeName "String")
          (:fieldName "age" :typeName "int")])
        (workspace-edit-result '(:edit (:changes [])))
        (generate-accessors-params nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest args)
                  (cond
                   ((eq method :java/resolveUnimplementedAccessors)
                    test-accessor-fields)
                   ((eq method :java/generateAccessors)
                    (setq generate-accessors-params (car args))
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (_fields _prompt _display-fn _multiple-p &rest _args)
                  selected-accessors))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-accessors-prompt mock-server test-arguments)

      (should (plist-get generate-accessors-params :accessors))
      (should (plist-get generate-accessors-params :context))
      (should (equal (plist-get generate-accessors-params :accessors) selected-accessors))
      (should (equal (plist-get generate-accessors-params :context) (aref test-arguments 0))))))

(ert-deftest eglot-jdtls--generate-accessors-prompt/complex-types ()
  "Test eglot-jdtls--generate-accessors-prompt - complex field types."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (complex-accessor-fields
         [(:fieldName "listData" :typeName "List<String>")
          (:fieldName "mapConfig" :typeName "Map<String,Object>")
          (:fieldName "builder" :typeName "StringBuilder")])
        (selected-complex-accessors
         [(:fieldName "listData" :typeName "List<String>")
          (:fieldName "builder" :typeName "StringBuilder")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/resolveUnimplementedAccessors)
                    complex-accessor-fields)
                   ((eq method :java/generateAccessors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               (display-calls nil)
               ((symbol-function 'eglot-jdtls--select)
                (lambda (fields prompt display-fn multiple-p &rest _args)
                  (dolist (field (append fields nil))
                    (push (funcall display-fn field) display-calls))
                  selected-complex-accessors))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-accessors-prompt mock-server test-arguments)

      (should (member "listData: List<String>" display-calls))
      (should (member "mapConfig: Map<String,Object>" display-calls))
      (should (member "builder: StringBuilder" display-calls)))))


;;; Tests for eglot-jdtls--generate-constructors-prompt

(ert-deftest eglot-jdtls--generate-constructors-prompt/normal-flow ()
  "Test eglot-jdtls--generate-constructors-prompt - select multiple constructors and fields."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-constructors
         [(:name "Person" :parameters ["String" "int"])
          (:name "Person" :parameters ["String" "int" "String"])])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (selected-constructors
         [(:name "Person" :parameters ["String" "int"])
          (:name "Person" :parameters ["String" "int" "String"])])
        (selected-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               (select-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors test-constructors :fields test-fields))
                   ((eq method :java/generateConstructors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (push (list items prompt display-fn multiple-p) select-calls)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    (should (equal items test-constructors))
                    (should multiple-p)
                    selected-constructors)
                   ((string-match "Select fields to generate" prompt)
                    (should (equal items test-fields))
                    (should multiple-p)
                    selected-fields)
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkConstructorsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateConstructors (mapcar #'cadr jsonrpc-request-calls)))
      (should (= (length select-calls) 2)))))

(ert-deftest eglot-jdtls--generate-constructors-prompt/empty-constructors ()
  "Test eglot-jdtls--generate-constructors-prompt - empty constructors list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")])
        (selected-fields
         [(:name "name" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors [] :fields test-fields))
                   ((eq method :java/generateConstructors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    (should (equal items []))
                    (should multiple-p)
                    [])
                   ((string-match "Select fields to generate" prompt)
                    (should (equal items test-fields))
                    (should multiple-p)
                    selected-fields)
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkConstructorsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateConstructors (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--generate-constructors-prompt/empty-fields ()
  "Test eglot-jdtls--generate-constructors-prompt - empty fields list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-constructors
         [(:name "Person" :parameters ["String" "int"])])
        (selected-constructors
         [(:name "Person" :parameters ["String" "int"])])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors test-constructors :fields []))
                   ((eq method :java/generateConstructors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    (should (equal items test-constructors))
                    (should multiple-p)
                    selected-constructors)
                   ((string-match "Select fields to generate" prompt)
                    (should (equal items []))
                    (should multiple-p)
                    [])
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (edit _command)
                  (should (equal edit workspace-edit-result)))))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkConstructorsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateConstructors (mapcar #'cadr jsonrpc-request-calls))))))

(ert-deftest eglot-jdtls--generate-constructors-prompt/single-constructor ()
  "Test eglot-jdtls--generate-constructors-prompt - single constructor selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-constructors
         [(:name "Person" :parameters ["String" "int"])
          (:name "Person" :parameters ["String" "int" "String"])])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors test-constructors :fields test-fields))
                   ((eq method :java/generateConstructors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    (vector (aref test-constructors 0)))
                   ((string-match "Select fields to generate" prompt)
                    (vector (aref test-fields 0)))
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2)))))

(ert-deftest eglot-jdtls--generate-constructors-prompt/single-field ()
  "Test eglot-jdtls--generate-constructors-prompt - single field selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-constructors
         [(:name "Person" :parameters ["String" "int"])])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* ((jsonrpc-request-calls nil)
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors test-constructors :fields test-fields))
                   ((eq method :java/generateConstructors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    (vector (aref test-constructors 0)))
                   ((string-match "Select fields to generate" prompt)
                    (vector (aref test-fields 0)))
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (= (length jsonrpc-request-calls) 2)))))

(ert-deftest eglot-jdtls--generate-constructors-prompt/display-format ()
  "Test eglot-jdtls--generate-constructors-prompt - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-constructors
         [(:name "Person" :parameters ["String" "int"])
          (:name "Person" :parameters ["String" "int" "String"])
          (:name "Person" :parameters [])])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (workspace-edit-result '(:edit (:changes []))))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors test-constructors :fields test-fields))
                   ((eq method :java/generateConstructors)
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               (constructor-display-calls nil)
               (field-display-calls nil)
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    (dolist (constructor (append items nil))
                      (push (funcall display-fn constructor) constructor-display-calls))
                    [])
                   ((string-match "Select fields to generate" prompt)
                    (dolist (field (append items nil))
                      (push (funcall display-fn field) field-display-calls))
                    [])
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (member "Person(String, int)" constructor-display-calls))
      (should (member "Person(String, int, String)" constructor-display-calls))
      (should (member "Person()" constructor-display-calls))
      (should (member "name: String" field-display-calls))
      (should (member "age: int" field-display-calls))
      (should (member "email: String" field-display-calls)))))

(ert-deftest eglot-jdtls--generate-constructors-prompt/verify-parameters ()
  "Test eglot-jdtls--generate-constructors-prompt - verify parameters passed to generateConstructors."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:uri "file:///test.java" :position (:line 1 :character 0))])
        (test-constructors
         [(:name "Person" :parameters ["String" "int"])
          (:name "Person" :parameters ["String" "int" "String"])])
        (test-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")
          (:name "email" :type "String")])
        (selected-constructors
         [(:name "Person" :parameters ["String" "int"])])
        (selected-fields
         [(:name "name" :type "String")
          (:name "age" :type "int")])
        (workspace-edit-result '(:edit (:changes [])))
        (generate-constructors-params nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest args)
                  (cond
                   ((eq method :java/checkConstructorsStatus)
                    (list :constructors test-constructors :fields test-fields))
                   ((eq method :java/generateConstructors)
                    (setq generate-constructors-params (car args))
                    workspace-edit-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn multiple-p &rest _args)
                  (cond
                   ((string-match "Select constructors to generate" prompt)
                    selected-constructors)
                   ((string-match "Select fields to generate" prompt)
                    selected-fields)
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'eglot--apply-workspace-edit)
                (lambda (_edit _command)
                  t)))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (plist-get generate-constructors-params :context))
      (should (plist-get generate-constructors-params :constructors))
      (should (plist-get generate-constructors-params :fields))
      (should (equal (plist-get generate-constructors-params :context) (aref test-arguments 0)))
      (should (equal (plist-get generate-constructors-params :constructors) selected-constructors))
      (should (equal (plist-get generate-constructors-params :fields) selected-fields)))))


(provide 'eglot-jdtls-test)
;;; eglot-jdtls-test.el ends here
