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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
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
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server _edit _command)
                  t)))

      (eglot-jdtls--generate-constructors-prompt mock-server test-arguments)

      (should (plist-get generate-constructors-params :context))
      (should (plist-get generate-constructors-params :constructors))
      (should (plist-get generate-constructors-params :fields))
      (should (equal (plist-get generate-constructors-params :context) (aref test-arguments 0)))
      (should (equal (plist-get generate-constructors-params :constructors) selected-constructors))
      (should (equal (plist-get generate-constructors-params :fields) selected-fields)))))


;;; Tests for eglot-jdtls--generate-delegate-methods-prompt-support

(ert-deftest eglot-jdtls--generate-delegate-methods-prompt-support/normal-flow ()
  "Test eglot-jdtls--generate-delegate-methods-prompt-support - select one field and multiple delegate methods."
  (let*
      ((mock-server (make-hash-table :test 'equal))
       (test-arguments (vector (list :uri "file:///test.java" :position (list :line 1 :character 0))))
       (field-plist (list :name "service" :type "SomeService"))
       (delegate-methods
        (vector
         (list :name "execute" :parameters (vector "String" "int"))
         (list :name "process" :parameters (vector "Object"))
         (list :name "validate" :parameters (vector))))
       (test-delegate-fields
        (vector (list :field field-plist :delegateMethods delegate-methods)))
       (selected-field (list :field field-plist :delegateMethods delegate-methods))
       (selected-methods
        (vector
         (list :field field-plist :delegateMethod (aref delegate-methods 0))
         (list :field field-plist :delegateMethod (aref delegate-methods 2))))
       (workspace-edit-result (list :edit (list :changes (vector)))))
    (cl-letf*
        ((jsonrpc-request-calls nil)
         ((symbol-function 'jsonrpc-request)
          (lambda (server method &rest _args)
            (push (list server method) jsonrpc-request-calls)
            (cond
             ((eq method :java/checkDelegateMethodsStatus)
              (list :delegateFields test-delegate-fields))
             ((eq method :java/generateDelegateMethods)
              workspace-edit-result)
             (t (error "Unexpected method: %s" method)))))
         (select-calls nil)
         ((symbol-function 'eglot-jdtls--select)
          (lambda (items prompt display-fn &optional multiple-p transform-fn)
            (push (list items prompt multiple-p) select-calls)
            (cond
             ;; First call: select field (single selection)
             ((string-match "Select target to generate delegates" prompt)
              (should (equal items test-delegate-fields))
              (should (not multiple-p))
              (if transform-fn
                  (funcall transform-fn selected-field)
                selected-field))
             ;; Second call: select methods (multiple selection)
             ((string-match "Select methods to generate delegates" prompt)
              (should multiple-p)
              selected-methods)
             (t (error "Unexpected prompt: %s" prompt)))))
         ((symbol-function 'eglot-jdtls--apply-edit)
          (lambda (_server edit _command)
            (should (equal edit workspace-edit-result)))))
      (eglot-jdtls--generate-delegate-methods-prompt-support mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkDelegateMethodsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateDelegateMethods (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify eglot-jdtls--select was called twice
      (should (= (length select-calls) 2)))))

(ert-deftest eglot-jdtls--generate-delegate-methods-prompt-support/single-method ()
  "Test eglot-jdtls--generate-delegate-methods-prompt-support - select one field and one delegate method."
  (let*
      ((mock-server (make-hash-table :test 'equal))
       (test-arguments (vector (list :uri "file:///test.java" :position (list :line 1 :character 0))))
       (field-plist (list :name "service" :type "SomeService"))
       (delegate-methods
        (vector
         (list :name "execute" :parameters (vector "String" "int"))
         (list :name "process" :parameters (vector "Object"))
         (list :name "validate" :parameters (vector))))
       (test-delegate-fields
        (vector (list :field field-plist :delegateMethods delegate-methods)))
       (selected-field (list :field field-plist :delegateMethods delegate-methods))
       (selected-methods
        (vector (list :field field-plist :delegateMethod (aref delegate-methods 0))))
       (workspace-edit-result (list :edit (list :changes (vector)))))
    (cl-letf*
        ((jsonrpc-request-calls nil)
         ((symbol-function 'jsonrpc-request)
          (lambda (server method &rest _args)
            (push (list server method) jsonrpc-request-calls)
            (cond
             ((eq method :java/checkDelegateMethodsStatus)
              (list :delegateFields test-delegate-fields))
             ((eq method :java/generateDelegateMethods)
              workspace-edit-result)
             (t (error "Unexpected method: %s" method)))))
         (select-calls nil)
         ((symbol-function 'eglot-jdtls--select)
          (lambda (items prompt display-fn &optional multiple-p transform-fn)
            (push (list items prompt multiple-p) select-calls)
            (cond
             ;; First call: select field (single selection)
             ((string-match "Select target to generate delegates" prompt)
              (should (equal items test-delegate-fields))
              (should (not multiple-p))
              (if transform-fn
                  (funcall transform-fn selected-field)
                selected-field))
             ;; Second call: select methods (multiple selection, but only one chosen)
             ((string-match "Select methods to generate delegates" prompt)
              (should multiple-p)
              selected-methods)
             (t (error "Unexpected prompt: %s" prompt)))))
         ((symbol-function 'eglot-jdtls--apply-edit)
          (lambda (_server edit _command)
            (should (equal edit workspace-edit-result)))))
      (eglot-jdtls--generate-delegate-methods-prompt-support mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkDelegateMethodsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateDelegateMethods (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify eglot-jdtls--select was called twice
      (should (= (length select-calls) 2)))))

(ert-deftest eglot-jdtls--generate-delegate-methods-prompt-support/empty-fields ()
  "Test eglot-jdtls--generate-delegate-methods-prompt-support - empty delegate fields list."
  (let*
      ((mock-server (make-hash-table :test 'equal))
       (test-arguments (vector (list :uri "file:///test.java" :position (list :line 1 :character 0))))
       (test-delegate-fields (vector))
       (workspace-edit-result (list :edit (list :changes (vector)))))
    (cl-letf*
        ((jsonrpc-request-calls nil)
         ((symbol-function 'jsonrpc-request)
          (lambda (server method &rest _args)
            (push (list server method) jsonrpc-request-calls)
            (cond
             ((eq method :java/checkDelegateMethodsStatus)
              (list :delegateFields test-delegate-fields))
             ((eq method :java/generateDelegateMethods)
              workspace-edit-result)
             (t (error "Unexpected method: %s" method)))))
         (select-calls nil)
         ((symbol-function 'eglot-jdtls--select)
          (lambda (items prompt display-fn &optional multiple-p transform-fn)
            (push (list items prompt multiple-p) select-calls)
            (cond
             ;; First call: select field from empty list
             ((string-match "Select target to generate delegates" prompt)
              (should (equal items test-delegate-fields))
              (should (equal items (vector)))
              (should (not multiple-p))
              ;; Return nil when no fields available
              nil)
             ;; This shouldn't be reached when field is nil, but handle it
             (t nil))))
         ((symbol-function 'eglot-jdtls--apply-edit)
          (lambda (_server edit _command)
            (should (equal edit workspace-edit-result)))))
      ;; This should handle the case where no fields are available
      ;; When selected-field is nil, accessing :delegateMethods will fail
      ;; So we expect an error or the code to handle nil gracefully
      (condition-case err
          (eglot-jdtls--generate-delegate-methods-prompt-support mock-server test-arguments)
        ((error wrong-type-argument)
         ;; Expected when trying to access :delegateMethods on nil
         (message "Expected error when no delegate fields: %s" err)))
      ;; Verify jsonrpc-request was called for checkDelegateMethodsStatus
      (should (member :java/checkDelegateMethodsStatus (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify eglot-jdtls--select was called twice (field selection fails, but code continues)
      (should (= (length select-calls) 2)))))

(ert-deftest eglot-jdtls--generate-delegate-methods-prompt-support/empty-methods ()
  "Test eglot-jdtls--generate-delegate-methods-prompt-support - empty delegate methods list."
  (let*
      ((mock-server (make-hash-table :test 'equal))
       (test-arguments (vector (list :uri "file:///test.java" :position (list :line 1 :character 0))))
       (field-plist (list :name "service" :type "SomeService"))
       (delegate-methods (vector))
       (test-delegate-fields
        (vector (list :field field-plist :delegateMethods delegate-methods)))
       (selected-field (list :field field-plist :delegateMethods delegate-methods))
       (workspace-edit-result (list :edit (list :changes (vector)))))
    (cl-letf*
        ((jsonrpc-request-calls nil)
         ((symbol-function 'jsonrpc-request)
          (lambda (server method &rest _args)
            (push (list server method) jsonrpc-request-calls)
            (cond
             ((eq method :java/checkDelegateMethodsStatus)
              (list :delegateFields test-delegate-fields))
             ((eq method :java/generateDelegateMethods)
              workspace-edit-result)
             (t (error "Unexpected method: %s" method)))))
         (select-calls nil)
         ((symbol-function 'eglot-jdtls--select)
          (lambda (items prompt display-fn &optional multiple-p transform-fn)
            (push (list items prompt multiple-p) select-calls)
            (cond
             ;; First call: select field (single selection)
             ((string-match "Select target to generate delegates" prompt)
              (should (equal items test-delegate-fields))
              (should (not multiple-p))
              (if transform-fn
                  (funcall transform-fn selected-field)
                selected-field))
             ;; Second call: select methods from empty list
             ((string-match "Select methods to generate delegates" prompt)
              (should (equal items delegate-methods))
              (should (equal items (vector)))
              (should multiple-p)
              ;; Return empty selection when no methods available
              (vector))
             (t (error "Unexpected prompt: %s" prompt)))))
         ((symbol-function 'eglot-jdtls--apply-edit)
          (lambda (_server edit _command)
            (should (equal edit workspace-edit-result)))))
      (eglot-jdtls--generate-delegate-methods-prompt-support mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/checkDelegateMethodsStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/generateDelegateMethods (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify eglot-jdtls--select was called twice
      (should (= (length select-calls) 2)))))

(ert-deftest eglot-jdtls--generate-delegate-methods-prompt-support/display-format ()
  "Test eglot-jdtls--generate-delegate-methods-prompt-support - verify display function format."
  (let*
      ((mock-server (make-hash-table :test 'equal))
       (test-arguments (vector (list :uri "file:///test.java" :position (list :line 1 :character 0))))
       (field-plist (list :name "service" :type "SomeService"))
       (delegate-methods
        (vector
         (list :name "execute" :parameters (vector "String" "int"))
         (list :name "process" :parameters (vector "Object"))
         (list :name "validate" :parameters (vector))))
       (test-delegate-fields
        (vector (list :field field-plist :delegateMethods delegate-methods)))
       (selected-field (list :field field-plist :delegateMethods delegate-methods))
       (selected-methods
        (vector
         (list :field field-plist :delegateMethod (aref delegate-methods 0))
         (list :field field-plist :delegateMethod (aref delegate-methods 1))))
       (workspace-edit-result (list :edit (list :changes (vector)))))
    (cl-letf*
        ((jsonrpc-request-calls nil)
         ((symbol-function 'jsonrpc-request)
          (lambda (server method &rest _args)
            (push (list server method) jsonrpc-request-calls)
            (cond
             ((eq method :java/checkDelegateMethodsStatus)
              (list :delegateFields test-delegate-fields))
             ((eq method :java/generateDelegateMethods)
              workspace-edit-result)
             (t (error "Unexpected method: %s" method)))))
         (field-display-calls nil)
         (method-display-calls nil)
         ((symbol-function 'eglot-jdtls--select)
          (lambda (items prompt display-fn &optional multiple-p transform-fn)
            (cond
             ;; First call: select field - capture display format
             ((string-match "Select target to generate delegates" prompt)
              (dolist (field (append items nil))
                (push (funcall display-fn field) field-display-calls))
              (if transform-fn
                  (funcall transform-fn selected-field)
                selected-field))
             ;; Second call: select methods - capture display format
             ((string-match "Select methods to generate delegates" prompt)
              (dolist (method (append items nil))
                (push (funcall display-fn method) method-display-calls))
              selected-methods)
             (t (error "Unexpected prompt: %s" prompt)))))
         ((symbol-function 'eglot-jdtls--apply-edit)
          (lambda (_server edit _command)
            (should (equal edit workspace-edit-result)))))
      (eglot-jdtls--generate-delegate-methods-prompt-support mock-server test-arguments)
      ;; Verify field display format: "name: type"
      (should (member "service: SomeService" field-display-calls))
      ;; Verify method display format: "fieldName.methodName(param1, param2)"
      (should (member "service.execute(String, int)" method-display-calls))
      (should (member "service.process(Object)" method-display-calls))
      (should (member "service.validate()" method-display-calls)))))


;;; Tests for eglot-jdtls--refactor-edit

(ert-deftest eglot-jdtls--refactor-edit/with-edit ()
  "Test eglot-jdtls--refactor-edit - apply workspace edit when edit is present."
  (let ((mock-server (make-hash-table :test 'equal))
        (eglot-execute-called nil)
        (edit-applied nil))
    (cl-letf* (((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit command)
                  (setq edit-applied t)
                  (should (equal edit '(:changes [])))))
               ((symbol-function 'eglot-execute)
                (lambda (&rest _args)
                  (setq eglot-execute-called t))))
      (eglot-jdtls--refactor-edit mock-server (list :edit '(:changes [])))
      (should edit-applied)
      (should (not eglot-execute-called)))))

(ert-deftest eglot-jdtls--refactor-edit/with-error-message ()
  "Test eglot-jdtls--refactor-edit - display error message when errorMessage is present."
  (let ((mock-server (make-hash-table :test 'equal))
        (message-calls nil)
        (edit-applied nil))
    (cl-letf* (((symbol-function 'message)
                (lambda (format-string &rest args)
                  (push (cons format-string args) message-calls)))
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit command)
                  (setq edit-applied t)))
               ((symbol-function 'eglot-execute)
                (lambda (&rest _args)
                  t)))
      (eglot-jdtls--refactor-edit mock-server (list :errorMessage "Refactoring failed"))
      (should (= (length message-calls) 1))
      (should (string= (car (car message-calls)) "%s"))
      (should (equal (cdr (car message-calls)) '("Refactoring failed")))
      (should (not edit-applied)))))

(ert-deftest eglot-jdtls--refactor-edit/with-command ()
  "Test eglot-jdtls--refactor-edit - execute follow-up command when command is present."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-command (list :command "java.action.rename" :arguments ["test"]))
        (eglot-execute-called nil)
        (execute-args nil))
    (cl-letf* (((symbol-function 'eglot-execute)
                (lambda (server command)
                  (setq eglot-execute-called t)
                  (setq execute-args (list server command))))
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (&rest _args)
                  t)))
      (eglot-jdtls--refactor-edit mock-server (list :command test-command))
      (should eglot-execute-called)
      (should (equal (car execute-args) mock-server))
      (should (equal (cadr execute-args) test-command)))))

(ert-deftest eglot-jdtls--refactor-edit/with-edit-and-command ()
  "Test eglot-jdtls--refactor-edit - apply edit first, then execute command when both are present."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-edit '(:changes []))
        (test-command (list :command "java.action.rename" :arguments ["test"]))
        (call-order nil)
        (edit-applied nil)
        (eglot-execute-called nil))
    (cl-letf* (((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (_server edit command)
                  (push 'edit call-order)
                  (setq edit-applied t)
                  (should (equal edit test-edit))))
               ((symbol-function 'eglot-execute)
                (lambda (server command)
                  (push 'execute call-order)
                  (setq eglot-execute-called t)
                  (should (equal command test-command)))))
      (eglot-jdtls--refactor-edit mock-server (list :edit test-edit :command test-command))
      (should edit-applied)
      (should eglot-execute-called)
      (should (equal call-order '(execute edit))))))

(ert-deftest eglot-jdtls--refactor-edit/empty-refactor-edit ()
  "Test eglot-jdtls--refactor-edit - handle empty refactor-edit gracefully."
  (let ((mock-server (make-hash-table :test 'equal))
        (message-called nil)
        (edit-applied nil)
        (eglot-execute-called nil))
    (cl-letf* (((symbol-function 'message)
                (lambda (&rest _args)
                  (setq message-called t)))
               ((symbol-function 'eglot-jdtls--apply-edit)
                (lambda (&rest _args)
                  (setq edit-applied t)))
               ((symbol-function 'eglot-execute)
                (lambda (&rest _args)
                  (setq eglot-execute-called t))))
      (eglot-jdtls--refactor-edit mock-server nil)
      (should (not message-called))
      (should (not edit-applied))
      (should (not eglot-execute-called)))))


;;; Tests for eglot-jdtls--move-file

(ert-deftest eglot-jdtls--move-file/normal-flow ()
  "Test eglot-jdtls--move-file - normal flow with destination selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:context nil)
                         (:uri "file:///test/MyClass.java")])
        (test-destinations
         [(:displayName "com.example.service" :path "src/main/java/com/example/service")
          (:displayName "com.example.util" :path "src/main/java/com/example/util")
          (:displayName "com.example.model" :path "src/main/java/com/example/model")])
        (selected-destination (list :displayName "com.example.service"
                                    :path "src/main/java/com/example/service"
                                    :project "test-project"))
        (move-result '(:edit (:changes [])))
        (jsonrpc-request-calls nil)
        (move-params nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :destinations test-destinations))
                   ((eq method :java/move)
                    (setq move-params (car args))
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'buffer-file-name)
                (lambda ()
                  "/test/MyClass.java"))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (destinations prompt display-fn &rest _args)
                  (should (equal destinations test-destinations))
                  (should (string-match "Choose the target package" prompt))
                  selected-destination))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal result move-result)))))
      (eglot-jdtls--move-file mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/getMoveDestinations (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/move (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify move parameters
      (should (plist-get move-params :moveKind))
      (should (equal (plist-get move-params :moveKind) "moveResource"))
      (should (plist-get move-params :sourceUris))
      (should (equal (plist-get move-params :sourceUris)
                     (vector "file:///test/MyClass.java")))
      (should (plist-get move-params :destination))
      (should (equal (plist-get move-params :destination) selected-destination))
      (should (plist-get move-params :updateReferences))
      (should (equal (plist-get move-params :updateReferences) t))
      ;; Verify refactor-edit was called
      (should refactor-edit-called))))

(ert-deftest eglot-jdtls--move-file/error-message ()
  "Test eglot-jdtls--move-file - display error message when getMoveDestinations returns errorMessage."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:context nil)
                         (:uri "file:///test/MyClass.java")])
        (jsonrpc-request-calls nil)
        (message-called nil)
        (message-content nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :errorMessage "Cannot find move destinations: compilation error"))
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args))))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  (setq refactor-edit-called t))))
      (eglot-jdtls--move-file mock-server test-arguments)
      ;; Verify jsonrpc-request was called only for getMoveDestinations
      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/getMoveDestinations))
      ;; Verify message was called with the error
      (should message-called)
      (should (string= message-content "Cannot find move destinations: compilation error"))
      ;; Verify refactor-edit was not called
      (should (not refactor-edit-called)))))

(ert-deftest eglot-jdtls--move-file/empty-destinations ()
  "Test eglot-jdtls--move-file - display message when destinations is empty vector."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:context nil)
                         (:uri "file:///test/MyClass.java")])
        (jsonrpc-request-calls nil)
        (message-called nil)
        (message-content nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :destinations []))
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args))))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  (setq refactor-edit-called t))))
      (eglot-jdtls--move-file mock-server test-arguments)
      ;; Verify jsonrpc-request was called only for getMoveDestinations
      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/getMoveDestinations))
      ;; Verify message was called with the appropriate message
      (should message-called)
      (should (string= message-content
                       "Cannot find available Java packages to move the selected files to."))
      ;; Verify refactor-edit was not called
      (should (not refactor-edit-called)))))

(ert-deftest eglot-jdtls--move-file/display-format ()
  "Test eglot-jdtls--move-file - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:context nil)
                         (:uri "file:///test/MyClass.java")])
        (test-destinations
         [(:displayName "com.example.service" :path "src/main/java/com/example/service")
          (:displayName "com.example.util" :path "src/main/java/com/example/util")
          (:displayName "com.example.model" :path "src/main/java/com/example/model")])
        (selected-destination (aref [(:displayName "com.example.service"
                                      :path "src/main/java/com/example/service")] 0))
        (move-result '(:edit (:changes [])))
        (display-calls nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :destinations test-destinations))
                   ((eq method :java/move)
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'buffer-file-name)
                (lambda ()
                  "/test/MyClass.java"))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (destinations prompt display-fn &rest _args)
                  (should (string-match "Choose the target package for MyClass.java" prompt))
                  (dolist (dest (append destinations nil))
                    (push (funcall display-fn dest) display-calls))
                  selected-destination))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  t)))
      (eglot-jdtls--move-file mock-server test-arguments)
      ;; Verify display format: "displayName - path"
      (should (member "com.example.service - src/main/java/com/example/service" display-calls))
      (should (member "com.example.util - src/main/java/com/example/util" display-calls))
      (should (member "com.example.model - src/main/java/com/example/model" display-calls)))))

;;; Tests for eglot-jdtls--instant-method

(ert-deftest eglot-jdtls--instant-method/normal-flow ()
  "Test eglot-jdtls--instant-method - normal flow with destination selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "myMethod")])
        (test-destinations
         [(:name "service" :type "Service" :isField :json-false)
          (:name "helper" :type "Helper" :isField t)
          (:name "delegate" :type "Delegate" :isField :json-false)])
        (selected-destination (list :name "service" :type "Service" :isField :json-false))
        (move-result '(:edit (:changes [])))
        (jsonrpc-request-calls nil)
        (move-params nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :destinations test-destinations))
                   ((eq method :java/move)
                    (setq move-params (car args))
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (destinations prompt display-fn &rest _args)
                  (should (equal destinations test-destinations))
                  (should (string-match "Select the new class for the instance method myMethod" prompt))
                  selected-destination))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal result move-result)))))
      (eglot-jdtls--instant-method mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 2))
      (should (member :java/getMoveDestinations (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/move (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify move parameters
      (should (plist-get move-params :moveKind))
      (should (equal (plist-get move-params :moveKind) "moveInstanceMethod"))
      (should (plist-get move-params :sourceUris))
      (should (equal (plist-get move-params :sourceUris)
                     (vector "file:///test/MyClass.java")))
      (should (plist-get move-params :destination))
      (should (equal (plist-get move-params :destination) selected-destination))
      (should (plist-get move-params :updateReferences))
      (should (equal (plist-get move-params :updateReferences) t))
      ;; Verify refactor-edit was called
      (should refactor-edit-called))))

(ert-deftest eglot-jdtls--instant-method/error-message ()
  "Test eglot-jdtls--instant-method - display error message when getMoveDestinations returns errorMessage."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "myMethod")])
        (jsonrpc-request-calls nil)
        (message-called nil)
        (message-content nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :errorMessage "Cannot find move destinations: method not found"))
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args))))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  (setq refactor-edit-called t))))
      (eglot-jdtls--instant-method mock-server test-arguments)
      ;; Verify jsonrpc-request was called only for getMoveDestinations
      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/getMoveDestinations))
      ;; Verify message was called with the error
      (should message-called)
      (should (string= message-content "Cannot find move destinations: method not found"))
      ;; Verify refactor-edit was not called
      (should (not refactor-edit-called)))))

(ert-deftest eglot-jdtls--instant-method/empty-destinations ()
  "Test eglot-jdtls--instant-method - display message when destinations is empty vector."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "myMethod")])
        (jsonrpc-request-calls nil)
        (message-called nil)
        (message-content nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :destinations []))
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args))))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  (setq refactor-edit-called t))))
      (eglot-jdtls--instant-method mock-server test-arguments)
      ;; Verify jsonrpc-request was called only for getMoveDestinations
      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/getMoveDestinations))
      ;; Verify message was called with the appropriate message
      (should message-called)
      (should (string= message-content
                       "Cannot find available Java packages to move the selected files to"))
      ;; Verify refactor-edit was not called
      (should (not refactor-edit-called)))))

(ert-deftest eglot-jdtls--instant-method/display-format ()
  "Test eglot-jdtls--instant-method - verify display function format with [Field] and [Method Parameter] labels."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "myMethod")])
        (test-destinations
         [(:name "service" :type "Service" :isField :json-false)
          (:name "helper" :type "Helper" :isField t)
          (:name "delegate" :type "Delegate" :isField :json-false)])
        (selected-destination (aref [(:name "service" :type "Service" :isField :json-false)] 0))
        (move-result '(:edit (:changes [])))
        (display-calls nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (cond
                   ((eq method :java/getMoveDestinations)
                    (list :destinations test-destinations))
                   ((eq method :java/move)
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (destinations prompt display-fn &rest _args)
                  (should (string-match "Select the new class for the instance method myMethod" prompt))
                  (dolist (dest (append destinations nil))
                    (push (funcall display-fn dest) display-calls))
                  selected-destination))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  t)))
      (eglot-jdtls--instant-method mock-server test-arguments)
      ;; Verify display format: "[Method Parameter] type name" for isField :json-false
      ;;                      "[Field]            type name" for isField t (12 spaces for alignment)
      (should (member "[Method Parameter] Service service" display-calls))
      (should (member "[Field]            Helper helper" display-calls))
      (should (member "[Method Parameter] Delegate delegate" display-calls)))))


;;; Tests for eglot-jdtls--select-target-class

(ert-deftest eglot-jdtls--select-target-class/normal-flow ()
  "Test eglot-jdtls--select-target-class - normal flow with symbol filtering and selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-prompt "Select target class: ")
        (test-project-name "test-project")
        (test-excludes '("com.example.ExcludedClass" "com.example.AnotherExcluded"))
        (test-symbols
         [(:name "MyClass" :containerName "com.example")
          (:name "ExcludedClass" :containerName "com.example")
          (:name "Helper" :containerName "com.example.util")
          (:name "AnotherExcluded" :containerName "com.example")])
        (selected-symbol (list :name "MyClass" :containerName "com.example"))
        (jsonrpc-request-calls nil)
        (filtered-symbols-actual nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method args) jsonrpc-request-calls)
                  (should (eq server mock-server))
                  (should (eq method :java/searchSymbols))
                  (let ((params (car args)))
                    (should (string= (plist-get params :query) "*"))
                    (should (string= (plist-get params :projectName) test-project-name))
                    (should (eq (plist-get params :sourceOnly) t)))
                  test-symbols))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (symbols prompt display-fn &rest _args)
                  (setq filtered-symbols-actual symbols)
                  (should (string-match "Select target class" prompt))
                  ;; Verify that excluded classes are not in the filtered list
                  (dolist (symbol (append symbols nil))
                    (let* ((item symbol)
                           (name (plist-get item :name))
                           (containerName (plist-get item :containerName))
                           (full-name (if containerName
                                         (format "%s.%s" containerName name)
                                       name)))
                      (should (not (member full-name test-excludes)))))
                  selected-symbol)))
      (let ((result (eglot-jdtls--select-target-class mock-server test-prompt test-project-name test-excludes)))
        ;; Verify jsonrpc-request was called
        (should (= (length jsonrpc-request-calls) 1))
        ;; Verify the result is the selected symbol
        (should (equal result selected-symbol))
        ;; Verify filtered symbols does not contain excluded classes
        (should (length> filtered-symbols-actual 0))))))

(ert-deftest eglot-jdtls--select-target-class/all-excluded ()
  "Test eglot-jdtls--select-target-class - all symbols are excluded, returns nil."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-prompt "Select target class: ")
        (test-project-name "test-project")
        (test-excludes '("com.example.MyClass" "com.example.Helper"))
        (test-symbols
         [(:name "MyClass" :containerName "com.example")
          (:name "Helper" :containerName "com.example")])
        (eglot-jdtls--select-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest args)
                  (should (eq method :java/searchSymbols))
                  test-symbols))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (&rest _args)
                  (setq eglot-jdtls--select-called t))))
      (let ((result (eglot-jdtls--select-target-class mock-server test-prompt test-project-name test-excludes)))
        ;; Verify the result is nil when all symbols are excluded
        (should (eq result nil))
        ;; Verify eglot-jdtls--select was NOT called
        (should (not eglot-jdtls--select-called))))))

(ert-deftest eglot-jdtls--select-target-class/empty-symbols ()
  "Test eglot-jdtls--select-target-class - searchSymbols returns empty list, returns nil."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-prompt "Select target class: ")
        (test-project-name "test-project")
        (test-excludes '())
        (eglot-jdtls--select-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest args)
                  (should (eq method :java/searchSymbols))
                  []))  ; Empty vector
               ((symbol-function 'eglot-jdtls--select)
                (lambda (&rest _args)
                  (setq eglot-jdtls--select-called t))))
      (let ((result (eglot-jdtls--select-target-class mock-server test-prompt test-project-name test-excludes)))
        ;; Verify the result is nil when no symbols are returned
        (should (eq result nil))
        ;; Verify eglot-jdtls--select was NOT called
        (should (not eglot-jdtls--select-called))))))

(ert-deftest eglot-jdtls--select-target-class/display-format ()
  "Test eglot-jdtls--select-target-class - verify display function format."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-prompt "Select target class: ")
        (test-project-name "test-project")
        (test-excludes '())
        (test-symbols
         [(:name "MyClass" :containerName "com.example")
          (:name "Helper" :containerName "com.example.util")
          (:name "Test" :containerName nil)])  ; nil containerName case
        (display-calls nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest args)
                  (should (eq method :java/searchSymbols))
                  test-symbols))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (symbols prompt display-fn &rest _args)
                  (should (string-match "Select target class" prompt))
                  (dolist (symbol symbols)
                    (push (funcall display-fn symbol) display-calls))
                  (car symbols))))
      (eglot-jdtls--select-target-class mock-server test-prompt test-project-name test-excludes)
      ;; Verify display format: "name containerName"
      (should (member "MyClass com.example" display-calls))
      (should (member "Helper com.example.util" display-calls))
      ;; Verify nil containerName case displays "Test nil"
      (should (member "Test nil" display-calls)))))

;;; Tests for eglot-jdtls--move-static-member

(ert-deftest eglot-jdtls--move-static-member/normal-flow ()
  "Test eglot-jdtls--move-static-member - normal flow with target class selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "myStaticMethod"
                          :projectName "test-project"
                          :enclosingTypeName "com.example.MyClass"
                          :memberType 5)])  ; 5 is eglot-jdtls--symbol-kind-method
        (test-symbols
         [(:name "TargetClass" :containerName "com.example")
          (:name "Helper" :containerName "com.example.util")])
        (selected-target (list :name "TargetClass" :containerName "com.example"))
        (move-result '(:edit (:changes [])))
        (jsonrpc-request-calls nil)
        (move-params nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/searchSymbols)
                    test-symbols)
                   ((eq method :java/move)
                    (setq move-params (car args))
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select-target-class)
                (lambda (server prompt project-name excludes)
                  (should (string-match "Select the new class for the static member myStaticMethod" prompt))
                  (should (equal project-name "test-project"))
                  ;; Verify excludes contains the enclosing type
                  (should (member "com.example.MyClass" excludes))
                  selected-target))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal result move-result)))))
      (eglot-jdtls--move-static-member mock-server test-arguments)
      ;; Verify jsonrpc-request was called for :java/move
      (should (member :java/move (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify move parameters
      (should (plist-get move-params :moveKind))
      (should (equal (plist-get move-params :moveKind) "moveStaticMember"))
      (should (plist-get move-params :sourceUris))
      (should (equal (plist-get move-params :sourceUris)
                     (vector "file:///test/MyClass.java")))
      (should (plist-get move-params :params))
      (should (equal (plist-get move-params :params) (aref test-arguments 1)))
      (should (plist-get move-params :destination))
      (should (equal (plist-get move-params :destination) selected-target))
      ;; Verify refactor-edit was called
      (should refactor-edit-called))))

(ert-deftest eglot-jdtls--move-static-member/cancel-selection ()
  "Test eglot-jdtls--move-static-member - user cancels target class selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [(:context nil)
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "myStaticMethod"
                          :projectName "test-project"
                          :enclosingTypeName "com.example.MyClass"
                          :memberType 5)])  ; 5 is eglot-jdtls--symbol-kind-method
        (test-symbols
         [(:name "TargetClass" :containerName "com.example")
          (:name "Helper" :containerName "com.example.util")])
        (jsonrpc-request-calls nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/searchSymbols)
                    test-symbols)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select-target-class)
                (lambda (server prompt project-name excludes)
                  (should (string-match "Select the new class for the static member myStaticMethod" prompt))
                  (should (equal project-name "test-project"))
                  ;; User cancels selection, return nil
                  nil))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
      (should-error "refactor-edit should not be called when user cancels"))))
       (eglot-jdtls--move-static-member mock-server test-arguments)
       ;; Verify jsonrpc-request was NOT called for :java/move
       (should (not (member :java/move (mapcar #'cadr jsonrpc-request-calls))))
       ;; Verify refactor-edit was NOT called
       (should (not refactor-edit-called)))))


;;; Tests for eglot-jdtls--move-type

(ert-deftest eglot-jdtls--move-type/normal-flow-new-file ()
  "Test eglot-jdtls--move-type - normal flow moving type to new file."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [:moveType
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "MyType"
                          :projectName "test-project"
                          :supportedDestinationKinds ["newFile"]
                          :enclosingTypeName "MyClass")])
        (test-kinds ["newFile"])
        (selected-kind "newFile")
        (move-result '(:edit (:changes [])))
        (jsonrpc-request-calls nil)
        (move-params nil)
        (refactor-edit-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/move)
                    (setq move-params (car args))
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn &rest _args)
                  (should (equal items test-kinds))
                  (should (string-match "What would you like to do?" prompt))
                  selected-kind))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal result move-result)))))
      (eglot-jdtls--move-type mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/move))
      ;; Verify move parameters
      (should (plist-get move-params :moveKind))
      (should (equal (plist-get move-params :moveKind) "moveTypeToNewFile"))
      (should (plist-get move-params :sourceUris))
      (should (plist-get move-params :params))
      (should (equal (plist-get move-params :params) (aref test-arguments 1)))
      ;; Verify refactor-edit was called
      (should refactor-edit-called))))

(ert-deftest eglot-jdtls--move-type/normal-flow-to-another-class ()
  "Test eglot-jdtls--move-type - normal flow moving type to another class."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [:moveType
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "MyType"
                          :projectName "test-project"
                          :supportedDestinationKinds ["newFile" "moveTypeToClass"]
                          :enclosingTypeName "MyClass")])
        (test-kinds ["newFile" "moveTypeToClass"])
        (selected-kind "moveTypeToClass")
        (selected-target-class "com.example.TargetClass")
        (move-result '(:edit (:changes [])))
        (jsonrpc-request-calls nil)
        (move-params nil)
        (refactor-edit-called nil)
        (select-target-class-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/move)
                    (setq move-params (car args))
                    move-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn &rest _args)
                  (should (equal items test-kinds))
                  (should (string-match "What would you like to do?" prompt))
                  selected-kind))
               ((symbol-function 'eglot-jdtls--select-target-class)
                (lambda (server prompt project-name excludes)
                  (setq select-target-class-called t)
                  (should (string-match "Select the new class for the type" prompt))
                  (should (equal project-name "test-project"))
                  (should excludes)
                  selected-target-class))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal result move-result)))))
      (eglot-jdtls--move-type mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (= (length jsonrpc-request-calls) 1))
      (should (eq (cadr (car jsonrpc-request-calls)) :java/move))
      ;; Verify select-target-class was called
      (should select-target-class-called)
      ;; Verify move parameters
      (should (plist-get move-params :moveKind))
      (should (equal (plist-get move-params :moveKind) "moveTypeToClass"))
      (should (plist-get move-params :sourceUris))
      (should (plist-get move-params :params))
      (should (equal (plist-get move-params :params) (aref test-arguments 1)))
      (should (plist-get move-params :destination))
      (should (equal (plist-get move-params :destination) selected-target-class))
      ;; Verify refactor-edit was called
      (should refactor-edit-called))))

(ert-deftest eglot-jdtls--move-type/empty-kinds-shows-error ()
  "Test eglot-jdtls--move-type - empty supportedDestinationKinds shows error message."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [:moveType
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "MyType"
                          :projectName "test-project"
                          :supportedDestinationKinds []
                          :enclosingTypeName "MyClass")])
        (message-called nil)
        (message-content nil)
        (jsonrpc-request-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (&rest _args)
                  (setq jsonrpc-request-called t)))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args)))))
      (eglot-jdtls--move-type mock-server test-arguments)
      ;; Verify message was called
      (should message-called)
      ;; Verify the error message
      (should (string= message-content "No available destination kinds"))
      ;; Verify jsonrpc-request was NOT called
      (should (not jsonrpc-request-called)))))

(ert-deftest eglot-jdtls--move-type/cancel-target-class-selection ()
  "Test eglot-jdtls--move-type - user cancels target class selection."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments [:moveType
                         (:textDocument (:uri "file:///test/MyClass.java"))
                         (:displayName "MyType"
                          :projectName "test-project"
                          :supportedDestinationKinds ["newFile" "moveTypeToClass"]
                          :enclosingTypeName "MyClass")])
        (test-kinds ["newFile" "moveTypeToClass"])
        (selected-kind "moveTypeToClass")
        (move-result '(:edit (:changes [])))
        (jsonrpc-request-called nil)
        (move-params nil)
        (select-target-class-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (setq jsonrpc-request-called t)
                  (when (eq method :java/move)
                    (setq move-params (car args))
                    move-result)))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn &rest _args)
                  (should (equal items test-kinds))
                  (should (string-match "What would you like to do?" prompt))
                  selected-kind))
               ((symbol-function 'eglot-jdtls--select-target-class)
                (lambda (server prompt project-name excludes)
                  (setq select-target-class-called t)
                  (should (string-match "Select the new class for the type" prompt))
                  (should (equal project-name "test-project"))
                  ;; User cancels - return nil
                  nil)))
      (eglot-jdtls--move-type mock-server test-arguments)
      ;; Verify select-target-class was called
      (should select-target-class-called)
      ;; Verify jsonrpc-request was called even with nil destination
      (should jsonrpc-request-called)
      ;; Verify move parameters
      (should (plist-get move-params :moveKind))
      (should (equal (plist-get move-params :moveKind) "moveTypeToClass"))
      (should (plist-get move-params :sourceUris))
      (should (plist-get move-params :params))
      (should (equal (plist-get move-params :params) (aref test-arguments 1)))
      ;; Verify destination is nil (user cancelled)
      (should (eq (plist-get move-params :destination) nil)))))


;;; Tests for eglot-jdtls--change-signature-build-content

(ert-deftest eglot-jdtls--change-signature-build-content/normal-flow ()
  "Test building content with modifier, return type, name, parameters and exceptions."
  (let* (;; Build parameters as hash tables since pcase map pattern works with hash tables
         (param1 (make-hash-table :test 'equal))
         (param2 (make-hash-table :test 'equal))
         ;; Build exceptions as hash tables
         (exc1 (make-hash-table :test 'equal))
         (exc2 (make-hash-table :test 'equal))
         ;; Populate param1
         (_ (puthash :type "int" param1))
         (_ (puthash :name "count" param1))
         (_ (puthash :originalIndex 0 param1))
         ;; Populate param2
         (_ (puthash :type "String" param2))
         (_ (puthash :name "name" param2))
         (_ (puthash :originalIndex 1 param2))
         ;; Populate exc1
         (_ (puthash :type "IOException" exc1))
         ;; Populate exc2
         (_ (puthash :type "SQLException" exc2))
         (sig-info (list :modifier "public"
                         :returnType "String"
                         :methodName "testMethod"
                         :parameters (vector param1 param2)
                         :exceptions (vector exc1 exc2)))
         (result (eglot-jdtls--change-signature-build-content sig-info)))
    (should (listp result))
    ;; Should have: 3 basic lines + 1 params label + 2 param lines +
    ;;              1 exceptions label + 2 exception lines +
    ;;              1 IsDelegate line + 1 blank line + 1 comment line
    (should (= (length result) 12))

    ;; First line: Access modifier
    (should (string-match-p "Access modifier: public" (car result)))

    ;; Second line: Return type
    (should (string-match-p "Return type: String" (nth 1 result)))

    ;; Third line: Method name
    (should (string-match-p "Method name: testMethod" (nth 2 result)))

    ;; Fourth line: Parameters label
    (should (string-match-p "Parameters:" (nth 3 result)))

    ;; Parameter lines (should preserve order)
    (should (string-match-p "- 0: int count" (nth 4 result)))
    (should (string-match-p "- 1: String name" (nth 5 result)))

    ;; Exceptions label
    (should (string-match-p "Exceptions:" (nth 6 result)))

    ;; Exception lines (with id starting from 0)
    (should (string-match-p "- 0: IOException" (nth 7 result)))
    (should (string-match-p "- 1: SQLException" (nth 8 result)))

    ;; IsDelegate line
    (should (string-match-p "IsDelegate: false" (nth 9 result)))

    ;; Blank line
    (should (string-empty-p (nth 10 result)))

    ;; Comment section starts with ---
    (should (string-prefix-p "---" (nth 11 result)))))

(ert-deftest eglot-jdtls--change-signature-build-content/empty-params-and-exceptions ()
  "Test building content with empty parameters and exceptions."
  (let* ((sig-info (list :modifier "public"
                         :returnType "void"
                         :methodName "simpleMethod"
                         :parameters (vector)
                         :exceptions (vector)))
         (result (eglot-jdtls--change-signature-build-content sig-info)))
    (should (listp result))
    ;; Should have: 3 basic lines + 1 params label + 0 param lines +
    ;;              1 exceptions label + 0 exception lines +
    ;;              1 IsDelegate line + 1 blank line + 1 comment line
    ;; Total: 8 lines
    (should (= (length result) 8))

    ;; First line: Access modifier
    (should (string-match-p "Access modifier: public" (car result)))

    ;; Second line: Return type
    (should (string-match-p "Return type: void" (nth 1 result)))

    ;; Third line: Method name
    (should (string-match-p "Method name: simpleMethod" (nth 2 result)))

    ;; Fourth line: Parameters label
    (should (string-match-p "Parameters:" (nth 3 result)))

    ;; Fifth line: Exceptions label (no parameter lines)
    (should (string-match-p "Exceptions:" (nth 4 result)))

    ;; Sixth line: IsDelegate (no exception lines)
    (should (string-match-p "IsDelegate: false" (nth 5 result)))

    ;; Blank line
    (should (string-empty-p (nth 6 result)))

    ;; Comment section starts with ---
    (should (string-prefix-p "---" (nth 7 result)))))

(ert-deftest eglot-jdtls--change-signature-build-content/verify-text-properties ()
  "Test that labels have read-only and face properties."
  (let* ((sig-info (list :modifier "public"
                         :returnType "String"
                         :methodName "testMethod"
                         :parameters (vector)
                         :exceptions (vector)))
         (result (eglot-jdtls--change-signature-build-content sig-info)))
    (should (listp result))

    ;; Check that label lines have text properties
    ;; Access modifier line should have read-only property
    (let ((access-modifier-line (car result)))
      (should (get-text-property 0 'read-only access-modifier-line))
      (should (eq (get-text-property 0 'face access-modifier-line) 'font-lock-keyword-face)))

    ;; Return type line should have text properties
    (let ((return-type-line (nth 1 result)))
      (should (get-text-property 0 'read-only return-type-line))
      (should (eq (get-text-property 0 'face return-type-line) 'font-lock-keyword-face)))

    ;; Method name line should have text properties
    (let ((method-name-line (nth 2 result)))
      (should (get-text-property 0 'read-only method-name-line))
      (should (eq (get-text-property 0 'face method-name-line) 'font-lock-keyword-face)))

    ;; Parameters label should have text properties
    (let ((params-label (nth 3 result)))
      (should (get-text-property 0 'read-only params-label))
      (should (eq (get-text-property 0 'face params-label) 'font-lock-keyword-face)))

    ;; Exceptions label should have text properties
    (let ((exceptions-label (nth 4 result)))
      (should (get-text-property 0 'read-only exceptions-label))
      (should (eq (get-text-property 0 'face exceptions-label) 'font-lock-keyword-face)))

    ;; IsDelegate line should have text properties
    (let ((is-delegate-line (nth 5 result)))
      (should (get-text-property 0 'read-only is-delegate-line))
      (should (eq (get-text-property 0 'face is-delegate-line) 'font-lock-keyword-face)))

    ;; Comment section should have comment face and read-only property
    (let ((comment-line (nth 7 result)))
      (should (string-prefix-p "---" comment-line))
      (should (get-text-property 0 'read-only comment-line))
      (should (eq (get-text-property 0 'face comment-line) 'font-lock-comment-face)))))

;;; Tests for eglot-jdtls--change-signature-parse-line-item

(ert-deftest eglot-jdtls--change-signature-parse-line-item/parameters-new ()
  "Test parsing a new parameter without index."
  (let* ((sig-exceptions [])
         (result (eglot-jdtls--change-signature-parse-line-item
                  "- String name"
                  'parameters
                  sig-exceptions)))
    (should result)
    (should (equal (plist-get result :type) "String"))
    (should (equal (plist-get result :name) "name"))
    ;; For new parameter (no index), defaultValue is "null"
    (should (equal (plist-get result :defaultValue) "null"))
    (should (equal (plist-get result :originalIndex) -1))))

(ert-deftest eglot-jdtls--change-signature-parse-line-item/parameters-with-index ()
  "Test parsing an existing parameter with index."
  (let* ((sig-exceptions [])
         (result (eglot-jdtls--change-signature-parse-line-item
                  "- 1: int count"
                  'parameters
                  sig-exceptions)))
    (should result)
    (should (equal (plist-get result :type) "int"))
    (should (equal (plist-get result :name) "count"))
    ;; For existing parameter (with index), defaultValue is ""
    (should (equal (plist-get result :defaultValue) ""))
    (should (equal (plist-get result :originalIndex) 1))))

(ert-deftest eglot-jdtls--change-signature-parse-line-item/parameters-with-default-value ()
  "Test parsing a parameter with default value."
  (let* ((sig-exceptions [])
         (result (eglot-jdtls--change-signature-parse-line-item
                  "- String name defaultValue"
                  'parameters
                  sig-exceptions)))
    (should result)
    (should (equal (plist-get result :type) "String"))
    (should (equal (plist-get result :name) "name"))
    ;; New parameter (no index) with explicit default value
    (should (equal (plist-get result :defaultValue) "defaultValue"))
    (should (equal (plist-get result :originalIndex) -1))))

(ert-deftest eglot-jdtls--change-signature-parse-line-item/exception-new ()
  "Test parsing a new exception without index."
  (let* ((sig-exceptions [])
         (result (eglot-jdtls--change-signature-parse-line-item
                  "- IOException"
                  'exception
                  sig-exceptions)))
    (should result)
    (should (equal (plist-get result :type) "IOException"))
    ;; New exception (no index) should not have typeHandleIdentifier
    (should (not (plist-get result :typeHandleIdentifier)))))

(ert-deftest eglot-jdtls--change-signature-parse-line-item/exception-with-index ()
  "Test parsing an existing exception with index and typeHandleIdentifier."
  (let* ((sig-exceptions [(:type "IOException" :typeHandleIdentifier "java.lang.IOException")
                          (:type "SQLException" :typeHandleIdentifier "java.sql.SQLException")])
         (result (eglot-jdtls--change-signature-parse-line-item
                  "- 0: Exception"
                  'exception
                  sig-exceptions)))
    (should result)
    (should (equal (plist-get result :type) "Exception"))
    ;; Existing exception (index 0) should have typeHandleIdentifier from sig-exceptions
    (should (equal (plist-get result :typeHandleIdentifier) "java.lang.IOException"))))

(ert-deftest eglot-jdtls--change-signature-parse-line-item/unknown-section ()
  "Test parsing with unknown section returns nil."
  (let* ((sig-exceptions [])
         (result (eglot-jdtls--change-signature-parse-line-item
                  "- String name"
                  'unknown-section
                  sig-exceptions)))
    (should (not result))))

;;; Tests for eglot-jdtls--change-signature-parse-buffer

(ert-deftest eglot-jdtls--change-signature-parse-buffer/normal-flow ()
  "Test parsing buffer with complete fields: modifier, return type, name, parameters and exceptions."
  (let* ((test-buffer (generate-new-buffer " *test-change-sig*"))
         (sig-exceptions [(:type "IOException" :typeHandleIdentifier "java.lang.IOException")
                          (:type "SQLException" :typeHandleIdentifier "java.sql.SQLException")])
         (method-id "test.method.id"))
    (unwind-protect
        (progn
          (with-current-buffer test-buffer
            (insert "Access modifier: public\n")
            (insert "Return type: String\n")
            (insert "Method name: testMethod\n")
            (insert "IsDelegate: false\n")
            (insert "Parameters:\n")
            (insert "- 0: int count\n")
            (insert "- 1: String name\n")
            (insert "Exceptions:\n")
            (insert "- 0: IOException\n")
            (insert "- 1: SQLException\n")
            (insert "\n")
            (insert "--- Keys: C-c C-c to confirm, C-c C-r to reset, C-c C-k to cancel ---\n"))

          (let ((result (eglot-jdtls--change-signature-parse-buffer
                         test-buffer method-id sig-exceptions)))
            ;; Result should be a vector
            (should (vectorp result))
            ;; Vector should have 8 elements: method-id, is-delegate, method-name,
            ;; access-modifier, return-type, parameters, exceptions, generate-guards
            (should (= (length result) 8))

            ;; First element: method-id
            (should (equal (aref result 0) method-id))

            ;; Second element: is-delegate (should be :json-false for "false")
            (should (eq (aref result 1) :json-false))

            ;; Third element: method-name
            (should (equal (aref result 2) "testMethod"))

            ;; Fourth element: access-modifier
            (should (equal (aref result 3) "public"))

            ;; Fifth element: return-type
            (should (equal (aref result 4) "String"))

            ;; Sixth element: parameters (should be a vector)
            (should (vectorp (aref result 5)))
            (should (= (length (aref result 5)) 2))
            ;; First parameter: index 0, int count
            (let ((param1 (aref (aref result 5) 0)))
              (should (equal (plist-get param1 :type) "int"))
              (should (equal (plist-get param1 :name) "count"))
              (should (equal (plist-get param1 :originalIndex) 0))
              (should (equal (plist-get param1 :defaultValue) "")))
            ;; Second parameter: index 1, String name
            (let ((param2 (aref (aref result 5) 1)))
              (should (equal (plist-get param2 :type) "String"))
              (should (equal (plist-get param2 :name) "name"))
              (should (equal (plist-get param2 :originalIndex) 1))
              (should (equal (plist-get param2 :defaultValue) "")))

            ;; Seventh element: exceptions (should be a vector)
            (should (vectorp (aref result 6)))
            (should (= (length (aref result 6)) 2))
            ;; First exception: index 0, IOException with typeHandleIdentifier
            (let ((exc1 (aref (aref result 6) 0)))
              (should (equal (plist-get exc1 :type) "IOException"))
              (should (equal (plist-get exc1 :typeHandleIdentifier) "java.lang.IOException")))
            ;; Second exception: index 1, SQLException with typeHandleIdentifier
            (let ((exc2 (aref (aref result 6) 1)))
              (should (equal (plist-get exc2 :type) "SQLException"))
              (should (equal (plist-get exc2 :typeHandleIdentifier) "java.sql.SQLException")))

            ;; Eighth element: generate-guards (should be :json-false)
            (should (eq (aref result 7) :json-false))))
      (kill-buffer test-buffer))))

(ert-deftest eglot-jdtls--change-signature-parse-buffer/empty-params-and-exceptions ()
  "Test parsing buffer with no parameters and no exceptions."
  (let* ((test-buffer (generate-new-buffer " *test-change-sig*"))
         (sig-exceptions [])
         (method-id "test.simple.method"))
    (unwind-protect
        (progn
          (with-current-buffer test-buffer
            (insert "Access modifier: private\n")
            (insert "Return type: void\n")
            (insert "Method name: simpleMethod\n")
            (insert "IsDelegate: false\n")
            (insert "Parameters:\n")
            (insert "Exceptions:\n")
            (insert "\n")
            (insert "--- Keys: C-c C-c to confirm, C-c C-r to reset, C-c C-k to cancel ---\n"))

          (let ((result (eglot-jdtls--change-signature-parse-buffer
                         test-buffer method-id sig-exceptions)))
            ;; Result should be a vector
            (should (vectorp result))
            ;; Vector should have 8 elements
            (should (= (length result) 8))

            ;; First element: method-id
            (should (equal (aref result 0) method-id))

            ;; Second element: is-delegate
            (should (eq (aref result 1) :json-false))

            ;; Third element: method-name
            (should (equal (aref result 2) "simpleMethod"))

            ;; Fourth element: access-modifier
            (should (equal (aref result 3) "private"))

            ;; Fifth element: return-type
            (should (equal (aref result 4) "void"))

            ;; Sixth element: parameters (should be empty vector)
            (should (vectorp (aref result 5)))
            (should (= (length (aref result 5)) 0))

            ;; Seventh element: exceptions (should be empty vector)
            (should (vectorp (aref result 6)))
            (should (= (length (aref result 6)) 0))

            ;; Eighth element: generate-guards
            (should (eq (aref result 7) :json-false))))
      (kill-buffer test-buffer))))

(ert-deftest eglot-jdtls--change-signature-parse-buffer/is-delegate-true ()
  "Test parsing buffer with IsDelegate set to true."
  (let* ((test-buffer (generate-new-buffer " *test-change-sig*"))
         (sig-exceptions [])
         (method-id "delegate.method.id"))
    (unwind-protect
        (progn
          (with-current-buffer test-buffer
            (insert "Access modifier: public\n")
            (insert "Return type: ActionListener\n")
            (insert "Method name: actionPerformed\n")
            (insert "IsDelegate: true\n")
            (insert "Parameters:\n")
            (insert "- 0: ActionEvent e\n")
            (insert "Exceptions:\n")
            (insert "\n")
            (insert "--- Keys: C-c C-c to confirm, C-c C-r to reset, C-c C-k to cancel ---\n"))

          (let ((result (eglot-jdtls--change-signature-parse-buffer
                         test-buffer method-id sig-exceptions)))
            ;; Result should be a vector
            (should (vectorp result))
            ;; Vector should have 8 elements
            (should (= (length result) 8))

            ;; First element: method-id
            (should (equal (aref result 0) method-id))

            ;; Second element: is-delegate (should be t for "true")
            (should (eq (aref result 1) t))

            ;; Third element: method-name
            (should (equal (aref result 2) "actionPerformed"))

            ;; Fourth element: access-modifier
            (should (equal (aref result 3) "public"))

            ;; Fifth element: return-type
            (should (equal (aref result 4) "ActionListener"))

            ;; Sixth element: parameters
            (should (vectorp (aref result 5)))
            (should (= (length (aref result 5)) 1))
            (let ((param1 (aref (aref result 5) 0)))
              (should (equal (plist-get param1 :type) "ActionEvent"))
              (should (equal (plist-get param1 :name) "e"))
              (should (equal (plist-get param1 :originalIndex) 0))
              (should (equal (plist-get param1 :defaultValue) "")))

            ;; Seventh element: exceptions (should be empty vector)
            (should (vectorp (aref result 6)))
            (should (= (length (aref result 6)) 0))

            ;; Eighth element: generate-guards
            (should (eq (aref result 7) :json-false))))
      (kill-buffer test-buffer))))

(ert-deftest eglot-jdtls--change-signature-parse-buffer/only-basic-fields ()
  "Test parsing buffer with only basic fields and no parameter/exception sections."
  (let* ((test-buffer (generate-new-buffer " *test-change-sig*"))
         (sig-exceptions [])
         (method-id "basic.method.id"))
    (unwind-protect
        (progn
          (with-current-buffer test-buffer
            (insert "Access modifier: protected\n")
            (insert "Return type: boolean\n")
            (insert "Method name: isValid\n")
            (insert "IsDelegate: false\n")
            (insert "\n")
            (insert "--- Keys: C-c C-c to confirm, C-c C-r to reset, C-c C-k to cancel ---\n"))

          (let ((result (eglot-jdtls--change-signature-parse-buffer
                         test-buffer method-id sig-exceptions)))
            ;; Result should be a vector
            (should (vectorp result))
            ;; Vector should have 8 elements
            (should (= (length result) 8))

            ;; First element: method-id
            (should (equal (aref result 0) method-id))

            ;; Second element: is-delegate
            (should (eq (aref result 1) :json-false))

            ;; Third element: method-name
            (should (equal (aref result 2) "isValid"))

            ;; Fourth element: access-modifier
            (should (equal (aref result 3) "protected"))

            ;; Fifth element: return-type
            (should (equal (aref result 4) "boolean"))

            ;; Sixth element: parameters (should be empty vector)
            (should (vectorp (aref result 5)))
            (should (= (length (aref result 5)) 0))

            ;; Seventh element: exceptions (should be empty vector)
            (should (vectorp (aref result 6)))
            (should (= (length (aref result 6)) 0))

            ;; Eighth element: generate-guards
            (should (eq (aref result 7) :json-false))))
      (kill-buffer test-buffer))))

;;; Tests for eglot-jdtls--change-signature-send-request

(ert-deftest eglot-jdtls--change-signature-send-request/normal ()
  "Test eglot-jdtls--change-signature-send-request with successful edit."
  (let ((mock-server (make-hash-table :test 'equal))
        (success-called nil)
        (refactor-edit-called nil)
        (window-deleted nil)
        (buffer-killed nil)
        (test-cmd "changeSignature")
        (test-params '(:location "test.java"))
        (test-cmd-params '(:parameters []))
        (test-edit '(:changes [(:range (:start (:line 1 :character 0)
                                              :end (:line 1 :character 10))
                                 :newText "new text")])))
    (cl-letf* (((symbol-function 'jsonrpc-async-request)
                (lambda (server method params &rest args)
                  (let ((success-fn (plist-get args :success-fn))
                        (error-fn (plist-get args :error-fn)))
                    ;; Verify request parameters
                    (should (equal method :java/getRefactorEdit))
                    (should (equal (plist-get params :command) test-cmd))
                    (should (equal (plist-get params :context) test-params))
                    (should (equal (plist-get params :commandArguments) test-cmd-params))
                    (setq success-called t)
                    ;; Simulate success callback
                    (funcall success-fn (list :edit test-edit)))))
               ((symbol-function 'eglot-jdtls--format-options)
                (lambda () '(:command "organizeImports")))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal (plist-get result :edit) test-edit))))
               ((symbol-function 'window-live-p)
                (lambda (window) (eq window 'test-window)))
               ((symbol-function 'buffer-live-p)
                (lambda (buffer) (eq buffer 'test-buffer)))
               ((symbol-function 'delete-window)
                (lambda (window)
                  (setq window-deleted t)
                  (should (eq window 'test-window))))
               ((symbol-function 'kill-buffer)
                (lambda (buffer)
                  (setq buffer-killed t)
                  (should (eq buffer 'test-buffer)))))
      (eglot-jdtls--change-signature-send-request
       mock-server test-cmd test-params test-cmd-params
       'test-window 'test-buffer)
      ;; Verify callbacks were called
      (should success-called)
      (should refactor-edit-called)
      (should window-deleted)
      (should buffer-killed))))

(ert-deftest eglot-jdtls--change-signature-send-request/error ()
  "Test eglot-jdtls--change-signature-send-request with error response."
  (let ((mock-server (make-hash-table :test 'equal))
        (error-called nil)
        (error-message-content nil)
        (test-cmd "changeSignature")
        (test-params '(:location "test.java"))
        (test-cmd-params '(:parameters []))
        (test-error "Refactoring failed"))
    (cl-letf* (((symbol-function 'jsonrpc-async-request)
                (lambda (server method params &rest args)
                  (let ((success-fn (plist-get args :success-fn))
                        (error-fn (plist-get args :error-fn)))
                    ;; Verify request parameters
                    (should (equal method :java/getRefactorEdit))
                    (should (equal (plist-get params :command) test-cmd))
                    (should (equal (plist-get params :context) test-params))
                    (should (equal (plist-get params :commandArguments) test-cmd-params))
                    ;; Simulate error callback
                    (setq error-called t)
                    (funcall error-fn (list :message test-error)))))
               ((symbol-function 'eglot-jdtls--format-options)
                (lambda () '(:command "organizeImports")))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq error-message-content (apply #'format format-string args)))))
      (eglot-jdtls--change-signature-send-request
       mock-server test-cmd test-params test-cmd-params
       nil nil)
      ;; Verify error was called
      (should error-called)
      ;; Verify error message content contains expected error
      (should error-message-content)
      (should (string-match test-error error-message-content)))))

(ert-deftest eglot-jdtls--change-signature-send-request/empty-edit ()
  "Test eglot-jdtls--change-signature-send-request with empty edit result."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-cmd "changeSignature")
        (test-params '(:location "test.java"))
        (test-cmd-params '(:parameters []))
        ;; Empty edit - changes key exists but is nil, no documentChanges key
        (test-edit '(:changes nil))
        (refactor-edit-called nil)
        (window-deleted nil)
        (buffer-killed nil))
    (cl-letf* (((symbol-function 'jsonrpc-async-request)
                (lambda (server method params &rest args)
                  (let ((success-fn (plist-get args :success-fn)))
                    ;; Verify request parameters
                    (should (equal method :java/getRefactorEdit))
                    (should (equal (plist-get params :command) test-cmd))
                    (should (equal (plist-get params :context) test-params))
                    (should (equal (plist-get params :commandArguments) test-cmd-params))
                    ;; Simulate success callback with empty edit
                    (funcall success-fn (list :edit test-edit)))))
               ((symbol-function 'eglot-jdtls--format-options)
                (lambda () '(:command "organizeImports")))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (_server _result)
                  (setq refactor-edit-called t)))
               ((symbol-function 'window-live-p)
                (lambda (_window) t))
               ((symbol-function 'buffer-live-p)
                (lambda (_buffer) t))
               ((symbol-function 'delete-window)
                (lambda (_window)
                  (setq window-deleted t)))
               ((symbol-function 'kill-buffer)
                (lambda (_buffer)
                  (setq buffer-killed t))))
      (eglot-jdtls--change-signature-send-request
       mock-server test-cmd test-params test-cmd-params
       'test-window 'test-buffer)
      ;; Verify refactor-edit was NOT called (empty edit case)
      (should (not refactor-edit-called))
      ;; Verify window and buffer were NOT cleaned up
      (should (not window-deleted))
      (should (not buffer-killed)))))

(ert-deftest eglot-jdtls--change-signature/normal-flow ()
  "Test eglot-jdtls--change-signature - get signature info, create buffer and switch."
  (let* ((mock-server (make-hash-table :test 'equal))
         (test-params (list :uri "file:///test.java"))
         (test-arguments (vector "changeSignature" test-params))
         (test-sig-info
          (list :modifier "public"
                :returnType "void"
                :methodName "testMethod"
                :methodIdentifier "testMethod(Ljava/lang/String;)V"
                :parameters (vector (list :type "String" :name "name" :originalIndex 0))
                :exceptions (vector (list :type "IOException" :typeHandleIdentifier "IOExceptionId"))
                :isDelegate :json-false))
         (mock-lines '("Access modifier: public"
                       "Return type: void"
                       "Method name: testMethod"
                       "Parameters:"
                       "- 0: String name"
                       "Exceptions:"
                       "- 0: IOException"
                       "IsDelegate: false"
                       ""
                       "---"))
         (setup-buffer-called nil)
         (switch-to-buffer-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (cond
                   ((eq method :java/getChangeSignatureInfo)
                    test-sig-info)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--change-signature-build-content)
                (lambda (sig-info)
                  (should (equal sig-info test-sig-info))
                  mock-lines))
               ((symbol-function 'eglot-jdtls--change-signature-setup-buffer)
                (lambda (buf lines sig-info server cmd params)
                  (setq setup-buffer-called t)
                  (should (bufferp buf))
                  (should (equal lines mock-lines))
                  (should (equal sig-info test-sig-info))
                  (should (equal server mock-server))
                  (should (equal cmd "changeSignature"))
                  (should (equal params test-params))))
               ((symbol-function 'switch-to-buffer-other-window)
                (lambda (buf)
                  (setq switch-to-buffer-called t)
                  (should (bufferp buf)))))
      (eglot-jdtls--change-signature mock-server test-arguments)
      (should setup-buffer-called)
      (should switch-to-buffer-called))))

(ert-deftest eglot-jdtls--change-signature/error-message ()
  "Test eglot-jdtls--change-signature - getChangeSignatureInfo returns errorMessage."
  (let* ((mock-server (make-hash-table :test 'equal))
         (test-params (list :uri "file:///test.java"))
         (test-arguments (vector "changeSignature" test-params))
         (test-sig-info (list :errorMessage "Cannot change signature: method not found"))
         (message-called nil)
         (message-content nil)
         (setup-buffer-called nil)
         (switch-to-buffer-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest _args)
                  (cond
                   ((eq method :java/getChangeSignatureInfo)
                    test-sig-info)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args))))
               ((symbol-function 'eglot-jdtls--change-signature-build-content)
                (lambda (_sig-info)
                  (setq setup-buffer-called t)
                  '()))
               ((symbol-function 'eglot-jdtls--change-signature-setup-buffer)
                (lambda (&rest _args)
                  (setq setup-buffer-called t)))
               ((symbol-function 'switch-to-buffer-other-window)
                (lambda (&rest _args)
                  (setq switch-to-buffer-called t))))
      (eglot-jdtls--change-signature mock-server test-arguments)
      ;; Verify message was called with the error
      (should message-called)
      (should (string= message-content "Cannot change signature: method not found"))
      ;; Verify buffer setup was NOT called (error case)
      (should (not setup-buffer-called))
      ;; Verify switch-to-buffer was NOT called (error case)
      (should (not switch-to-buffer-called)))))

;;; Tests for eglot-jdtls--resolve-scopes

(ert-deftest eglot-jdtls--resolve-scopes ()
  "Test eglot-jdtls--resolve-scopes with various scenarios."
  (let ((test-cases
         '(;; (scopes expected-result description)
           ([] nil "empty list")
           (["currentScope"] "currentScope" "single element")
           (["scope1" "scope2" "scope3"] "selected-scope" "multiple elements"))))
    (dolist (test-case test-cases)
      (pcase-let* ((`(,scopes ,expected ,_desc) test-case))
        (cond
         ;; Empty list - returns nil directly
         ((= (length scopes) 0)
          (should (equal (eglot-jdtls--resolve-scopes scopes) expected)))
         ;; Single element - returns the element directly
         ((= (length scopes) 1)
          (should (equal (eglot-jdtls--resolve-scopes scopes) expected)))
         ;; Multiple elements - requires mock completing-read
         (t
          (cl-letf* (((symbol-function 'completing-read)
                      (lambda (_prompt _collection &rest _args)
                        "selected-scope")))
            (should (equal (eglot-jdtls--resolve-scopes scopes) expected)))))))))


;;; Tests for eglot-jdtls--get-expression

(ert-deftest eglot-jdtls--get-expression/empty-list ()
  "Test eglot-jdtls--get-expression with empty expression list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-params '(:offset 10)))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (should (equal method :java/inferSelection))
                  [])))
      (let ((result (eglot-jdtls--get-expression "extractMethod" test-params mock-server)))
        (should (not result))))))

(ert-deftest eglot-jdtls--get-expression/single-expression ()
  "Test eglot-jdtls--get-expression with single expression."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-params '(:offset 10)))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (_server method &rest _args)
                  (should (equal method :java/inferSelection))
                  [(:name "myExpression" :params "someParams")])))
      (let ((result (eglot-jdtls--get-expression "extractMethod" test-params mock-server)))
        (should (equal result '(:name "myExpression" :params "someParams")))))))

(ert-deftest eglot-jdtls--get-expression/multiple-expressions ()
  "Test eglot-jdtls--get-expression with multiple expressions."
  (let ((test-cases
         '(;; (cmd expected-prompt-fragment description)
           ("extractMethod" "extract to method:" "extractMethod prompt")
           ("extractVariable" "extract to variable:" "extractVariable prompt")
           ("extractVariableAllOccurrence" "extract to variable:" "extractVariableAllOccurrence prompt")
           ("extractConstant" "extract to constant:" "extractConstant prompt")
           ("extractField" "extract to field:" "extractField prompt")))
        (test-params '(:offset 10))
        (test-expressions [(:name "expr1") (:name "expr2")])
        (selected-expression '(:name "expr2")))

    (dolist (test-case test-cases)
      (pcase-let* ((`(,cmd ,expected-prompt ,_desc) test-case))
        (let ((mock-server (make-hash-table :test 'equal))
              (select-called nil)
              (select-prompt nil))
          (cl-letf* (((symbol-function 'jsonrpc-request)
                      (lambda (_server method &rest _args)
                        (should (equal method :java/inferSelection))
                        test-expressions))
                     ((symbol-function 'eglot-jdtls--select)
                      (lambda (expressions prompt display-fn &rest _args)
                        (setq select-called t)
                        (setq select-prompt prompt)
                        (should (equal expressions test-expressions))
                        selected-expression)))
            (let ((result (eglot-jdtls--get-expression cmd test-params mock-server)))
              (should select-called)
              (should (string-match expected-prompt select-prompt))
              (should (equal result selected-expression)))))))))



;;; Tests for eglot-jdtls--extract-interface

(ert-deftest eglot-jdtls--extract-interface/normal-flow ()
  "Test eglot-jdtls--extract-interface - normal flow with member selection and destination package."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments ["extractInterface"
                         (:textDocument (:uri "file:///test/MyService.java"))
                         (:displayName "extractInterface"
                          :projectName "test-project")])
        (selected-members (vector "member1" "member2"))
        (selected-destination "/src/com/example")
        (interface-name "MyInterface")
        (refactor-result
         '(:edit (:documentChanges [(:kind "create"
                                       :uri "file:///test/com/example/MyInterface.java")])))
        (jsonrpc-request-calls nil)
        (get-refactor-params nil)
        (refactor-edit-called nil)
        (find-file-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (push (list server method) jsonrpc-request-calls)
                  (cond
                   ((eq method :java/checkExtractInterfaceStatus)
                    (list :members
                          [(:name "doSomething" :typeName "String" :parameters ["String" "int"] :handleIdentifier "member1")
                           (:name "processData" :typeName "void" :parameters ["List"] :handleIdentifier "member2")]
                          :subTypeName "MyInterface"
                          :destinationResponse
                          (list :destinations
                                [(:displayName "com.example" :path "/src/com/example")
                                 (:displayName "com.example.impl" :path "/src/com/example/impl")])))
                   ((eq method :java/getRefactorEdit)
                    (setq get-refactor-params (car args))
                    refactor-result)
                   (t (error "Unexpected method: %s" method)))))
               ((symbol-function 'eglot-jdtls--select)
                (lambda (items prompt display-fn &rest _args)
                  (cond
                   ((string-match "Select members:" prompt)
                    ;; Verify display format
                    (let ((display-calls (mapcar display-fn (append items nil))))
                      (should (member "doSomething(String, int) String" display-calls))
                      (should (member "processData(List) void" display-calls)))
                    selected-members)
                   ((string-match "Specify package:" prompt)
                    ;; Verify items is destinations vector
                    (should (vectorp items))
                    (should (= (length items) 2))
                    selected-destination)
                   (t (error "Unexpected prompt: %s" prompt)))))
               ((symbol-function 'read-string)
                (lambda (prompt &optional initial)
                  (should (string-match "Specify interface name:" prompt))
                  (should (equal initial "MyInterface"))
                  interface-name))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (should (equal result refactor-result))))
               ((symbol-function 'eglot-uri-to-path)
                (lambda (uri)
                  (should (equal uri "file:///test/com/example/MyInterface.java"))
                  "/test/com/example/MyInterface.java"))
               ((symbol-function 'file-exists-p)
                (lambda (file)
                  (should (equal file "/test/com/example/MyInterface.java"))
                  t))
               ((symbol-function 'find-file-other-window)
                (lambda (file)
                  (setq find-file-called t)
                  (should (equal file "/test/com/example/MyInterface.java")))))
      (eglot-jdtls--extract-interface mock-server test-arguments)
      ;; Verify jsonrpc-request calls
      (should (member :java/checkExtractInterfaceStatus (mapcar #'cadr jsonrpc-request-calls)))
      (should (member :java/getRefactorEdit (mapcar #'cadr jsonrpc-request-calls)))
      ;; Verify getRefactorEdit parameters
      (should get-refactor-params)
      (should (equal (plist-get get-refactor-params :command) "extractInterface"))
      (should (equal (plist-get get-refactor-params :commandArguments)
                     (vconcat (vector selected-members interface-name selected-destination))))
      ;; Verify refactor-edit was called
      (should refactor-edit-called)
      ;; Verify find-file-other-window was called
      (should find-file-called))))


(ert-deftest eglot-jdtls--extract-interface/empty-members ()
  "Test eglot-jdtls--extract-interface with empty members list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments ["extractInterface"
                         (:textDocument (:uri "file:///test/MyService.java"))
                         (:displayName "extractInterface"
                          :projectName "test-project")])
        (message-called nil)
        (message-content nil)
        (jsonrpc-request-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (setq jsonrpc-request-called t)
                  (should (eq method :java/checkExtractInterfaceStatus))
                  (list :members
                        []
                        :subTypeName "MyInterface"
                        :destinationResponse
                        (list :destinations
                              [(:displayName "com.example" :path "/src/com/example")]))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args)))))
      (eglot-jdtls--extract-interface mock-server test-arguments)
      ;; Verify message was called
      (should message-called)
      (should (string-match "Cannot find available members" message-content))
      ;; Verify jsonrpc-request was called
      (should jsonrpc-request-called))))

(ert-deftest eglot-jdtls--extract-interface/empty-destinations ()
  "Test eglot-jdtls--extract-interface with empty destinations list."
  (let ((mock-server (make-hash-table :test 'equal))
        (test-arguments ["extractInterface"
                         (:textDocument (:uri "file:///test/MyService.java"))
                         (:displayName "extractInterface"
                          :projectName "test-project")])
        (message-called nil)
        (message-content nil)
        (jsonrpc-request-called nil))
    (cl-letf* (((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (setq jsonrpc-request-called t)
                  (should (eq method :java/checkExtractInterfaceStatus))
                  (list :members
                        [(:name "doSomething" :typeName "String" :parameters ["String" "int"] :handleIdentifier "member1")]
                        :subTypeName "MyInterface"
                        :destinationResponse
                        (list :destinations
                              []))))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (setq message-called t)
                  (setq message-content (apply #'format format-string args)))))
      (eglot-jdtls--extract-interface mock-server test-arguments)
      ;; Verify message was called
      (should message-called)
      (should (string-match "Cannot find available Java packages" message-content))
      ;; Verify jsonrpc-request was called
      (should jsonrpc-request-called))))


;;; Tests for eglot-jdtls--apply-refactoring-command

(ert-deftest test-eglot-jdtls-apply-refactoring-command-dispatch ()
  "Test that eglot-jdtls--apply-refactoring-command dispatches to correct handlers."
  (let ((mock-server (make-hash-table :test 'equal))
        (dispatched-handler nil))

    ;; Test case 1: moveFile command
    (cl-letf* (((symbol-function 'eglot-jdtls--move-file)
                (lambda (&rest _args)
                  (setq dispatched-handler 'eglot-jdtls--move-file)))
               ((symbol-function 'eglot-jdtls--instant-method)
                (lambda (&rest _args)
                  (setq dispatched-handler 'eglot-jdtls--instant-method)))
               ((symbol-function 'eglot-jdtls--move-static-member)
                (lambda (&rest _args)
                  (setq dispatched-handler 'eglot-jdtls--move-static-member)))
               ((symbol-function 'eglot-jdtls--move-type)
                (lambda (&rest _args)
                  (setq dispatched-handler 'eglot-jdtls--move-type)))
               ((symbol-function 'eglot-jdtls--change-signature)
                (lambda (&rest _args)
                  (setq dispatched-handler 'eglot-jdtls--change-signature)))
               ((symbol-function 'eglot-jdtls--extract-interface)
                (lambda (&rest _args)
                  (setq dispatched-handler 'eglot-jdtls--extract-interface))))

      ;; Test each command type
      (dolist (test-case '(("moveFile" . eglot-jdtls--move-file)
                           ("moveInstanceMethod" . eglot-jdtls--instant-method)
                           ("moveStaticMember" . eglot-jdtls--move-static-member)
                           ("moveType" . eglot-jdtls--move-type)
                           ("changeSignature" . eglot-jdtls--change-signature)
                           ("extractInterface" . eglot-jdtls--extract-interface)))
        (setq dispatched-handler nil)
        (let ((cmd (car test-case))
              (expected-handler (cdr test-case)))
          (eglot-jdtls--apply-refactoring-command mock-server (vector cmd nil))
          (should (equal dispatched-handler expected-handler)))))))

(ert-deftest test-eglot-jdtls-apply-refactoring-command-unknown-command ()
  "Test that eglot-jdtls--apply-refactoring-command returns nil for unknown commands."
  (let ((mock-server (make-hash-table :test 'equal)))
    (cl-letf* (((symbol-function 'eglot-jdtls--move-file)
                (lambda (&rest _args)
                  (error "Should not be called"))))
      (let ((result (eglot-jdtls--apply-refactoring-command mock-server (vector "unknownCommand" nil))))
        (should (not result))))))

(ert-deftest test-eglot-jdtls-apply-refactoring-command-extract-method ()
  "Test extractMethod command calls :java/getRefactorEdit in non-region mode."
  (let ((mock-server (make-hash-table :test 'equal))
        (jsonrpc-request-called nil)
        (jsonrpc-request-args nil)
        (refactor-edit-called nil)
        (refactor-edit-result nil)
        (test-params '(:textDocument (:uri "file:///test/Test.java")
                        :range (:start (:line 0 :character 0)
                                :end (:line 0 :character 10))))
        (test-expression '(:name "myMethod" :params [] :bounds (:start (:line 0 :character 0) :end (:line 0 :character 10)))))

    (cl-letf* (((symbol-function 'use-region-p)
                (lambda ()
                  nil))  ; Non-region mode
               ((symbol-function 'eglot-jdtls--get-expression)
                (lambda (cmd params server)
                  ;; Should be called with extractMethod command
                  (should (equal cmd "extractMethod"))
                  (should (equal params test-params))
                  test-expression))
               ((symbol-function 'jsonrpc-request)
                (lambda (server method &rest args)
                  (setq jsonrpc-request-called t)
                  (setq jsonrpc-request-args (list server method args))
                  ;; Return a mock refactor edit result
                  '(:changes [])))
               ((symbol-function 'eglot-jdtls--refactor-edit)
                (lambda (server result)
                  (setq refactor-edit-called t)
                  (setq refactor-edit-result result))))

      (eglot-jdtls--apply-refactoring-command mock-server (vector "extractMethod" test-params))

      ;; Verify jsonrpc-request was called
      (should jsonrpc-request-called)

      ;; Verify the method was :java/getRefactorEdit
      (should (eq (nth 1 jsonrpc-request-args) :java/getRefactorEdit))

      ;; Verify the arguments contain the command and expression
      (let ((request-args (car (nth 2 jsonrpc-request-args))))
        (should (equal (plist-get request-args :command) "extractMethod"))
        ;; commandArguments should be a vector containing the expression
        (should (vectorp (plist-get request-args :commandArguments)))
        (should (equal (aref (plist-get request-args :commandArguments) 0) test-expression))
        (should (equal (plist-get request-args :context) test-params)))

      ;; Verify eglot-jdtls--refactor-edit was called with the result
      (should refactor-edit-called)
      (should (equal refactor-edit-result '(:changes []))))))


;;; Tests for eglot--apply-workspace-edit signature compatibility

(ert-deftest eglot-jdtls--apply-edit/new-signature ()
  "Test eglot-jdtls--apply-edit passes SERVER for eglot >= 1.24."
  (let ((eglot-jdtls--apply-edit-takes-server-p t)
        (calls nil))
    (cl-letf* (((symbol-function 'eglot--apply-workspace-edit)
                (lambda (server wedit origin)
                  (push (list server wedit origin) calls))))
      (eglot-jdtls--apply-edit 'server '(:edit) 'this-command)
      (should (equal calls (list (list 'server '(:edit) 'this-command)))))))

(ert-deftest eglot-jdtls--apply-edit/old-signature ()
  "Test eglot-jdtls--apply-edit drops SERVER for eglot <= 1.23."
  (let ((eglot-jdtls--apply-edit-takes-server-p nil)
        (calls nil))
    (cl-letf* (((symbol-function 'eglot--apply-workspace-edit)
                (lambda (wedit origin)
                  (push (list wedit origin) calls))))
      (eglot-jdtls--apply-edit 'server '(:edit :origin) 'this-command)
      (should (equal calls (list (list '(:edit :origin) 'this-command)))))))


(provide 'eglot-jdtls-test)
;;; eglot-jdtls-test.el ends here
