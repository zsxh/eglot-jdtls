;;; eglot-jdtls.el ---   -*- lexical-binding: t; -*-

;; Copyright (C) 2026  zsxh

;; Author: zsxh <bnbvbchen@gmail.com>
;; Maintainer: zsxh <bnbvbchen@gmail.com>
;; URL: https://github.com/zsxh/eglot-jdtls
;; Version: 0.0.1
;; Package-Requires: ((emacs "30.2") (compat "30.1.0.0") (eglot "1.17.30") (jsonrpc "1.0.24"))
;; Keywords: eglot jdtls

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
;;
;;

;;; Code:

(require 'cl-lib)
(require 'compat)
(require 'eglot)
(require 'jsonrpc)


(defgroup eglot-jdtls nil
  "Settings for Eclipse JDT Language Server integration with Eglot."
  :group 'eglot
  :prefix "eglot-jdtls-"
  :link '(url-link :tag "GitHub" "https://github.com/zsxh/eglot-jdtls"))

(defclass eglot-jdtls-server (eglot-lsp-server)
  ()
  :documentation "eclipse's jdt langserver."
  :group 'eglot-jdtls)

;; Variables

(defcustom eglot-jdtls-cache-dir
  (expand-file-name "eglot-java" (temporary-file-directory))
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
    :settings nil
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

;; Eglot jdtls config

(defun eglot-jdtls-cmd (_interactive)
  "Return the JDT Language Server command for Eglot."
  (let ((cmd (or (plist-get eglot-jdtls-config :cmd)
                 (plist-get eglot-jdtls--default-config :cmd))))
    (cond
     ((functionp cmd)
      (funcall cmd))
     ((listp cmd)
      (let ((program (car cmd))
            (args (cdr cmd)))
        (cons (executable-find program) args)))
     (t
      (user-error "[eglot-jdtls] eglot-jdtls-config :cmd should be either a function or list")))))

(cl-defmethod eglot-initialization-options ((server eglot-jdtls-server))
  "Return initialization options for JDT LS SERVER."
  (let* ((init-options (plist-get eglot-jdtls-config :init-options))
         (default-init-options (plist-get eglot-jdtls--default-config :init-options))
         (bundles (or (plist-get init-options :bundles)
                      (plist-get default-init-options :bundles)))
         (extendedClientCapabilities (or (plist-get init-options :extendedClientCapabilities)
                                         (plist-get default-init-options :extendedClientCapabilities)))
         (settings (or (plist-get eglot-jdtls-config :settings)
                       (plist-get eglot-jdtls--default-config :settings))))
    (list
     :settings settings
     :extendedClientCapabilities extendedClientCapabilities
     :bundles bundles)))

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
                     (cl-loop for (mode . languageid) in
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
         (_ (string-match "jdt://contents/\\(.*?\\)/\\(.*\\)\.class\\?" uri))
         (jar-file (substring uri (match-beginning 1) (match-end 1)))
         (java-file (format "%s.java" (replace-regexp-in-string "/" "." (substring uri (match-beginning 2) (match-end 2)) t t)))
         (jar-dir (concat (file-name-as-directory cache-dir)
                          (file-name-as-directory jar-file)))
         (source-file (expand-file-name (concat jar-dir java-file))))
    (unless (file-readable-p source-file)
      (let ((content (jsonrpc-request
                      (or (eglot-current-server)
                          ;; NOTE: dape https://github.com/svaante/dape/issues/78#issuecomment-1966786597
                          (eglot-jdtls--find-jdt-server))
                      :java/classFileContents (list :uri uri))))
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
  "Apply workspace edit(s) from JDT LS command `java.apply.workspaceEdit'.

ARGUMENTS is a list of workspace edit objects to apply."
  (mapc #'eglot--apply-workspace-edit arguments this-command))

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
                              (pcase-let* (((map :name
                                                 :parameters
                                                 :declaringClass) method))
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

(defun eglot-jdlts--show-references (command arguments)
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
              (y-or-n-p "The toString() method already exists. Replace?"))
      (let* ((selected-fields (eglot-jdtls--select
                               fields
                               "Select fields to include: "
                               (lambda (field)
                                 (pcase-let* (((map :name :type) field))
                                   (format "%s: %s" name type)))
                               t))
             (generate-result (jsonrpc-request
                               server :java/generateToString
                               (list :fields selected-fields
                                     :context params))))
        (eglot--apply-workspace-edit generate-result this-command)))))

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
              (y-or-n-p (format "The %s method already exists. Replace?"
                                existingMethods)))
      (let* ((selected-fields (eglot-jdtls--select
                               fields
                               "Select fields to include: "
                               (lambda (field)
                                 (pcase-let* (((map :name :type) field))
                                   (format "%s: %s" name type)))
                               t))
             (generate-result (jsonrpc-request
                               server :java/generateHashCodeEquals
                               (list
                                :fields selected-fields
                                :context params
                                :regenerate (not (seq-empty-p existingMethods))))))
        (eglot--apply-workspace-edit generate-result this-command)))))

(defun eglot-jdtls--generate-accessors-prompt (server arguments)
  "Prompt user to generate accessor methods (getters and setters) for Java fields.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (let* ((params (seq-elt arguments 0))
         (accessorFields (jsonrpc-request
                          server :java/resolveUnimplementedAccessors
                          params))
         (selected-accessors (eglot-jdtls--select
                              accessorFields
                              "Select fields to generate: "
                              (lambda (field)
                                (pcase-let* (((map :fieldName :typeName) field))
                                  (format "%s: %s" fieldName typeName)))
                              t))
         (generate-result (jsonrpc-request
                           server :java/generateAccessors
                           (list :accessors selected-accessors
                                 :context params))))
    (eglot--apply-workspace-edit generate-result this-command)))

(defun eglot-jdtls-generate-constructors-prompt (server arguments)
  "Prompt user to generate constructors for Java class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing context information for the class."
  (pcase-let* ((params (seq-elt arguments 0))
               (check-resp (jsonrpc-request
                            server :java/checkConstructorsStatus
                            params))
               ((map :constructors :fields) check-resp)
               (selected-constructors (eglot-jdtls--select
                                       constructors
                                       "Select constructors to generate: "
                                       (lambda (constructor)
                                         (pcase-let* (((map :name :parameters) field))
                                           (format "%s(%s)" name (mapconcat #'identity parameters ", "))))
                                       t))
               (selected-fields (eglot-jdtls--select
                                 fields
                                 "Select fields to generate: "
                                 (lambda (field)
                                   (pcase-let* (((map :name :type) field))
                                     (format "%s: %s" name type)))
                                 t))
               (generate-result (jsonrpc-request server :java/generateConstructors
                                                 (list :context params
                                                       :constructors selected-constructors
                                                       :fields selected-fields))))
    (eglot--apply-workspace-edit generate-result this-command)))

(defun eglot-jdtls-generate-delegate-methods-prompt-support (server arguments)
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
       (field (plist-get selected-field :field))
       (field-name (plist-get field :name))
       (delegate-methods (plist-get selected-field-item :delegateMethods))
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
       (generate-result (jsonrpc-request
                         server :java/generateDelegateMethods
                         (list :context params
                               :delegateEntries selected-methods))))
    (eglot--apply-workspace-edit generate-result this-command)))

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
  (cl-block nil
    (let* ((uris (vector (plist-get (seq-elt arguments 2) :uri)))
           (move-dest-resp (jsonrpc-request
                            server :java/getMoveDestinations
                            (list :moveKind "moveResource"
                                  :sourceUris uris
                                  :params nil)))
           (err-msg (plist-get move-dest-resp :errorMessage))
           (_ (when err-msg
                (message "%s" err-msg)
                (cl-return)))
           (destinations (plist-get move-dest-resp :destinations))
           (_ (unless (and destinations
                           (vectorp destinations)
                           (length> destinations 0))
                (message "Cannot find available Java packages to move the selected files to.")
                (cl-return)))
           (destination (eglot-jdtls--select
                         destinations
                         (format "Choose the target package for %s: "
                                 (file-name-nondirectory (buffer-file-name)))
                         (lambda (item)
                           (let ((display-name (plist-get item :displayName))
                                 (path (plist-get item :path)))
                             (format "%s - %s" display-name path)))))
           (result (jsonrpc-request
                    server :java/move
                    (list :moveKind "moveResource"
                          :sourceUris uris
                          :params nil
                          :destination destination
                          :updateReferences t))))
      (eglot-jdtls--refactor-edit server result))))

(defun eglot-jdtls--instant-method (server arguments)
  "Move an instance method to a different class (field or method parameter).

The method is moved to either a field's type or a method parameter's type,
converting it to a static method in the target class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list containing the move operation context from JDT LS
command, with parameters at index 1 and display info at index 2."
  (cl-block nil
    (let* ((params (seq-elt arguments 1))
           (uris (vector (plist-get (plist-get params :textDocument) :uri)))
           (move-dest-resp (jsonrpc-request server :java/getMoveDestinations
                                           (list :moveKind "moveInstanceMethod"
                                                 :sourceUris uris
                                                 :params params)))
           (err-msg (plist-get move-dest-resp :errorMessage))
           (_ (when err-msg (message "%s" err-msg) (cl-return)))
           (destinations (plist-get move-dest-resp :destinations))
           (_ (unless (and destinations
                           (vectorp destinations)
                           (length> destinations 0))
                (message "Cannot find available Java packages to move the selected files to")
                (cl-return)))
           (destination (eglot-jdtls--select
                         destinations
                         (format
                          "Select the new class for the instance method %s: "
                          (or (plist-get (seq-elt arguments 2) :displayName)
                              ""))
                         (lambda (item)
                           (pcase-let* (((map :name :type :isField) item))
                             (format "%s %s %s"
                                     (if (eq isField :json-false)
                                         "[Method Parameter]"
                                       "[Field]           ")
                                     type name)))))
           (result (jsonrpc-request server :java/move
                                   (list :moveKind "moveInstanceMethod"
                                         :sourceUris uris
                                         :params params
                                         :destination destination
                                         :updateReferences t))))
      (eglot-jdtls--refactor-edit server result))))

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
      (eglot-jdtls--select filtered-symbols prompt
                            (lambda (item)
                              (pcase-let* (((map :name :containerName) item))
                                (format "%s %s" name containerName)))))))

(defun eglot-jdtls--move-static-member (server arguments)
  "Move a static member (field, method, or type) to another class.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (cl-block nil
    (pcase-let*
        ((`[_cmd ,params ,cmd-info] arguments)
         (uris (vector (plist-get (plist-get params :textDocument) :uri)))
         ((map
           (:displayName display-name "")
           (:projectName project-name "")
           (:enclosingTypeName type-name)
           :memberType) cmd-info)
         (excludes (when type-name
                     (if (memq memberType '(55 71 81))
                         ;; 55: Type, 71: Enum, 81: AnnotationType
                         (list type-name
                               (format "%s.%s"
                                       type-name
                                       display-name))
                       (list type-name))))
         (target-class (eglot-jdtls--select-target-class
                        server
                        (format
                         "Select the new class for the static member %s: "
                         display-name)
                        project-name
                        excludes))
         (_ (unless target-class
              (message "No destination found")
              (cl-return)))
         (result (jsonrpc-request server :java/move
                                 (list :moveKind "moveStaticMember"
                                       :sourceUris uris
                                       :params params
                                       :destination target-class))))
      (eglot-jdtls--refactor-edit server result))))

(defun eglot-jdtls--move-type (server arguments)
  "Move a type (class, interface, enum, or annotation type) to another location.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (cl-block nil
    (pcase-let*
        ((`[_cmd ,params ,cmd-info] arguments)
         (uris (vector (plist-get (plist-get params :textDocument) :uri)))
         ((map
           (:displayName display-name "")
           (:projectName project-name "")
           (:supportedDestinationKinds kinds)
           (:enclosingTypeName type-name)) cmd-info)
         (_ (when (length= kinds 0)
              (message "No available destination kinds")
              (cl-return)))
         (kind (eglot-jdtls--select
                kinds "What would you like to do?"
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
      (eglot-jdtls--refactor-edit server result))))

(defun eglot-jdtls--change-signature (server arguments)
  "Change method signature interactively using a dedicated edit buffer.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (cl-block nil
    (pcase-let*
        ((`[,cmd ,params] arguments)
         (sig-info (jsonrpc-request server :java/getChangeSignatureInfo params))
         (err-msg (plist-get sig-info :errorMessage))
         (_ (when err-msg
              (message "%s" err-msg)
              (cl-return)))
         (edit-buf (get-buffer-create "*eglot-jdtls:Change Method Signature*")))
      (cl-labels
          ((send-change-signature
            (cmd-params)
            (let ((win (selected-window))
                  (buf (current-buffer)))
              (message "[eglot-jdtls] send async changeSignature request, it might take few seconds to complete.")
              (jsonrpc-async-request
               server :java/getRefactorEdit
               (list :command cmd
                     :context params
                     :options (eglot-jdtls--format-options)
                     :commandArguments cmd-params)
               :success-fn
               (lambda (result)
                 (when-let* ((edit (plist-get result :edit))
                             (doc-changes (plist-get edit :documentChanges)))
                   (eglot-jdtls--refactor-edit server result)
                   (when (window-live-p win)
                     (delete-window win))
                   (when (buffer-live-p buf)
                     (kill-buffer buf)))))))
           (label
            (str)
            (propertize
             str
             'read-only t 'face 'font-lock-keyword-face 'front-sticky t 'rear-nonsticky t))
           (comments
            (&rest strs)
            (propertize
             (mapconcat #'identity strs "\n")
             'read-only t 'face 'font-lock-comment-face 'front-sticky t 'rear-nonsticky t))
           (set-edit-buf-content
            (buf lines)
            (with-current-buffer buf
              (let ((inhibit-read-only t))
                (erase-buffer))
              (dolist (line lines)
                (insert line)
                (newline))
              (goto-char (point-min))))
           (parse-buf
            (buf method-id sig-exceptions)
            (with-current-buffer buf
              (save-excursion
                (goto-char (point-min))
                (let ((is-preview :json-false)
                      access-modifier return-type method-name parameters
                      exceptions is-delegate section)
                  (cl-block nil
                    (while (not (eobp))
                      (let ((line (thing-at-point 'line t)))
                        (when (string-prefix-p "---" line)
                          (cl-return))
                        (cond
                         ((string-prefix-p "Access modifier: " line)
                          (setq access-modifier (string-trim (substring line (length "Access modifier: ")))))
                         ((string-prefix-p "Return type: " line)
                          (setq return-type (string-trim (substring line (length "Return type: ")))))
                         ((string-prefix-p "Method name: " line)
                          (setq method-name (string-trim (substring line (length "Method name: ")))))
                         ((string-prefix-p "IsDelegate: " line)
                          (setq is-delegate (string-trim (substring line (length "IsDelegate: ")))))
                         ((string-prefix-p "Parameters:" line)
                          (setq section 'parameters))
                         ((string-prefix-p "Exceptions:" line)
                          (setq section 'exception))
                         ((string-prefix-p "-" line)
                          (pcase section
                            ('parameters
                             (when (string-match "\\-\\(?: \\([0-9]+\\):\\)? \\(\\S-+\\) \\(\\S-+\\)\\(?: \\(\\S-+\\)\\)?" line)
                               (let ((idx (match-string 1 line))
                                     (type (match-string 2 line))
                                     (name (match-string 3 line))
                                     (default-val (match-string 4 line)))
                                 (push (list
                                        :type type
                                        :name name
                                        :defaultValue (if idx "" (or default-val "null"))
                                        :originalIndex (if idx (string-to-number idx) -1))
                                       parameters))))
                            ('exception
                             (when (string-match "\\-\\(?: \\([0-9]+\\):\\)? \\(\\S-+\\)" line)
                               (let* ((idx (match-string 1 line))
                                      (type (match-string 2 line))
                                      (type-id (when idx
                                                 (let ((idx (string-to-number idx)))
                                                   (when (and (> idx -1)
                                                              (< idx (length sig-exceptions)))
                                                     (plist-get (seq-elt sig-exceptions idx)
                                                                :typeHandleIdentifier))))))
                                 (push (if type-id
                                           (list :type type :typeHandleIdentifier type-id)
                                         (list :type type)) exceptions))))
                            (_ nil))))
                        (forward-line))))
                  (vector method-id
                          is-delegate
                          method-name
                          access-modifier
                          return-type
                          (vconcat (nreverse parameters))
                          (vconcat (nreverse exceptions))
                          is-preview))))))
        (pcase-let*
            (((map :methodIdentifier :modifier :returnType
                   :methodName :parameters :exceptions) sig-info)
             (lines `(,(concat (label "Access modifier: ") modifier)
                      ,(concat (label "Return type: ") returnType)
                      ,(concat (label "Method name: ") methodName)
                      ,(label "Parameters:")
                      ,@(cl-loop for param across parameters
                                 for id from 0
                                 collect
                                 (pcase-let* (((map :type :name
                                                    :defaultValue
                                                    :originalIndex) param))
                                   (format "- %d: %s %s"
                                           originalIndex type name)))
                      ,(label "Exceptions:")
                      ,@(cl-loop for exception across exceptions
                                 for id from 0
                                 collect
                                 (pcase-let* (((map :typeHandleIdentifier
                                                    :type) exception))
                                   (format "- %d: %s" id type)))
                      ,(concat (label "IsDelegate: ") "false")
                      ""
                      ,(comments
                        "---"
                        "Labels are used to parse the values. Ensure they remain at the beginning of each line. "
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
                        "---"))))
          (with-current-buffer edit-buf
            (set-edit-buf-content edit-buf lines)
            (local-set-key (kbd "C-c C-c")
                           (lambda ()
                             (interactive)
                             (let ((cmd-params (parse-buf edit-buf
                                                          methodIdentifier
                                                          exceptions)))
                               (send-change-signature cmd-params))))
            (local-set-key (kbd "C-c C-r")
                           (lambda ()
                             (interactive)
                             (set-edit-buf-content edit-buf lines)))
            (local-set-key (kbd "C-c C-k")
                           (lambda ()
                             (interactive)
                             (kill-buffer-and-window))))
          (switch-to-buffer-other-window edit-buf))))))

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

CMD is the refactoring command name (e.g., \"extractMethod\", \"extractVariable\",
\"extractConstant\", \"extractField\").
PARAMS is the context parameters for the refactoring operation.
SERVER is the JDT Language Server instance (unused, server is obtained via
eglot-current-server internally)."
  (let* ((expressions (jsonrpc-request
                       (eglot-current-server) :java/inferSelection
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
  "Extract an interface from a class by selecting members and specifying destination.

SERVER is the JDT Language Server instance.
ARGUMENTS is a list provided by the Java refactoring command."
  (cl-block nil
    (pcase-let*
        ((`[,cmd ,params] arguments)
         (check-resp (jsonrpc-request
                      server :java/checkExtractInterfaceStatus
                      params))
         (_ (unless check-resp (cl-return)))
         ((map :members :subTypeName :destinationResponse) check-resp)
         (destinations (plist-get destinationResponse :destinations))
         (_ (unless (and members (vectorp members) (length> members 0))
              (message "Cannot find available members to declare in the interface")
              (cl-return)))
         (_ (unless (and destinations
                         (vectorp destinations)
                         (length> destinations 0))
              (message "Cannot find available Java packages to extract interface to")
              (cl-return)))
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
         (_ (unless member-ids (cl-return)))
         (interface-name (read-string "Specify interface name: " subTypeName))
         (_ (unless (and interface-name
                         (not (string-empty-p interface-name)))
              (cl-return)))
         (destination (eglot-jdtls--select
                       destinations
                       (format "Specify package: ")
                       (lambda (item)
                         (let ((display-name (plist-get item :displayName))
                               (path (plist-get item :path)))
                           (format "%s - %s" display-name path)))))
         (_ (unless destination (cl-return)))
         (cmd-args (vector member-ids interface-name destination))
         (result (jsonrpc-request
                  server :java/getRefactorEdit
                  (list :command cmd
                        :commandArguments (vconcat cmd-args)
                        :context params
                        :options (eglot-jdtls--format-options)))))
      (eglot-jdtls--refactor-edit server result)
      (when-let* ((edit (plist-get result :edit))
                  (doc-changes (plist-get edit :documentChanges)))
        (mapc
         (lambda (doc-change)
           (when-let* ((kind (plist-get doc-change :kind))
                       (_ (equal kind "create"))
                       (uri (plist-get doc-change :uri))
                       (file (eglot-uri-to-path uri))
                       (_ (file-exists-p file)))
             (find-file-other-window file)))
         doc-changes)))))

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
                             (let* ((_ (length> arguments 2))
                                    (cmd-info (seq-elt arguments 2))
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
                           (let* ((_ (length> arguments 2))
                                  (cmd-info (seq-elt arguments 2))
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
_METHOD is always 'workspace/executeClientCommand' (via method specialization).
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
      ("java.action.generateConstructorsPrompt" (eglot-jdtls-generate-constructors-prompt server arguments))
      ("java.action.generateDelegateMethodsPrompt" (eglot-jdtls-generate-delegate-methods-prompt-support server arguments))
      ("java.action.applyRefactoringCommand" (eglot-jdtls--apply-refactoring-command server arguments))
      ("java.action.rename" (eglot-jdtls--rename arguments))
      ("java.show.references" (eglot-jdlts--show-references command arguments))
      ("java.show.implementations" (eglot-jdlts--show-references command arguments))
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


(provide 'eglot-jdtls)
;;; eglot-jdtls.el ends here
