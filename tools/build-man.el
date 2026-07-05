;;; build-man.el --- generate groff man pages from doc/*.org via ox-man -*- lexical-binding: t; -*-

;; Run from the repo root:
;;   emacs --batch -l tools/build-man.el
;; For each doc/<name>.org this writes man/man1/<name>.1, using ox-man for the
;; section bodies and a hand-built .TH line (ox-man's own template cannot emit
;; the date/version fields).

(require 'org)
(require 'ox-man)

(defun build-man--section-id (class-options)
  "Parse the :section-id value from a MAN_CLASS_OPTIONS keyword string.
Falls back to \"1\" when absent or unreadable."
  (let ((raw (or (cadr (assoc "MAN_CLASS_OPTIONS" class-options)) "")))
    (condition-case nil
        (let* ((attr (read (format "(%s)" raw)))
               (sid (plist-get attr :section-id)))
          (if (and sid (stringp sid)) sid "1"))
      (error "1"))))

(defun build-man-file (org-file out-file)
  "Convert ORG-FILE to OUT-FILE (groff man) using ox-man."
  ;; Resolve OUT-FILE to an absolute path before `find-file' changes
  ;; `default-directory' to ORG-FILE's directory.
  (let ((out-file (expand-file-name out-file)))
  (with-current-buffer (find-file org-file)
    (org-mode)
    (let* ((kw     (org-collect-keywords '("TITLE" "DATE" "MAN_VERSION"
                                           "MAN_CLASS_OPTIONS")))
           (title  (or (cadr (assoc "TITLE" kw)) (file-name-base org-file)))
           (date   (or (cadr (assoc "DATE" kw)) ""))
           (ver    (or (cadr (assoc "MAN_VERSION" kw)) ""))
           (sect   (build-man--section-id kw))
           (body   (org-export-as 'man))
           (th     (if (string= ver "")
                       (format ".TH \"%s\" \"%s\" \"%s\"" title sect date)
                     (format ".TH \"%s\" \"%s\" \"%s\" \"%s\""
                             title sect date ver)))
           (out    (replace-regexp-in-string
                    "^\\.TH [^\n]*\n" (concat th "\n") body t)))
      (make-directory (file-name-directory out-file) t)
      (with-temp-buffer
        (insert out)
        (write-region (point-min) (point-max) out-file nil 'silent))
      (message "built %s -> %s" org-file out-file)))))

(let ((docs (directory-files "doc" t "\\.org\\'")))
  (dolist (f docs)
    (build-man-file f (concat "man/man1/" (file-name-base f) ".1")))
  (message "done: %d page(s)" (length docs)))