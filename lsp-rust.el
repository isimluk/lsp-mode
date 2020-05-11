;;; lsp-rust.el --- Rust Client settings             -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Ivan Yonchovski

;; Author: Ivan Yonchovski <yyoncho@gmail.com>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
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

;; lsp-rust client

;;; Code:

(require 'lsp-mode)
(require 'ht)
(require 'dash)

(defgroup lsp-rust nil
  "LSP support for Rust, using Rust Language Server or rust-analyzer."
  :group 'lsp-mode
  :link '(url-link "https://github.com/rust-lang/rls")
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-server 'rls
  "Choose LSP server."
  :type '(choice (const :tag "rls" rls)
                 (const :tag "rust-analyzer" rust-analyzer))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2"))

;; RLS

(defcustom lsp-rust-rls-server-command '("rls")
  "Command to start RLS."
  :type '(repeat string)
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-library-directories '("~/.cargo/registry/src" "~/.rustup/toolchains")
  "List of directories which will be considered to be libraries."
  :risky t
  :type '(repeat string)
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-sysroot nil
  "If non-nil, use the given path as the sysroot for all rustc invocations instead of trying
to detect the sysroot automatically."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Sysroot"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-target nil
  "If non-nil, use the given target triple for all rustc invocations."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Target"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-rustflags nil
  "Flags added to RUSTFLAGS."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Flags"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-clear-env-rust-log t
  "Clear the RUST_LOG environment variable before running rustc or cargo."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-build-lib nil
  "If non-nil, checks the project as if you passed the `--lib' argument to cargo.
Mutually exclusive with, and preferred over, `lsp-rust-build-bin'. (Unstable)"
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-build-bin nil
  "If non-nil, checks the project as if you passed `-- bin <build_bin>' argument to cargo.
Mutually exclusive with `lsp-rust-build-lib'. (Unstable)"
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Binary"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-cfg-test nil
  "If non-nil, checks the project as if you were running `cargo test' rather than cargo build.
I.e., compiles (but does not run) test code."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-unstable-features nil
  "Enable unstable features."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-wait-to-build nil
  "Time in milliseconds between receiving a change notification
and starting build. If not specified, automatically inferred by
the latest build duration."
  :type '(choice
          (const :tag "Auto" nil)
          (number :tag "Time"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-show-warnings t
  "Show warnings."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-crate-blacklist  [
                                      "cocoa"
                                      "gleam"
                                      "glium"
                                      "idna"
                                      "libc"
                                      "openssl"
                                      "rustc_serialize"
                                      "serde"
                                      "serde_json"
                                      "typenum"
                                      "unicode_normalization"
                                      "unicode_segmentation"
                                      "winapi"
                                      ]
  "A list of Cargo crates to blacklist."
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-build-on-save nil
  "Only index the project when a file is saved and not on
change."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-features []
  "List of Cargo features to enable."
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-all-features nil
  "Enable all Cargo features."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-no-default-features nil
  "Do not enable default Cargo features."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-racer-completion t
  "Enables code completion using racer."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-clippy-preference "opt-in"
  "Controls eagerness of clippy diagnostics when available. Valid
  values are (case-insensitive):\n - \"off\": Disable clippy
  lints.\n - \"opt-in\": Clippy lints are shown when crates
  specify `#![warn(clippy)]`.\n - \"on\": Clippy lints enabled
  for all crates in workspace.\nYou need to install clippy via
  rustup if you haven't already."
  :type '(choice
          (const "on")
          (const "opt-in")
          (const "off"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-jobs nil
  "Number of Cargo jobs to be run in parallel."
  :type '(choice
          (const :tag "Auto" nil)
          (number :tag "Jobs"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-all-targets t
  "Checks the project as if you were running cargo check --all-targets.
I.e., check all targets and integration tests too."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-target-dir nil
  "When specified, it places the generated analysis files at the
specified target directory. By default it is placed target/rls
directory."
  :type '(choice
          (const :tag "Default" nil)
          (string :tag "Directory"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-rustfmt-path nil
  "When specified, RLS will use the Rustfmt pointed at the path
instead of the bundled one"
  :type '(choice
          (const :tag "Bundled" nil)
          (string :tag "Path"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-build-command nil
  "EXPERIMENTAL (requires `unstable_features`)\nIf set, executes
a given program responsible for rebuilding save-analysis to be
loaded by the RLS. The program given should output a list of
resulting .json files on stdout. \nImplies `rust.build_on_save`:
true."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Command"))
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-full-docs nil
  "Instructs cargo to enable full documentation extraction during
save-analysis while building the crate."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(defcustom lsp-rust-show-hover-context t
  "Show additional context in hover tooltips when available. This
is often the type local variable declaration."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.1"))

(lsp-register-custom-settings
 '(("rust.show_hover_context" lsp-rust-show-hover-context t)
   ("rust.full_docs" lsp-rust-full-docs t)
   ("rust.build_command" lsp-rust-build-command)
   ("rust.rustfmt_path" lsp-rust-rustfmt-path)
   ("rust.target_dir" lsp-rust-target-dir)
   ("rust.all_targets" lsp-rust-all-targets t)
   ("rust.jobs" lsp-rust-jobs)
   ("rust.clippy_preference" lsp-rust-clippy-preference)
   ("rust.racer_completion" lsp-rust-racer-completion t)
   ("rust.no_default_features" lsp-rust-no-default-features t)
   ("rust.all_features" lsp-rust-all-features t)
   ("rust.features" lsp-rust-features)
   ("rust.build_on_save" lsp-rust-build-on-save t)
   ("rust.crate_blacklist" lsp-rust-crate-blacklist)
   ("rust.show_warnings" lsp-rust-show-warnings t)
   ("rust.wait_to_build" lsp-rust-wait-to-build)
   ("rust.unstable_features" lsp-rust-unstable-features t)
   ("rust.cfg_test" lsp-rust-cfg-test t)
   ("rust.build_bin" lsp-rust-build-bin)
   ("rust.build_lib" lsp-rust-build-lib t)
   ("rust.clear_env_rust_log" lsp-rust-clear-env-rust-log t)
   ("rust.rustflags" lsp-rust-rustflags)
   ("rust.target" lsp-rust-target)
   ("rust.sysroot" lsp-rust-sysroot)))

(defun lsp-clients--rust-window-progress (workspace params)
  "Progress report handling.
PARAMS progress report notification data."
  (-let (((&hash "done" "message" "title") params))
    (if (or done (s-blank-str? message))
        (lsp-workspace-status nil workspace)
      (lsp-workspace-status (format "%s - %s" title (or message "")) workspace))))

(cl-defmethod lsp-execute-command
  (_server (_command (eql rls.run)) params)
  (-let* (((&hash "env" "binary" "args" "cwd") (lsp-seq-first params))
          (default-directory (or cwd (lsp-workspace-root) default-directory) ))
    (compile
     (format "%s %s %s"
             (s-join " " (ht-amap (format "%s=%s" key value) env))
             binary
             (s-join " " args)))))

(lsp-register-client
 (make-lsp-client :new-connection (lsp-stdio-connection (lambda () lsp-rust-rls-server-command))
                  :major-modes '(rust-mode rustic-mode)
                  :priority (if (eq lsp-rust-server 'rls) 1 -1)
                  :initialization-options '((omitInitBuild . t)
                                            (cmdRun . t))
                  :notification-handlers (ht ("window/progress" 'lsp-clients--rust-window-progress))
                  :action-handlers (ht ("rls.run" 'lsp-rust--rls-run))
                  :library-folders-fn (lambda (_workspace) lsp-rust-library-directories)
                  :initialized-fn (lambda (workspace)
                                    (with-lsp-workspace workspace
                                      (lsp--set-configuration
                                       (lsp-configuration-section "rust"))))
                  :server-id 'rls))


;; rust-analyzer

(defcustom lsp-rust-analyzer-server-command '("rust-analyzer")
  "Command to start rust-analyzer."
  :type '(repeat string)
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2"))

(defcustom lsp-rust-analyzer-server-display-inlay-hints nil
  "Show inlay hints."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2"))

(defcustom lsp-rust-analyzer-max-inlay-hint-length nil
  "Max inlay hint length."
  :type 'integer
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-display-parameter-hints nil
  "Whether to show function parameter name inlay hints at the call site."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-display-chaining-hints nil
  "Whether to show inlay type hints for method chains."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-lru-capacity nil
  "Number of syntax trees rust-analyzer keeps in memory."
  :type 'integer
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-cargo-watch-enable t
  "Enable Cargo watch."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-cargo-watch-command "check"
  "Cargo watch command."
  :type 'string
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-cargo-watch-args []
  "Cargo watch args."
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-cargo-override-command []
  "Advanced option, fully override the command rust-analyzer uses for checking.
The command should include `--message=format=json` or similar option."
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-cargo-all-targets nil
  "Cargo watch all targets or not."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-use-client-watching t
  "Use client watching"
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-exclude-globs []
  "Exclude globs"
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-macro-expansion-method 'lsp-rust-analyzer-macro-expansion-default
  "Use a different function if you want formatted macro expansion results and syntax highlighting."
  :type 'function
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.2.2"))

(defcustom lsp-rust-analyzer-diagnostics-enable t
  "Whether to show native rust-analyzer diagnostics."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-cargo-load-out-dirs-from-check nil
  "Whether to run `cargo check` on startup to get the correct value for package OUT_DIRs."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-rustfmt-extra-args []
  "Additional arguments to rustfmt."
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-rustfmt-override-command []
  "Advanced option, fully override the command rust-analyzer uses for formatting."
  :type 'lsp-string-vector
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-completion-add-call-parenthesis t
  "Whether to add parenthesis when completing functions."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-completion-add-call-argument-snippets t
  "Whether to add argument snippets when completing functions."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-completion-postfix-enable t
  "Whether to show postfix snippets like `dbg`, `if`, `not`, etc."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-call-info-full t
  "Whether to show function name and docs in parameter hints."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defcustom lsp-rust-analyzer-proc-macro-enable nil
  "Enable Proc macro support; lsp-rust-analyzer-cargo-load-out-dirs-from-check must be enabled."
  :type 'boolean
  :group 'lsp-rust
  :package-version '(lsp-mode . "6.3.2"))

(defun lsp-rust-analyzer--make-init-options ()
  "Init options for rust-analyzer"
  `(:diagnostics (:enable ,(lsp-json-bool lsp-rust-analyzer-diagnostics-enable))
    :lruCapacity ,lsp-rust-analyzer-lru-capacity
    :checkOnSave (:enable ,(lsp-json-bool lsp-rust-analyzer-cargo-watch-enable)
                  :command ,lsp-rust-analyzer-cargo-watch-command
                  :extraArgs ,lsp-rust-analyzer-cargo-watch-args
                  :allTargets ,(lsp-json-bool lsp-rust-analyzer-cargo-all-targets)
                  :overrideCommand ,lsp-rust-analyzer-cargo-override-command)
    :files (:exclude ,lsp-rust-analyzer-exclude-globs
                     :watcher ,(lsp-json-bool (if lsp-rust-analyzer-use-client-watching
                                                  "client"
                                                "notify")))
    :cargo (:allFeatures ,(lsp-json-bool lsp-rust-all-features)
            :noDefaultFeatures ,(lsp-json-bool lsp-rust-no-default-features)
            :features ,lsp-rust-features
            :loadOutDirsFromCheck ,(lsp-json-bool lsp-rust-analyzer-cargo-load-out-dirs-from-check))
    :rustfmt (:extraArgs ,lsp-rust-analyzer-rustfmt-extra-args
              :overrideCommand ,lsp-rust-analyzer-rustfmt-override-command)
    :inlayHints (:typeHints ,(lsp-json-bool lsp-rust-analyzer-server-display-inlay-hints)
                 :chainingHints ,(lsp-json-bool lsp-rust-analyzer-display-chaining-hints)
                 :parameterHints ,(lsp-json-bool lsp-rust-analyzer-display-parameter-hints)
                 :maxLength ,lsp-rust-analyzer-max-inlay-hint-length)
    :completion (:addCallParenthesis ,(lsp-json-bool lsp-rust-analyzer-completion-add-call-parenthesis)
                 :addCallArgumentSnippets ,(lsp-json-bool lsp-rust-analyzer-completion-add-call-argument-snippets)
                 :postfix (:enable ,(lsp-json-bool lsp-rust-analyzer-completion-postfix-enable)))
    :callInfo (:full ,(lsp-json-bool lsp-rust-analyzer-call-info-full))
    :procMacro (:enable ,(lsp-json-bool lsp-rust-analyzer-proc-macro-enable))))

(defconst lsp-rust-notification-handlers
  '(("rust-analyzer/publishDecorations" . (lambda (_w _p)))))

(defconst lsp-rust-action-handlers
  '(("rust-analyzer.applySourceChange" .
     (lambda (p) (lsp-rust-apply-source-change-command p)))
    ("rust-analyzer.selectAndApplySourceChange" .
     (lambda (p) (lsp-rust-select-and-apply-source-change-command p)))))

(defun lsp-rust-apply-source-change-command (p)
  (let ((data (-> p (ht-get "arguments") (lsp-seq-first))))
    (lsp-rust-apply-source-change data)))

(defun lsp-rust-uri-filename (text-document)
  (lsp--uri-to-path (gethash "uri" text-document)))

(defun lsp-rust-apply-source-change (data)
  (seq-doseq (it (-> data (ht-get "workspaceEdit") (ht-get "documentChanges")))
    (lsp--apply-text-document-edit it))
  (-when-let (cursor-position (ht-get data "cursorPosition"))
    (let ((filename (lsp-rust-uri-filename (ht-get cursor-position "textDocument")))
          (position (ht-get cursor-position "position")))
      (find-file filename)
      (goto-char (lsp--position-to-point position)))))

(defun lsp-rust-select-and-apply-source-change-command (p)
  (let* ((options (-> p (ht-get "arguments") (lsp-seq-first)))
         (chosen-option (lsp--completing-read "Select option:" options
                                              (-lambda ((&hash "label")) label))))
    (lsp-rust-apply-source-change chosen-option)))

(define-derived-mode lsp-rust-analyzer-syntax-tree-mode special-mode "Rust-Analyzer-Syntax-Tree"
  "Mode for the rust-analyzer syntax tree buffer.")

(defun lsp-rust-analyzer-syntax-tree ()
  "Display syntax tree for current buffer."
  (interactive)
  (-if-let* ((workspace (lsp-find-workspace 'rust-analyzer))
             (root (lsp-workspace-root default-directory))
             (params (list :textDocument (lsp--text-document-identifier)
                           :range (if (use-region-p)
                                      (lsp--region-to-range (region-beginning) (region-end))
                                    (lsp--region-to-range (point-min) (point-max)))))
             (results (with-lsp-workspace workspace
                        (lsp-send-request (lsp-make-request
                                           "rust-analyzer/syntaxTree"
                                           params)))))
      (let ((buf (get-buffer-create (format "*rust-analyzer syntax tree %s*" root)))
            (inhibit-read-only t))
        (with-current-buffer buf
          (lsp-rust-analyzer-syntax-tree-mode)
          (erase-buffer)
          (insert results)
          (goto-char (point-min)))
        (pop-to-buffer buf))
    (message "rust-analyzer not running.")))

(define-derived-mode lsp-rust-analyzer-status-mode special-mode "Rust-Analyzer-Status"
  "Mode for the rust-analyzer status buffer.")

(defun lsp-rust-analyzer-status ()
  "Displays status information for rust-analyzer."
  (interactive)
  (-if-let* ((workspace (lsp-find-workspace 'rust-analyzer))
             (root (lsp-workspace-root default-directory))
             (results (with-lsp-workspace workspace
                        (lsp-send-request (lsp-make-request
                                           "rust-analyzer/analyzerStatus")))))
      (let ((buf (get-buffer-create (format "*rust-analyzer status %s*" root)))
            (inhibit-read-only t))
        (with-current-buffer buf
          (lsp-rust-analyzer-status-mode)
          (erase-buffer)
          (insert results)
          (pop-to-buffer buf)))
    (message "rust-analyzer not running.")))

(defun lsp-rust-analyzer-join-lines ()
  "Join selected lines into one, smartly fixing up whitespace and trailing commas."
  (interactive)
  (let* ((params (list :textDocument (lsp--text-document-identifier)
                       :range (if (use-region-p)
                                  (lsp--region-to-range (region-beginning) (region-end))
                                (lsp--region-to-range (point) (point)))))
         (result (lsp-send-request (lsp-make-request "rust-analyzer/joinLines" params))))
    (lsp-rust-apply-source-change result)))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection (lambda () lsp-rust-analyzer-server-command))
  :major-modes '(rust-mode rustic-mode)
  :priority (if (eq lsp-rust-server 'rust-analyzer) 1 -1)
  :initialization-options 'lsp-rust-analyzer--make-init-options
  :notification-handlers (ht<-alist lsp-rust-notification-handlers)
  :action-handlers (ht<-alist lsp-rust-action-handlers)
  :library-folders-fn (lambda (_workspace) lsp-rust-library-directories)
  :ignore-messages nil
  :server-id 'rust-analyzer))

(defun lsp-rust-switch-server (&optional lsp-server)
  "Switch priorities of lsp servers, unless LSP-SERVER is already active."
  (interactive)
  (let ((current-server (if (> (lsp--client-priority (gethash 'rls lsp-clients)) 0)
                            'rls
                          'rust-analyzer)))
    (unless (eq lsp-server current-server)
      (dolist (server '(rls rust-analyzer))
        (when (natnump (setf (lsp--client-priority (gethash server lsp-clients))
                             (* (lsp--client-priority (gethash server lsp-clients)) -1)))
          (message (format "Switched to server %s." server)))))))

;; inlay hints

(defvar-local lsp-rust-analyzer-inlay-hints-timer nil)

(defun lsp-rust-analyzer-update-inlay-hints (buffer)
  (if (and (lsp-rust-analyzer-initialized?)
           (eq buffer (current-buffer)))
      (lsp-request-async
       "rust-analyzer/inlayHints"
       (list :textDocument (lsp--text-document-identifier))
       (lambda (res)
         (remove-overlays (point-min) (point-max) 'lsp-rust-analyzer-inlay-hint t)
         (dolist (hint res)
           (-let* (((&hash "range" "label" "kind") hint)
                   ((beg . end) (lsp--range-to-region range))
                   (overlay (make-overlay beg end)))
             (overlay-put overlay 'lsp-rust-analyzer-inlay-hint t)
             (overlay-put overlay 'evaporate t)
             (cond
              ((string= kind "TypeHint")
               (overlay-put overlay 'after-string (propertize (concat ": " label)
                                                              'font-lock-face 'font-lock-comment-face)))
              ((string= kind "ParameterHint")
               (overlay-put overlay 'before-string (propertize (concat label ": ")
                                                               'font-lock-face 'font-lock-comment-face)))
              ((string= kind "ChainingHint")
               (overlay-put overlay 'after-string (propertize (concat ": " label)
                                                              'font-lock-face 'font-lock-comment-face)))
              ))))
       :mode 'tick))
  nil)

(defun lsp-rust-analyzer-initialized? ()
  (when-let ((workspace (lsp-find-workspace 'rust-analyzer)))
    (eq 'initialized (lsp--workspace-status workspace))))

(defun lsp-rust-analyzer-inlay-hints-change-handler (&rest _rest)
  (when lsp-rust-analyzer-inlay-hints-timer
    (cancel-timer lsp-rust-analyzer-inlay-hints-timer))
  (setq lsp-rust-analyzer-inlay-hints-timer
        (run-with-idle-timer 0.1 nil #'lsp-rust-analyzer-update-inlay-hints (current-buffer))))

(define-minor-mode lsp-rust-analyzer-inlay-hints-mode
  "Mode for displaying inlay hints."
  nil nil nil
  (cond
   (lsp-rust-analyzer-inlay-hints-mode
    (lsp-rust-analyzer-update-inlay-hints (current-buffer))
    (add-hook 'lsp-on-change-hook #'lsp-rust-analyzer-inlay-hints-change-handler nil t))
   (t
    (remove-overlays (point-min) (point-max) 'lsp-rust-analyzer-inlay-hint t)
    (remove-hook 'lsp-on-change-hook #'lsp-rust-analyzer-inlay-hints-change-handler t))))

;; activate `lsp-rust-analyzer-inlay-hints-mode'
(when lsp-rust-analyzer-server-display-inlay-hints
  (add-hook 'lsp-after-open-hook (lambda ()
                                   (when (lsp-find-workspace 'rust-analyzer nil)
                                     (lsp-rust-analyzer-inlay-hints-mode)))))

(defun lsp-rust-analyzer-expand-macro ()
  "Expands the macro call at point recursively."
  (interactive)
  (-if-let (workspace (lsp-find-workspace 'rust-analyzer))
      (-if-let* ((params (list :textDocument (lsp--text-document-identifier)
                               :position (lsp--cur-position)))
                 (response (with-lsp-workspace workspace
                             (lsp-send-request (lsp-make-request
                                                "rust-analyzer/expandMacro"
                                                params))))
                 (result (ht-get response "expansion")))
          (funcall lsp-rust-analyzer-macro-expansion-method result)
        (message "No macro found at point, or it could not be expanded."))
    (message "rust-analyzer not running.")))

(defun lsp-rust-analyzer-macro-expansion-default (result)
  "Default method for displaying macro expansion."
  (let* ((root (lsp-workspace-root default-directory))
         (buf (get-buffer-create (get-buffer-create (format "*rust-analyzer macro expansion %s*" root)))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert result)
        (special-mode)))
    (display-buffer buf)))

;; runnables
(defvar lsp-rust-analyzer--last-runnable nil)

(defun lsp-rust-analyzer--runnables-params ()
  (list :textDocument (lsp--text-document-identifier)
        :position (lsp--cur-position)))

(defun lsp-rust-analyzer--runnables ()
  (lsp-send-request (lsp-make-request "rust-analyzer/runnables"
                                      (lsp-rust-analyzer--runnables-params))))

(defun lsp-rust-analyzer--select-runnable ()
  (lsp--completing-read
   "Select runnable:"
   (if lsp-rust-analyzer--last-runnable
       (cons lsp-rust-analyzer--last-runnable (lsp-rust-analyzer--runnables))
     (lsp-rust-analyzer--runnables))
   (-lambda ((&hash "label")) label)))

(defun lsp-rust-analyzer-run (runnable)
  (interactive (list (lsp-rust-analyzer--select-runnable)))
  (-let* (((&hash "env" "bin" "args" "extraArgs" "label") runnable)
          (compilation-environment (-map (-lambda ((k v)) (concat k "=" v)) (ht-items env))))
    (compilation-start
     (string-join (append (list bin) args (when extraArgs '("--")) extraArgs '()) " ")
     ;; cargo-process-mode is nice, but try to work without it...
     (if (functionp 'cargo-process-mode) 'cargo-process-mode nil)
     (lambda (_) (concat "*" label "*")))
    (setq lsp-rust-analyzer--last-runnable runnable)))

(defun lsp-rust-analyzer-rerun (&optional runnable)
  (interactive (list (or lsp-rust-analyzer--last-runnable
                         (lsp-rust-analyzer--select-runnable))))
  (lsp-rust-analyzer-run (or runnable lsp-rust-analyzer--last-runnable)))

(provide 'lsp-rust)
;;; lsp-rust.el ends here

;; Local Variables:
;; flycheck-disabled-checkers: (emacs-lisp-checkdoc)
;; End:
