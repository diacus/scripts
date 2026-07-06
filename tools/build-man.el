;;; build-man.el --- generate groff man pages from doc/*.org via ox-man -*- lexical-binding: t; -*-

;; Run from the repo root:
;;   emacs --batch -l tools/build-man.el
;; For each doc/<name>.org this writes man/man<sect>/<name>.<sect>, where
;; <sect> is read from the org file's MAN_CLASS_OPTIONS :section-id keyword
;; (defaulting to 1).  Uses ox-man for the section bodies and a hand-built
;; .TH line (ox-man's own template cannot emit the date/version fields).

(require 'org)
(require 'ox-man)

(defun build-man--section-id (class-options)
  "Parse the :section-id value from a MAN_CLASS_OPTIONS keyword string.
Accepts either an integer (e.g. \"5\") or a string (e.g. \"\\\"5\\\"\").
Falls back to \"1\" when absent or unreadable."
  (let ((raw (or (cadr (assoc "MAN_CLASS_OPTIONS" class-options)) "")))
    (condition-case nil
        (let* ((attr (read (format "(%s)" raw)))
               (sid (plist-get attr :section-id)))
          (cond
           ((stringp sid) sid)
           ((integerp sid) (number-to-string sid))
           (t "1")))
      (error "1"))))

(defun build-man-file (org-file root)
  "Convert ORG-FILE to a groff man page under man/man<sect>/ using ox-man.
The output section is discovered from the org file's MAN_CLASS_OPTIONS
:section-id keyword (falling back to \"1\").  ROOT is the repo root
directory; the output path is resolved against it before `find-file'
changes `default-directory' to ORG-FILE's directory."
  (with-current-buffer (find-file org-file)
    (org-mode)
    (let* ((kw       (org-collect-keywords '("TITLE" "DATE" "MAN_VERSION"
                                             "MAN_CLASS_OPTIONS")))
           (title    (or (cadr (assoc "TITLE" kw)) (file-name-base org-file)))
           (date     (or (cadr (assoc "DATE" kw)) ""))
           (ver      (or (cadr (assoc "MAN_VERSION" kw)) ""))
           (sect     (build-man--section-id kw))
           (out-file (expand-file-name
                      (format "man/man%s/%s.%s"
                              sect (file-name-base org-file) sect)
                      root))
           (body     (org-export-as 'man))
           (th       (if (string= ver "")
                         (format ".TH \"%s\" \"%s\" \"%s\"" title sect date)
                       (format ".TH \"%s\" \"%s\" \"%s\" \"%s\""
                               title sect date ver)))
           (out      (replace-regexp-in-string
                      "^\\.TH [^\n]*\n" (concat th "\n") body t)))
      (make-directory (file-name-directory out-file) t)
      (with-temp-buffer
        (insert out)
        (write-region (point-min) (point-max) out-file nil 'silent))
      (message "built %s -> %s" org-file out-file))))

(let ((docs (directory-files "doc" t "\\.org\\'"))
      (root default-directory))
  (dolist (f docs)
    (build-man-file f root))
  (message "done: %d page(s)" (length docs)))