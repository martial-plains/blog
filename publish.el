;;; publish.el --- Build the blog with Org's publishing system -*- lexical-binding: t; -*-

;; Build:  emacs --batch -l publish.el -f blog-publish
;; Output: public/
;;
;; The first build needs network access: it installs htmlize (syntax
;; highlighting) and org-contrib (which provides ox-rss) from ELPA.

(require 'subr-x)
(require 'package)

;; ---------------------------------------------------------------
;; Packages
;; ---------------------------------------------------------------
;; Neither package ships with Emacs, so install whichever is missing.
;; This has to run before Org is loaded, in case org-contrib pulls in a
;; newer Org than the one bundled with Emacs.
(dolist (archive '(("gnu"    . "https://elpa.gnu.org/packages/")
                   ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
  (unless (assoc (car archive) package-archives)
    (add-to-list 'package-archives archive t)))
(package-initialize)

(defvar blog--archives-refreshed nil)

(defun blog-ensure-package (feature &optional package)
  "Load FEATURE, installing PACKAGE (default: FEATURE) from ELPA if missing."
  (unless (require feature nil t)
    (unless blog--archives-refreshed
      (package-refresh-contents)
      (setq blog--archives-refreshed t))
    (package-install (or package feature))
    (require feature)))

(blog-ensure-package 'htmlize)

(add-to-list 'load-path
             (expand-file-name "lisp" (file-name-directory load-file-name)))

(require 'ox-rss)

(require 'ox-publish)
(require 'ox-html)

;; Colour source blocks with CSS classes (org-keyword, org-string, ...);
;; the colours themselves live in content/css/style.css.
(setq org-html-htmlize-output-type 'css
      org-html-htmlize-font-prefix "org-")

(defvar blog-title "Isaiah's Blog")
(defvar blog-author "Allister Isaiah Harvey")
(defvar blog-description
  "Notes on Icelandic, Emacs, Org mode and the odd projects that grow out of them.")

(defvar blog-base-path (or (getenv "BLOG_BASE") ""))

;; Feed readers need absolute URLs.  BLOG_ORIGIN is scheme + host only,
;; e.g. https://user.github.io; BLOG_BASE (above) supplies any subfolder.
(defvar blog-origin
  (let ((env (getenv "BLOG_ORIGIN")))
    (string-remove-suffix
     "/" (downcase (if (string-empty-p (or env "")) "http://localhost:8000" env)))))
(defvar blog-site-url (concat blog-origin blog-base-path))

;; ---------------------------------------------------------------
;; Paths
;; ---------------------------------------------------------------
(defvar blog-root
  (file-name-as-directory
   (expand-file-name
    (file-name-directory (or load-file-name buffer-file-name default-directory)))))

(defun blog-path (&rest parts)
  (expand-file-name (mapconcat #'identity parts "/") blog-root))

;; Keep Org's publishing cache inside the project.
(setq org-publish-timestamp-directory (blog-path ".cache/"))

;; ---------------------------------------------------------------
;; Page furniture
;; ---------------------------------------------------------------
(defun blog-url (path)
  (concat blog-base-path path))

(defvar blog-head
  (concat
   "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />"
   (format "<link rel=\"stylesheet\" href=\"%s\" />" (blog-url "/css/style.css"))
   (format "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"%s\" href=\"%s\" />"
           blog-title (blog-url "/rss.xml"))))

(defvar blog-preamble
  (format (concat "<header class=\"site-header\">"
                  "<a class=\"site-title\" href=\"%s\">%s</a>"
                  "<nav><a href=\"%s\">Posts</a><a href=\"%s\">About</a>"
                  "<a href=\"%s\">RSS</a></nav>"
                  "</header>")
          (blog-url "/") blog-title
          (blog-url "/posts/") (blog-url "/about.html")
          (blog-url "/rss.xml")))

(defun blog-postamble (info)
  "Footer for every page. Shows the publication date when the page has one."
  (let ((date (ignore-errors (org-export-get-date info "%d %B %Y"))))
    (concat
     "<footer class=\"site-footer\">"
     (if (and (stringp date) (not (string-empty-p date)))
         (format "<p class=\"published\">Published %s</p>" date)
       "")
     (format "<p>&copy; %s %s. Built with Emacs and Org mode.</p>"
             (format-time-string "%Y") blog-author)
     "</footer>")))

(defun blog-sitemap-entry (entry style project)
  "One line of the posts index: link, then date."
  (cond ((not (directory-name-p entry))
         (format "[[file:%s][%s]] — %s"
                 entry
                 (org-publish-find-title entry project)
                 (format-time-string "%d %B %Y"
                                     (org-publish-find-date entry project))))
        ((eq style 'tree)
         (capitalize (file-name-nondirectory (directory-file-name entry))))
        (t entry)))

;; ---------------------------------------------------------------
;; RSS feed
;; ---------------------------------------------------------------
;; ox-rss turns every top-level headline of one Org file into a feed item.
;; Our posts are one file each, so before publishing we write a small
;; .cache/rss/rss.org with a headline per post (title, date, #+DESCRIPTION
;; as the summary, and a link to the full post).  The "blog-rss" project
;; below then turns that file into public/rss.xml.
(defun blog-post-files ()
  "Org files under content/posts, leaving out the generated index.org."
  (let ((index (blog-path "content/posts/index.org")))
    (seq-remove (lambda (file) (file-equal-p file index))
                (directory-files-recursively
                 (blog-path "content/posts") "\\`[^.#].*\\.org\\'"))))

(defun blog-post-meta (file)
  "Return (:title TITLE :date TIME :description TEXT) for the post FILE."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (delay-mode-hooks (org-mode))
    (let* ((kw (org-collect-keywords '("TITLE" "DATE" "DESCRIPTION")))
           (get (lambda (key)
                  (string-trim (mapconcat #'identity (cdr (assoc key kw)) " "))))
           (title (funcall get "TITLE"))
           (date (funcall get "DATE")))
      (list :title (if (string-empty-p title) (file-name-base file) title)
            :date (or (and (not (string-empty-p date))
                           (ignore-errors (org-time-string-to-time date)))
                      (file-attribute-modification-time (file-attributes file)))
            :description (funcall get "DESCRIPTION")))))

(defun blog-plain-title (title)
  "TITLE without Org emphasis markers (/italic/, *bold*, =code=, ...)."
  (replace-regexp-in-string
   "\\(\\`\\|[[:space:](]\\)\\([*/=~+_]\\)\\([^[:space:]]\\(?:[^\n]*?[^[:space:]]\\)?\\)\\2\\([[:space:].,;:!?)]\\|\\'\\)"
   "\\1\\3\\4" title))

(defun blog-write-rss-source ()
  "Write .cache/rss/rss.org, the Org file the feed is built from."
  (let* ((posts-dir (blog-path "content/posts/"))
         (entries (sort (mapcar (lambda (file) (cons file (blog-post-meta file)))
                                (blog-post-files))
                        (lambda (a b)            ; newest first
                          (time-less-p (plist-get (cdr b) :date)
                                       (plist-get (cdr a) :date)))))
         (dir (blog-path ".cache/rss"))
         (coding-system-for-write 'utf-8)
         (system-time-locale "C"))
    (make-directory dir t)
    (with-temp-file (expand-file-name "rss.org" dir)
      (insert (format "#+TITLE: %s\n#+DESCRIPTION: %s\n#+AUTHOR: %s\n#+LANGUAGE: en-GB\n\n"
                      blog-title blog-description blog-author))
      (dolist (entry entries)
        (let* ((meta (cdr entry))
               (path (concat "posts/"
                             (file-name-sans-extension
                              (file-relative-name (car entry) posts-dir))
                             ".html")))
          (insert (format (concat "* %s\n:PROPERTIES:\n:RSS_PERMALINK: %s\n"
                                  ":PUBDATE: %s\n:ID: %s\n:END:\n")
                          (blog-plain-title (plist-get meta :title))
                          path
                          (format-time-string "%Y-%m-%d %a %H:%M" (plist-get meta :date))
                          path))
          (unless (string-empty-p (plist-get meta :description))
            (insert (plist-get meta :description) "\n\n"))
          (insert (format "[[%s/%s][Read the full post]]\n\n" blog-site-url path)))))))

;; Options shared by every HTML component.
(defvar blog-common
  `(:publishing-function org-html-publish-to-html
    :language "en-GB"
    :with-toc nil
    :section-numbers nil
    :with-author nil
    :with-creator nil
    :time-stamp-file nil
    :html-doctype "html5"
    :html-html5-fancy t
    :html-head-include-default-style nil
    :html-head-include-scripts nil
    :html-validation-link nil
    :html-head ,blog-head
    :html-preamble ,blog-preamble
    :html-postamble blog-postamble))

;; ---------------------------------------------------------------
;; Projects
;; ---------------------------------------------------------------
(setq org-publish-project-alist
      `(("blog-pages"                     ; content/*.org  (home, about)
         :base-directory ,(blog-path "content")
         :base-extension "org"
         :recursive nil
         :publishing-directory ,(blog-path "public")
         ,@blog-common)

        ("blog-posts"                     ; content/posts/*.org  + generated index
         :base-directory ,(blog-path "content/posts")
         :base-extension "org"
         :recursive t
         :publishing-directory ,(blog-path "public/posts")
         :auto-sitemap t
         :sitemap-filename "index.org"
         :sitemap-title "Posts"
         :sitemap-style list
         :sitemap-sort-files anti-chronologically
         :sitemap-format-entry blog-sitemap-entry
         ,@blog-common)

        ("blog-rss"                       ; .cache/rss/rss.org -> public/rss.xml
         :base-directory ,(blog-path ".cache/rss")
         :base-extension "org"
         :recursive nil
         :publishing-directory ,(blog-path "public")
         :publishing-function org-rss-publish-to-rss
         :rss-extension "xml"
         :html-link-home ,blog-site-url
         :html-link-use-abs-url t
         :with-toc nil
         :section-numbers nil)

        ("blog-static"                    ; css, images, etc. copied as they are
         :base-directory ,(blog-path "content")
         :base-extension "css\\|js\\|png\\|jpg\\|jpeg\\|gif\\|svg\\|webp\\|ico\\|txt"
         :recursive t
         :publishing-directory ,(blog-path "public")
         :publishing-function org-publish-attachment)

        ("blog" :components ("blog-pages" "blog-posts" "blog-rss" "blog-static"))))

;; ---------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------
(defun blog-publish ()
  "Build the whole site into public/."
  (interactive)
  (blog-write-rss-source)
  (org-publish "blog" t)
  ;; Stop GitHub Pages running Jekyll over the output.
  (write-region "" nil (blog-path "public/.nojekyll") nil 'silent)
  (message "Blog published to %s" (blog-path "public")))

(provide 'publish)
;;; publish.el ends here
