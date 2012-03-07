;;; command-log-mode.el --- log keyboard commands to buffer

;; Copyright (C) 2004  Free Software Foundation, Inc.

;; Author: Michael Weber <michaelw@foldr.org>
;; Keywords: help
;; Initial-version: <2004-10-07 11:41:28 michaelw>
;; Time-stamp: <2004-11-06 17:08:11 michaelw>

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This add-on can be used to demo Emacs to an audience.  When
;; activated, keystrokes get logged into a designated buffer, along
;; with the command bound to them.

;; To enable, use e.g.:
;;
;; (add-hook 'LaTeX-mode-hook (function clm/log-keyboard-commands))
;;
;; To see the log buffer, call M-x clm/open-command-log-buffer.

;;; Code:

(eval-when-compile (require 'cl))

(defvar clm/lm*log-command-exceptions*
  '(nil self-insert-command backward-char forward-char
        delete-char delete-backward-char backward-delete-char
        backward-delete-char-untabify
        universal-argument universal-argument-other-key
        universal-argument-minus universal-argument-more
        beginning-of-line end-of-line recenter
        move-end-of-line move-beginning-of-line
        handle-switch-frame
        newline previous-line next-line)
  "A list commands which should not be logged, despite logging being enabled.
Frequently used non-interesting commands (like cursor movements) should be put here.")

(defvar clm/lm*command-log-buffer* nil
  "Reference of the currenly used buffer to display logged commands.")
(defvar clm/lm*command-repetitions* 0
  "Count of how often the last keyboard commands has been repeated.")
(defvar clm/lm*last-keyboard-command* nil
  "Last logged keyboard command.")


(defvar clm/lm*log-command-indentation* 11
  "*Indentation of commands in command log buffer.")

;;;###autoload
(define-minor-mode command-log-mode
  "Toggle keyboard command logging."
  :init-value nil
  :lighter " command-log"
  :keymap nil)

(define-global-minor-mode global-command-log-mode command-log-mode
  command-log-mode)

(defun clm/lmbuffer-log-command-p (cmd &optional buffer)
  "Determines whether keyboard command CMD should be logged.
If non-nil, BUFFER specifies the buffer used to determine whether CMD should be logged.
If BUFFER is nil, the current buffer is assumed."
  (let ((val (if buffer
		 (buffer-local-value command-log-mode buffer)
	       command-log-mode)))
    (and (not (null val))
	 (null (member cmd clm/lm*log-command-exceptions*)))))

(defmacro clm/lmwith-saved-command-environment (&rest body)
  (declare (indent 0))
  `(let ((deactivate-mark nil) ; do not deactivate mark in transient
                                        ; mark mode
	 ;; do not let random commands scribble over
	 ;; {THIS,LAST}-COMMAND
	 (this-command this-command)
	 (last-command last-command))
     ,@body))

(defun clm/lmopen-command-log-buffer (&optional arg)
  "Opens (and creates, if non-existant) a buffer used for logging keyboard commands.
If ARG is Non-nil, the existing command log buffer is cleared."
  (interactive "P")
  (prog1 (setq clm/lm*command-log-buffer* (get-buffer-create " *command-log*"))
    (when arg (with-current-buffer clm/lm*command-log-buffer*
		(erase-buffer)))
    (pop-to-buffer clm/lm*command-log-buffer* nil t)))

(defun clm/lmscroll-buffer-window (buffer &optional move-fn)
  "Updates `point' of windows containing BUFFER according to MOVE-FN.
If non-nil, MOVE-FN is called on every window which displays BUFFER.
If nil, MOVE-FN defaults to scrolling to the bottom, making the last line visible.

Scrolling up can be accomplished with:
\(clm/lmscroll-buffer-window buf (lambda () (goto-char (point-min))))
"
  (let ((selected (selected-window))
	(point-mover (or move-fn
			 (function (lambda () (goto-char (point-max)))))))
    (walk-windows (function (lambda (window)
			      (when (eq (window-buffer window) buffer)
				(select-window window)
				(funcall point-mover)
				(select-window selected))))
		  nil t)))

(defmacro clm/lmwith-command-log-buffer (&rest body)
  (declare (indent 0))
  `(when (and (not (null clm/lm*command-log-buffer*))
	      (buffer-name clm/lm*command-log-buffer*))
     (with-current-buffer clm/lm*command-log-buffer*
       ,@body)))

(defun clm/lmlog-command (&optional cmd)
  "Hook into `pre-command-hook' to intercept command activation."
  (clm/lmwith-saved-command-environment
    (setq cmd (or cmd this-command))
    (when (clm/lmbuffer-log-command-p cmd)
      (clm/lmwith-command-log-buffer
        (let ((current (current-buffer)))
          (goto-char (point-max))
          (cond ((eq cmd clm/lm*last-keyboard-command*)
                 (incf clm/lm*command-repetitions*)
                 (save-match-data
                   (when (and (> clm/lm*command-repetitions* 1)
                              (search-backward "[" (line-beginning-position -1) t))
                     (delete-region (point) (line-end-position))))
                 (backward-char) ; skip over either ?\newline or ?\space before ?\[
                 (insert " [")
                 (princ (1+ clm/lm*command-repetitions*) current)
                 (insert " times]"))
                (t ;; (message "last cmd: %s cur: %s" last-command cmd)
                 (setq clm/lm*command-repetitions* 0)
                 (insert (key-description (this-command-keys)))
                 (when (>= (current-column) clm/lm*log-command-indentation*)
                   (newline))
                 (move-to-column clm/lm*log-command-indentation* t)
                 (princ cmd current)
                 (newline)
                 (setq clm/lm*last-keyboard-command* cmd)))
          (clm/lmscroll-buffer-window current))))))

(add-hook 'pre-command-hook 'clm/lmlog-command)

(provide 'command-log-mode)
;;; command-log-mode.el ends here
