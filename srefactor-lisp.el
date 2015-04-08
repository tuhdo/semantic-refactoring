;;; Srefactor --- A refactoring tool based on Semantic parser framework
;;
;; Filename: srefactor-lisp.el
;; Description: A refactoring tool based on Semantic parser framework
;; Author: Tu, Do Hoang <tuhdo1710@gmail.com>
;; URL      : https://github.com/tuhdo/semantic-refactor
;; Maintainer: Tu, Do Hoang
;; Created: Wed Feb 11 21:25:51 2015 (+0700)
;; Version: 0.3
;; Package-Requires: ((emacs "24.4"))
;; Last-Updated: Wed Feb 11 21:25:51 2015 (+0700)
;;           By: Tu, Do Hoang
;;     Update #: 1
;; URL:
;; Doc URL:
;; Keywords: emacs-lisp, languages, tools
;; Compatibility: GNU Emacs: 24.3+
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;; Semantic is a package that provides a framework for writing
;; parsers. Parsing is a process of analyzing source code based on
;; programming language syntax. This package relies on Semantic for
;; analyzing source code and uses its results to perform smart code
;; refactoring that based on code structure of the analyzed language,
;; instead of plain text structure.
;;
;; This package provides the following features for Emacs Lisp:
;;
;; - `srefactor-elisp-format-buffer': Format whole buffer.
;; - `srefactor-elisp-format-defun': Format the current defun point is in.
;; - `srefactor-elisp-one-line': Transform all sub-sexpressions current sexpression at
;; point into one line separated each one by a space.
;;
;; - `srefactor-elisp-multi-line': Transform all sub-sexpressions current sexpression
;; - at point into multiple lines separated. If the head symbol belongs to the
;; - list `srefactor-elisp-symbol-to-skip', then the first N next symbol/sexpressions
;; - (where N is the nummber associated with the head symbol as stated in the
;; - list) are skipped before a newline is inserted.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:
(require 'semantic/bovine/el)

(defcustom srefactor-newline-threshold 30
  "After a token is inserted, if the length of current
  S-EXPRESSION is greater than this value, start inserting a newline.")

(defcustom srefactor-elisp-symbol-to-skip '(;; ("progn" . 0)
                                            ("cond" . 0)
                                            ;; ("save-excursion" . 0)
                                            ("unwind-protect" . 0)
                                            ("condition-case " . 1)
                                            ("with-current-buffer" . 1)
                                            ;; ("let" . 1)
                                            ;; ("let*" . 1)
                                            ("if" . 1)
                                            ;; ("while" . 1)
                                            ;; ("dolist" . 1)
                                            ("do" . 1)
                                            ;; ("when" . 1)
                                            ("buffer-substring-no-properties" . 0)
                                            ("unless" . 1)
                                            ("not" . 1)
                                            ("null" . 1)
                                            ("null?" . 1)
                                            ("or" . 1)
                                            ("and" . 1)
                                            ("catch" . 1)
                                            ("mapcar" . 1)
                                            ("mapcan" . 1)
                                            ("mapc" . 1)
                                            ("+" . 1)
                                            ("-" . 1)
                                            ("*" . 1)
                                            ("/" . 1)
                                            ("error" . 1)
                                            ("goto-char" . 1)
                                            ("insert" . 1)
                                            ("car" . 1)
                                            ("cdr" . 1)
                                            ("lambda" . 1)
                                            ("cons" . 2)
                                            ("kill-region" . 2)
                                            ("equal" . 2)
                                            ("concat" . 2)
                                            ("member" . 2)
                                            ("eq?" . 2)
                                            ("eq" . 2)
                                            ("get" . 2)
                                            ("assoc" . 2)
                                            ;; ("defun" . 2)
                                            ("defn" . 1)
                                            ("defclass" . 2)
                                            ;; ("defmacro" . 2)
                                            ("defsubst" . 2)
                                            ("defface" . 2)
                                            ("defalias" . 2)
                                            ("defcustom" . 2)
                                            ("declare" . 2)
                                            ("defvar" . 2)
                                            ("string-match" . 2)
                                            ("defcustom" . 2)
                                            ("setq" . 2)
                                            ("setq-default" . 2)
                                            ("setf" . 2)
                                            (">" . 2)
                                            ("<" . 2)
                                            ("<=" . 2)
                                            (">=" . 2)
                                            ("/=" . 2)
                                            ("=" . 2)
                                            ("1" . 2)
                                            ("1" . 2)
                                            )
  "A list of pairs of a symbol and a number that denotes how many
  sexp to skip before inserting the first newline. "
  :group 'srefactor)

(defun srefactor--appropriate-major-mode (major-mode)
  (cond
   ((eq major-mode 'emacs-lisp-mode)
    (emacs-lisp-mode))
   ((eq major-mode 'scheme-mode)
    (scheme-mode))
   ((eq major-mode 'common-lisp-mode)
    (common-lisp-mode))
   ((and (fboundp 'clojure-mode)
         (eq major-mode 'clojure-mode))
    (clojure-mode))
   (t (emacs-lisp-mode))))

(defun srefactor-lisp-format-buffer ()
  "Format current buffer."
  (interactive)
  (let ((cur-pos (point)))
    (goto-char (point-max))
    (while (beginning-of-defun-raw)
      (let* ((orig-point (point))
             (beg (point))
             (end (save-excursion
                    (forward-sexp)
                    (point)))
             (cur-major-mode major-mode)
             (tmp-buf (generate-new-buffer "tmp-buf"))
             (content (buffer-substring-no-properties beg end)))
        (unwind-protect
            (progn
              (setq content (with-current-buffer tmp-buf
                              (semantic-default-elisp-setup)
                              (semantic-lex-init)
                              (insert content)
                              (srefactor-one-or-multi-lines (point-min)
                                                            (point-max)
                                                            (point-min)
                                                            'multi-line
                                                            nil
                                                            t)
                              (srefactor--appropriate-major-mode cur-major-mode)
                              (indent-region (point-min)
                                             (point-max))
                              (buffer-substring-no-properties
                               (point-min)
                               (point-max))))
              (goto-char beg)
              (kill-region beg end)
              (insert content)
              (goto-char orig-point))
          (kill-buffer tmp-buf))))
    (goto-char cur-pos)))

(defun srefactor-lisp-format-defun ()
  "Format current defun point is in."
  (interactive)
  (let* ((orig-point (point))
         (beg (save-excursion
                (beginning-of-defun-raw)
                (point)))
         (end (save-excursion
                (goto-char beg)
                (forward-sexp)
                (point)))
         (cur-major-mode major-mode)
         (tmp-buf (generate-new-buffer "tmp-buf"))
         (content (buffer-substring-no-properties beg end)))
    (unwind-protect
        (progn
          (setq content (with-current-buffer tmp-buf
                          (semantic-default-elisp-setup)
                          (semantic-lex-init)
                          (insert content)
                          (srefactor-one-or-multi-lines (point-min)
                                                        (point-max)
                                                        (point-min)
                                                        'multi-line
                                                        nil
                                                        t)
                          (srefactor--appropriate-major-mode cur-major-mode)
                          (indent-region (point-min)
                                         (point-max))
                          (buffer-substring-no-properties
                           (point-min)
                           (point-max))))
          (goto-char beg)
          (kill-region beg end)
          (insert content)
          (goto-char orig-point))
      (kill-buffer tmp-buf))))

(defun srefactor-lisp-one-line (recursive-p)
  "Transform all sub-sexpressions current sexpression at point
into one line separated each one by a space."
  (interactive "P")
  (let* ((orig-point (point))
         (beg (save-excursion
                (unless (looking-at "(")
                  (backward-up-list))
                (point)))
         (end (save-excursion
                (goto-char beg)
                (forward-sexp)
                (point)))
         (cur-major-mode major-mode)
         (tmp-buf (generate-new-buffer "tmp-buf"))
         (content (buffer-substring-no-properties beg end)))
    (unwind-protect
        (progn
          (setq content (with-current-buffer tmp-buf
                          (semantic-default-elisp-setup)
                          (semantic-lex-init)
                          (insert content)
                          (srefactor-one-or-multi-lines (point-min)
                                                        (point-max)
                                                        (point-min)
                                                        'one-line
                                                        nil
                                                        recursive-p)
                          (srefactor--appropriate-major-mode cur-major-mode)
                          (indent-region (point-min)
                                         (point-max))
                          (buffer-substring-no-properties
                           (point-min)
                           (point-max))))
          (goto-char beg)
          (kill-region beg end)
          (insert content)
          (goto-char orig-point))
      (kill-buffer tmp-buf))))

(defun srefactor-lisp-multi-line ()
  "Transform all sub-sexpressions current sexpression at point
into multiple lines separated. If the head symbol belongs to the
list `srefactor-elisp-symbol-to-skip', then the first N next
symbol/sexpressions (where N is the nummber associated with the
head symbol as stated in the list) are skipped before a newline
is inserted."
  (interactive)
  (let* ((orig-point (point))
         (beg (save-excursion
                (unless (looking-at "(")
                  (backward-up-list))
                (point)))
         (end (save-excursion
                (goto-char beg)
                (forward-sexp)
                (point)))
         (cur-major-mode major-mode)
         (tmp-buf (generate-new-buffer "tmp-buf"))
         (content (buffer-substring-no-properties beg end)))
    (unwind-protect
        (progn
          (setq content (with-current-buffer tmp-buf
                          (semantic-lex-init)
                          (semantic-default-elisp-setup)
                          (insert content)
                          (srefactor-one-or-multi-lines (point-min)
                                                        (point-max)
                                                        (point-min)
                                                        'multi-line
                                                        nil
                                                        t)
                          (srefactor--appropriate-major-mode cur-major-mode)
                          (indent-region (point-min)
                                         (point-max))
                          (buffer-substring-no-properties
                           (point-min)
                           (point-max))))
          (goto-char beg)
          (kill-region beg end)
          (insert content)
          (goto-char orig-point))
      (kill-buffer tmp-buf))))

(defun srefactor-one-or-multi-lines (beg end orig-point format-type &optional newline-betwen-semantic-lists recursive-p)
  "Turn the current sexpression into one line/multi-line depends
on the value of FORMAT-TYPE. If FORMAT-TYPE is 'one-line,
transforms all sub-sexpressions of the same level into one
line. If FORMAT-TYPE is 'multi-line, transforms all
sub-sexpressions of the same level into multiple lines.

Return the position of last closing sexp."
  (let* ((lexemes (semantic-emacs-lisp-lexer beg end 1))
         (first-token (cadr lexemes))
         (first-token-name (buffer-substring-no-properties
                            (semantic-lex-token-start first-token)
                            (semantic-lex-token-end first-token)))
         (second-token (caddr lexemes))
         (tmp-buf (generate-new-buffer (make-temp-name "")))
         (orig-format-type format-type)
         token-str
         ignore-pair
         token
         ignore-num)
    (unwind-protect
        (progn
          (unless (assoc 'semantic-list lexemes)
            (setq format-type 'one-line))
          (if (or (eq (car first-token) 'semantic-list)
                  (assoc first-token-name srefactor-elisp-symbol-to-skip))
              (setq newline-betwen-semantic-lists t)
            (setq newline-betwen-semantic-lists nil))
          (while lexemes
            (setq token (pop lexemes))
            (setq token-str (if token
                                (buffer-substring-no-properties
                                 (semantic-lex-token-start token)
                                 (semantic-lex-token-end token))
                              ""))
            (let* ((token-type (car token))
                   (tok-start (semantic-lex-token-start token))
                   (tok-end (semantic-lex-token-end token))
                   (next-token (car lexemes))
                   (next-token-type (car next-token))
                   (next-token-str (if next-token
                                       (buffer-substring-no-properties
                                        (semantic-lex-token-start next-token)
                                        (semantic-lex-token-end next-token))
                                     ""))
                   (next-next-token (cadr lexemes))
                   (next-next-token-type (car next-next-token))
                   (next-next-token-str (if next-next-token
                                            (buffer-substring-no-properties
                                             (semantic-lex-token-start next-token)
                                             (semantic-lex-token-end next-token))
                                          "")))
              (with-current-buffer tmp-buf
                (insert token-str)
                (cond
                 ((member (concat token-str next-token-str) '("1-" "1+"))
                  (goto-char (semantic-lex-token-end token))
                  (insert (concat next-token-str " "))
                  (pop lexemes))
                 ((or (eq token-type 'punctuation)
                      (eq token-type 'open-paren)
                      (eq token-type 'close-paren)
                      (eq next-token-type 'close-paren))
                  "")
                 ((equal token-str ".")
                  (insert (concat " " next-token-str))
                  (pop lexemes))
                 ((and (eq token-type 'symbol)
                       (eq orig-format-type 'multi-line)
                       (string-match ":.*" token-str))
                  (insert (concat " " next-token-str))
                  (if (not (eq next-next-token-type 'close-paren))
                      (insert "\n")
                    (insert next-next-token-str)
                    (pop lexemes))
                  (pop lexemes))
                 ((eq format-type 'one-line)
                  (insert " "))
                 ((eq format-type 'multi-line)
                  (insert "\n"))))))
          (goto-char beg)
          (kill-region beg end)
          (save-excursion
            (insert (with-current-buffer tmp-buf
                      (buffer-substring-no-properties
                       (point-min)
                       (point-max))))
            (when (eq format-type 'multi-line)
              (goto-char beg)
              (setq ignore-pair (assoc first-token-name srefactor-elisp-symbol-to-skip))
              (setq ignore-num (or (cdr ignore-pair)
                                   (get (intern first-token-name) 'lisp-indent-function)))
              (cond
               (ignore-num
                (save-excursion
                  (while (> ignore-num 0)
                    (forward-line 1)
                    (delete-indentation)
                    (setq ignore-num (1- ignore-num)))))
               ((not (member (car second-token) `(,(when newline-betwen-semantic-lists 'semantic-list)
                                                  close-paren
                                                  open-paren)))
                (forward-line 1)
                (delete-indentation)))))
          (when recursive-p
            (goto-char beg)
            (forward-sexp)
            (setq end (point))
            (setq lexemes (semantic-emacs-lisp-lexer beg end 1))
            (dolist (token
                     (reverse lexemes))
              (let ((tok-start (semantic-lex-token-start token))
                    (tok-end (semantic-lex-token-end token)))
                (when (and (eq (car token) 'semantic-list)
                           (> (- tok-end tok-start) 2))
                  (goto-char (semantic-lex-token-start token))
                  (srefactor-one-or-multi-lines tok-start
                                                tok-end
                                                tok-start
                                                format-type
                                                newline-betwen-semantic-lists
                                                recursive-p))))))
      (kill-buffer tmp-buf))))

(provide 'srefactor-lisp)