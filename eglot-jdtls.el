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
  ""
  :group 'eglot
  :prefix "eglot-jdtls-"
  :link '(url-link :tag "GitHub" "https://github.com/zsxh/eglot-jdtls"))

(defclass eglot-jdtls-server (eglot-lsp-server)
  ()
  :documentation "eclipse's jdt langserver."
  :group 'eglot-jdtls)

;; Variables

(defcustom eglot-jdtls-config nil
  "JDTLS server config for eglot."
  :type '(plist :key-type (restricted-sexp
                           :match-alternatives (keywordp)
                           :tag "Keyword")
                :value-type sexp)
  :group 'eglot-jdtls)

(defcustom eglot-jdtls-cache-dir
  (expand-file-name "eglot-java" (temporary-file-directory))
  "Directory to cache Java source files from jdt:// URIs."
  :type 'directory
  :group 'eglot-jdtls)

(defvar eglot-jdtls--default-config
  '(:cmd ("jdtls")
    :settings nil
    :init-options (:bundles []
                   :extendedClientCapabilities (:classFileContentsSupport t
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
  ""
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
  ""
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

(defun eglot-jdtls---select (items prompt display-item-fn
                                   &optional multiple-p separator)
  ""
  (let* ((cands (mapcar
                 (lambda (item)
                   (cons (funcall display-item-fn item) item))
                 items))
         (item-fn (lambda (choice)
                    (alist-get choice cands nil nil 'equal)))
         (crm-separator (or separator crm-separator)))
    (if multiple-p
        (cl-map 'vector
                item-fn
                (delete-dups
                 (completing-read-multiple prompt cands)))
      (funcall item-fn (completing-read prompt cands)))))

(defun eglot-jdtls--format-options ()
  ""
  (list
   :tabSize tab-width
   :insertSpaces (if indent-tabs-mode
                     :json-false
                   t)))

(defun eglot-jdtls--find-jdt-server ()
  ""
  (let ((filter-fn (lambda (server)
                     (cl-loop for (mode . languageid) in
                              (eglot--languages server)
                              when (string= languageid "java")
                              return languageid)))
        (servers (gethash (eglot--current-project) eglot--servers-by-project)))
    (cl-find-if filter-fn servers)))

(defun eglot-jdtls-uri-handler (operation &rest args)
  "Support Eclipse jdtls `jdt://' uri scheme."
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
  "Command `java.apply.workspaceEdit' handler."
  (mapc #'eglot--apply-workspace-edit arguments this-command))

(defun eglot-jdtls--override-methods-prompt (server arguments)
  "Command `java.action.overrideMethodsPrompt' handler."
  (let* ((argument (seq-elt arguments 0))
         (list-methods-result (jsonrpc-request server :java/listOverridableMethods argument))
         (methods (plist-get list-methods-result :methods))
         (menu-items (mapcar
                      (lambda (method)
                        (let* ((name (plist-get method :name))
                               (parameters (plist-get method :parameters))
                               (class (plist-get method :declaringClass)))
                          (cons (format "%s(%s): %s" name (string-join parameters ", ") class) method)))
                      methods))
         ;; use ";" instead of "," to separate strings in completing-read-multiple
         (crm-separator "[ \t]*;[ \t]*")
         (selected-methods (cl-map
                            'vector
                            (lambda (choice) (alist-get choice menu-items nil nil 'equal))
                            (delete-dups
                             (completing-read-multiple "Select methods: " menu-items))))
         (add-methods-result (jsonrpc-request
                              server
                              :java/addOverridableMethods
                              (list :overridableMethods selected-methods :context argument))))
    (eglot--apply-workspace-edit add-methods-result this-command)))

(defun eglot-jdlts--show-references (command arguments)
  "Show Java references from LSP arguments."
  (if-let* ((refs (seq-elt arguments 2))
            (_ (length> refs 0)))
      (xref-show-xrefs
       (eglot--collecting-xrefs (collect)
         (mapc
          (lambda (ref)
            (eglot--dbind ((Location) uri range) ref
              (collect (eglot--xref-make-match "" uri range))))
          refs))
       nil)
    (message "%s returned no references" command)))

(defun eglot-jdtls--rename (arguments)
  "Execute Java rename action using Eglot LSP."
  (eglot--dbind (uri offset length) (seq-elt arguments 0)
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
  "Prompt user to generate toString method for Java class using Eglot LSP."
  (let* ((context (seq-elt arguments 0))
         (check-resp (jsonrpc-request server :java/checkToStringStatus context)))
    (eglot--dbind (fields exists) check-resp
      (when (or (eq exists :json-false) (y-or-n-p "The toString() method already exists. Replace?"))
        (let* ((menu-items (mapcar (lambda (field)
                                     (let ((name (plist-get field :name))
                                           (type (plist-get field :type)))
                                       (cons (format "%s: %s" name type) field)))
                                   fields))
               ;; use ";" instead of "," to separate strings in completing-read-multiple
               (crm-separator "[ \t]*;[ \t]*")
               (selected-items (cl-map 'vector
                                       (lambda (choice) (alist-get choice menu-items nil nil 'equal))
                                       (delete-dups
                                        (completing-read-multiple "Select fields to include: " menu-items))))
               (generate-result (jsonrpc-request server :java/generateToString (list :fields selected-items :context context))))
          (eglot--apply-workspace-edit generate-result this-command))))))

(defun eglot-jdtls--hashCode-equals-prompt (server arguments)
  "Prompt user to generate hashCode and equals methods for Java class using Eglot LSP."
  (let* ((context (seq-elt arguments 0))
         (check-resp (jsonrpc-request server :java/checkHashCodeEqualsStatus context)))
    (eglot--dbind (fields existingMethods) check-resp
      (when (or (seq-empty-p existingMethods)
                (y-or-n-p (format "The %s method already exists. Replace?" existingMethods)))
        (let* ((menu-items (mapcar (lambda (field)
                                     (let ((name (plist-get field :name))
                                           (type (plist-get field :type)))
                                       (cons (format "%s: %s" name type) field)))
                                   fields))
               ;; use ";" instead of "," to separate strings in completing-read-multiple
               (crm-separator "[ \t]*;[ \t]*")
               (selected-items (cl-map 'vector
                                       (lambda (choice) (alist-get choice menu-items nil nil 'equal))
                                       (delete-dups
                                        (completing-read-multiple "Select fields to include: " menu-items))))
               (generate-result (jsonrpc-request server :java/generateHashCodeEquals
                                                (list
                                                 :fields selected-items
                                                 :context context
                                                 :regenerate (not (seq-empty-p existingMethods))))))
          (eglot--apply-workspace-edit generate-result this-command))))))

(defun java-action-generateAccessorsPrompt (server arguments)
  "Prompt user to generate accessor methods for Java fields using Eglot LSP."
  (let* ((context (seq-elt arguments 0))
         (accessorFields (jsonrpc-request server :java/resolveUnimplementedAccessors context))
         (menu-items (mapcar (lambda (accessorField)
                               (let ((field (plist-get accessorField :fieldName))
                                     (type (plist-get accessorField :typeName)))
                                 (cons (format "%s: %s" field type) accessorField)))
                             accessorFields))
         ;; use ";" instead of "," to separate strings in completing-read-multiple
         (crm-separator "[ \t]*;[ \t]*")
         (selected-items (cl-map 'vector
                                 (lambda (choice) (alist-get choice menu-items nil nil 'equal))
                                 (delete-dups
                                  (completing-read-multiple "Select fields to generate: " menu-items))))
         (generate-result (jsonrpc-request server :java/generateAccessors (list :accessors selected-items :context context))))
    (eglot--apply-workspace-edit generate-result this-command)))

(defun java-action-generateConstructorsPrompt (server arguments)
  "Prompt user to generate constructors for Java classes using Eglot LSP."
  (let* ((context (seq-elt arguments 0))
         (check-resp (jsonrpc-request server :java/checkConstructorsStatus context))
         (constructors (plist-get check-resp :constructors))
         (fields (plist-get check-resp :fields))
         ;; use ";" instead of "," to separate strings in completing-read-multiple
         (crm-separator "[ \t]*;[ \t]*")
         (constructor-items (mapcar (lambda (item)
                                      (let ((name (plist-get item :name))
                                            (parameters (plist-get item :parameters)))
                                        (cons (format "%s(%s)" name (mapconcat #'identity parameters ", ")) item)))
                                    constructors))
         (selected-constructors (cl-map 'vector
                                        (lambda (choice) (alist-get choice constructor-items nil nil 'equal))
                                        (delete-dups
                                         (completing-read-multiple "Select constructors to generate: " constructor-items))))
         (field-items (mapcar (lambda (item)
                                (let ((name (plist-get item :name))
                                      (type (plist-get item :type)))
                                  (cons (format "%s: %s" name type) item)))
                              fields))
         (selected-fields (cl-map 'vector
                                  (lambda (choice) (alist-get choice field-items nil nil 'equal))
                                  (delete-dups
                                   (completing-read-multiple "Select fields to generate: " field-items))))
         (generate-result (jsonrpc-request server :java/generateConstructors
                                          (list :context context
                                                :constructors selected-constructors
                                                :fields selected-fields))))
    (eglot--apply-workspace-edit generate-result this-command)))

(defun java-action-generateDelegateMethodsPromptSupport (server arguments)
  "Prompt user to generate delegate methods for Java fields using Eglot LSP."
  (let* ((context (seq-elt arguments 0))
         (check-resp (jsonrpc-request server :java/checkDelegateMethodsStatus context))
         (delegate-fields (plist-get check-resp :delegateFields))
         ;; use ";" instead of "," to separate strings in completing-read-multiple
         (crm-separator "[ \t]*;[ \t]*")
         (field-items (mapcar (lambda (item)
                                (let* ((field (plist-get item :field))
                                       (name (plist-get field :name))
                                       (type (plist-get field :type)))
                                  (cons (format "%s: %s" name type) item)))
                              delegate-fields))
         (selected-field-key (completing-read "Select target to generate delegates for:" field-items))
         (selected-field-item (alist-get selected-field-key field-items nil nil 'equal))
         (field (plist-get selected-field-item :field))
         (field-name (plist-get field :name))
         (delegate-methods (plist-get selected-field-item :delegateMethods))
         (delegate-method-items (mapcar (lambda (item)
                                          (let* ((name (plist-get item :name))
                                                 (parameters (plist-get item :parameters)))
                                            (cons (format "%s.%s(%s)" field-name name
                                                          (mapconcat #'identity parameters ", "))
                                                  item)))
                                        delegate-methods))
         (selected-delegate-methods
          (cl-map 'vector
                  (lambda (choice)
                    (let* ((method (alist-get choice delegate-method-items nil nil 'equal)))
                      (list :field field :delegateMethod method)))
                  (delete-dups
                   (completing-read-multiple
                    "Select methods to generate delegates for:" delegate-method-items))))
         (generate-result (jsonrpc-request server :java/generateDelegateMethods
                                          (list :context context
                                                :delegateEntries selected-delegate-methods))))
    (eglot--apply-workspace-edit generate-result this-command)))

(defun eglot-jdtls--refactor-edit (server refactor-edit)
  ""
  (let ((edit (plist-get refactor-edit :edit))
        (command (plist-get refactor-edit :command))
        (err (plist-get refactor-edit :errorMessage)))
    (when err
      (message "%s" err))
    (when edit
      (eglot--apply-workspace-edit edit this-command))
    (when command
      (eglot-execute server command))))

(defun eglot-jdtls--move-file (server arguments)
  ""
  (cl-block nil
    (let* ((ctx (seq-elt arguments 1))
           (uris (vector (plist-get (seq-elt arguments 2) :uri)))
           (move-dest-resp (jsonrpc-request server :java/getMoveDestinations
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
           (destination (eglot-jdtls---select
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
  ""
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
           (destination (eglot-jdtls---select
                         destinations
                         (format
                          "Select the new class for the instance method %s: "
                          (or (plist-get (seq-elt arguments 2) :displayName) ""))
                         (lambda (item)
                           (let ((name (plist-get item :name))
                                 (type (plist-get item :type))
                                 (is-field (plist-get item :isField)))
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
      (eglot-jdtls--refactor-edit server result))))

(defun eglot-jdtls--select-target-class (server prompt project-name excludes)
  ""
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
      (eglot-jdtls---select filtered-symbols prompt
                            (lambda (item)
                              (pcase-let* (((map :name :containerName) item))
                                (format "%s %s" name containerName)))))))

(defun eglot-jdtls--move-static-member (server arguments)
  ""
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
  ""
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
         (kind (eglot-jdtls---select
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
  ""
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
              (eglot--async-request
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
  ""
  (pcase (length scopes)
    (0 nil)
    (1 (seq-elt scopes 0))
    (_ (completing-read
        "Initialize the field in: "
        (append scopes nil)))))

(defun eglot-jdtls--get-expression (cmd params server)
  ""
  (let* ((expressions (jsonrpc-request
                       (eglot-current-server) :java/inferSelection
                       (list :command cmd
                             :context params))))
    (pcase (length expressions)
      (0 nil)
      (1 (seq-elt expressions 0))
      (_ (eglot-jdtls---select
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
  ""
  (cl-block nil
    (pcase-let*
        ((`[,cmd ,params] arguments)
         (check-resp (jsonrpc-request server :java/checkExtractInterfaceStatus params))
         (_ (unless check-resp (cl-return)))
         ((map :members :subTypeName :destinationResponse) check-resp)
         (destinations (plist-get destinationResponse :destinations))
         (_ (unless (and members (vectorp members) (length> members 0))
              (message "Cannot find available members to declare in the interface")
              (cl-return)))
         (_ (unless (and destinations (vectorp destinations) (length> destinations 0))
              (message "Cannot find available Java packages to extract interface to")
              (cl-return)))
         (members (eglot-jdtls---select
                   members
                   "Select members: "
                   (lambda (m)
                     (pcase-let* (((map :name :typeName :parameters) m)
                                  (params-str (mapconcat #'identity parameters ", ")))
                       (format "%s(%s) %s" name params-str typeName)))
                   t
                   "[ \t]*;[ \t]*"))
         (_ (unless members (cl-return)))
         (member-ids (vconcat (mapcar (lambda (x) (plist-get x :handleIdentifier)) members)))
         (interface-name (read-string "Specify interface name: " subTypeName))
         (_ (unless (and interface-name (not (string-empty-p interface-name)))
              (cl-return)))
         (destination (eglot-jdtls---select
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
  ""
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
  (pcase command
    ("java.action.organizeImports.chooseImports"
     (let* ((documentUri (seq-elt arguments 0)) ; string - 文档 URI
            (selections (seq-elt arguments 1)) ; ImportSelection[] - 导入冲突列表
            (restoreExistingImports (seq-elt arguments 2)) ; boolean - 是否保留现有导入
            (select-candidate-fn
             (eglot--lambda (candidates range)
               (eglot--goto range)
               (let* ((menu-items (mapcar
                                   (lambda (cand)
                                     (let ((fullyQualifiedName (plist-get cand :fullyQualifiedName)))
                                       (cons fullyQualifiedName cand)))
                                   candidates))
                      (selected-item-key (completing-read "Select class to import: " menu-items))
                      (selected-item (alist-get selected-item-key menu-items nil nil 'equal)))
                 selected-item))))
       (with-current-buffer (find-file (eglot-uri-to-path documentUri))
         (save-excursion
           (cl-map 'vector select-candidate-fn selections)))))
    ("_java.reloadBundles.command" [])
    (_ (message "Unknown client command: %s" command))))

(cl-defmethod eglot-execute :around
  ((server eglot-jdtls-server) action)
  "Custom handler for performing client commands."
  (let ((command (plist-get action :command))
        (arguments (plist-get action :arguments))
        (vertico-sort-function nil))
    (pcase command
      ("java.apply.workspaceEdit" (eglot-jdtls--apply-workspaceEdit arguments))
      ("java.action.overrideMethodsPrompt" (eglot-jdtls--override-methods-prompt server arguments))
      ("java.action.generateToStringPrompt" (eglot-jdtls--generate-toString-prompt server arguments))
      ("java.action.hashCodeEqualsPrompt" (eglot-jdtls--hashCode-equals-prompt server arguments))
      ("java.action.generateAccessorsPrompt" (java-action-generateAccessorsPrompt server arguments))
      ("java.action.generateConstructorsPrompt" (java-action-generateConstructorsPrompt server arguments))
      ("java.action.generateDelegateMethodsPrompt" (java-action-generateDelegateMethodsPromptSupport server arguments))
      ("java.action.applyRefactoringCommand" (eglot-jdtls--apply-refactoring-command server arguments))
      ("java.action.rename" (eglot-jdtls--rename arguments))
      ("java.show.references" (eglot-jdlts--show-references command arguments))
      ("java.show.implementations" (eglot-jdlts--show-references command arguments))
      (_ (cl-call-next-method)))))

;; Interactive commands

;;;###autoload
(defun eglot-jdtls-organize-imports ()
  "Organize imports in the current Java buffer using Eglot LSP."
  (interactive)
  (eglot--async-request
   (eglot--current-server-or-lose)
   :java/organizeImports
   `(:textDocument (:uri ,(eglot-path-to-uri (buffer-file-name) :truenamep t))
     :range (:start (:line 0 :character 0)
             :end (:line 0 :character 0))
     :context (:diagnostics []))
   :success-fn (lambda (result)
                 (eglot--apply-workspace-edit result this-command))
   :hint :java/organizeImports))


(provide 'eglot-jdtls)
;;; eglot-jdtls.el ends here
