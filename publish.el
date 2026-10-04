;;; publish.el --- Build the blog with Org's publishing system -*- lexical-binding: t; -*-

;; Build:  emacs --batch -l publish.el -f blog-publish
;; Output: public/
;;
;; The first build needs network access: it installs htmlize (syntax
;; highlighting) and org-contrib (which provides ox-rss) from ELPA.

(require 'subr-x)
(require 'cl-lib)
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
;; English month names whatever language the operating system uses.
(setq system-time-locale "C")

(defun blog-url (path)
  (concat blog-base-path path))

(defvar blog-head
  (concat
   "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />"
   "<meta name=\"color-scheme\" content=\"light dark\" />"
   ;; Apply a saved theme before the page paints, so there is no flash.
   "<script>try{var t=localStorage.getItem('theme');if(t)document.documentElement.dataset.theme=t}catch(e){}</script>"
   (format "<link rel=\"stylesheet\" href=\"%s\" />" (blog-url "/css/style.css"))
   (format "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"%s\" href=\"%s\" />"
           blog-title (blog-url "/rss.xml"))
   (format "<script defer src=\"%s\"></script>" (blog-url "/js/site.js"))))

(defun blog-keyword (info key)
  "Value of the #+KEY: line in the page being exported, or nil."
  (org-element-map (plist-get info :parse-tree) 'keyword
    (lambda (k)
      (when (string= (upcase (org-element-property :key k)) key)
        (string-trim (org-element-property :value k))))
    info t))

(defun blog-info-date (info)
  "The page's #+DATE: as a time value, or nil."
  (let ((d (blog-keyword info "DATE")))
    (and d (not (string-empty-p d))
         (ignore-errors (org-time-string-to-time d)))))

(defun blog-date-string (time)
  (string-trim-left (format-time-string "%d %B %Y" time) "0"))

(defun blog-initials ()
  (let ((words (split-string blog-author)))
    (upcase (concat (substring (car words) 0 1)
                    (substring (car (last words)) 0 1)))))

(defun blog-svg (body)
  (format (concat "<svg viewBox=\"0 0 24 24\" width=\"18\" height=\"18\" fill=\"none\" "
                  "stroke=\"currentColor\" stroke-width=\"1.7\" stroke-linecap=\"round\" "
                  "stroke-linejoin=\"round\" aria-hidden=\"true\">%s</svg>")
          body))

;; Header of every page except the posts index: optional hero image,
;; title, and (for dated posts) the date and author line.
(defun blog-preamble (info)
  (unless (equal (blog-keyword info "LAYOUT") "list")
    (let ((hero (blog-keyword info "HERO"))
          (time (blog-info-date info)))
      (concat
       (when (and hero (not (string-empty-p hero)))
         (format "<div class=\"hero\"><img src=\"%s\" alt=\"\" /></div>"
                 (blog-url (concat "/" hero))))
       (format "<h1 class=\"title\">%s</h1>"
               (org-export-data (plist-get info :title) info))
       (when time
         (format (concat "<div class=\"post-meta\"><time datetime=\"%s\">%s</time>"
                         "<span class=\"author\"><span class=\"avatar\">%s</span>%s</span></div>")
                 (format-time-string "%F" time)
                 (blog-date-string time)
                 (blog-initials)
                 blog-author))))))

;; The floating bar at the bottom of every page (see content/js/site.js).
(defvar blog-dock
  (concat
   "<div class=\"bottom-fade\" aria-hidden=\"true\"></div>"
   "<nav class=\"dock\" aria-label=\"Site\">"
   ;; Search box (with its results list) and, on long pages, a button that opens it.
   "<div class=\"dock-search\"><label>"
   (blog-svg "<circle cx=\"11\" cy=\"11\" r=\"8\"/><path d=\"m21 21-4.3-4.3\"/>")
   (format (concat "<input id=\"dock-search\" type=\"search\" placeholder=\"Search posts\" "
                   "autocomplete=\"off\" aria-label=\"Search posts\" data-index=\"%s\" />")
           (blog-url "/search-index.json"))
   "<kbd>Ctrl K</kbd></label>"
   "<ul id=\"search-results\" class=\"results\" role=\"listbox\" hidden></ul></div>"
   "<button id=\"search-open\" type=\"button\" aria-label=\"Search posts\" title=\"Search\">"
   (blog-svg "<circle cx=\"11\" cy=\"11\" r=\"8\"/><path d=\"m21 21-4.3-4.3\"/>")
   "</button>"
   ;; Which part of the post you are reading, with a progress ring.
   "<span class=\"dock-section\"><i class=\"dot\"></i><span id=\"dock-label\"></span>"
   "<svg class=\"ring\" viewBox=\"0 0 20 20\" width=\"18\" height=\"18\" aria-hidden=\"true\">"
   "<circle class=\"track\" cx=\"10\" cy=\"10\" r=\"8\"/>"
   "<circle class=\"bar\" cx=\"10\" cy=\"10\" r=\"8\" pathLength=\"1\"/></svg></span>"
   "<span class=\"sep\"></span>"
   "<button id=\"theme-toggle\" type=\"button\" aria-label=\"Toggle light and dark theme\" title=\"Theme\">"
   "<span class=\"icon-moon\">"
   (blog-svg "<path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z\"/>")
   "</span><span class=\"icon-sun\">"
   (blog-svg (concat "<circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2m0 16v2M4.93 4.93l1.41 1.41"
                     "m11.32 11.32 1.41 1.41M2 12h2m16 0h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41\"/>"))
   "</span></button>"
   (format "<a href=\"%s\" aria-label=\"Home\" title=\"Home\">%s</a>" (blog-url "/")
           (blog-svg "<path d=\"m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\"/><path d=\"M9 22V12h6v10\"/>"))
   (format "<a href=\"%s\" aria-label=\"About\" title=\"About\">%s</a>" (blog-url "/about.html")
           (blog-svg "<circle cx=\"12\" cy=\"8\" r=\"4\"/><path d=\"M4 21a8 8 0 0 1 16 0\"/>"))
   (format "<a class=\"dock-text\" href=\"%s\" title=\"All posts\">%s<span>Posts</span></a>"
           (blog-url "/posts/")
           (blog-svg "<path d=\"M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01\"/>"))
   "</nav>"))

(defun blog-postamble (info)
  "Footer for every page: end-of-post links (dated posts only), colophon, dock."
  (concat
   (when (blog-info-date info)
     (format (concat "<nav class=\"endnav\"><a href=\"%s\">&larr; Read more posts</a>"
                     "<a href=\"%s\">Subscribe via RSS &rarr;</a></nav>")
             (blog-url "/posts/") (blog-url "/rss.xml")))
   (format "<p class=\"colophon\">&copy; %s %s. Built with Emacs and Org mode.</p>"
           (format-time-string "%Y") blog-author)
   blog-dock))

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
  "Return (:title :date :description :tags :hero) for the post FILE."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (delay-mode-hooks (org-mode))
    (let* ((kw (org-collect-keywords '("TITLE" "DATE" "DESCRIPTION" "FILETAGS" "HERO")))
           (get (lambda (key)
                  (string-trim (mapconcat #'identity (cdr (assoc key kw)) " "))))
           (title (funcall get "TITLE"))
           (date (funcall get "DATE")))
      (list :title (if (string-empty-p title) (file-name-base file) title)
            :date (or (and (not (string-empty-p date))
                           (ignore-errors (org-time-string-to-time date)))
                      (file-attribute-modification-time (file-attributes file)))
            :description (funcall get "DESCRIPTION")
            :tags (split-string (funcall get "FILETAGS") "[: ]+" t)
            :hero (funcall get "HERO")))))

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

;; ---------------------------------------------------------------
;; Posts index
;; ---------------------------------------------------------------
;; Written to content/posts/index.org before publishing (it is git-ignored).
;; The list is raw HTML so each row can carry its tags and hero image; the
;; tag pills, search box and hover preview are driven by content/js/site.js.
(defun blog-tag-order (entries)
  "All tags used by ENTRIES, most used first."
  (let (counts)
    (dolist (entry entries)
      (dolist (tag (plist-get (cdr entry) :tags))
        (let ((cell (assoc tag counts)))
          (if cell (cl-incf (cdr cell)) (push (cons tag 1) counts)))))
    (mapcar #'car (sort (nreverse counts) (lambda (a b) (> (cdr a) (cdr b)))))))

(defun blog-write-posts-index ()
  (let* ((posts-dir (blog-path "content/posts/"))
         (entries (sort (mapcar (lambda (file) (cons file (blog-post-meta file)))
                                (blog-post-files))
                        (lambda (a b)            ; newest first
                          (time-less-p (plist-get (cdr b) :date)
                                       (plist-get (cdr a) :date)))))
         (coding-system-for-write 'utf-8))
    (with-temp-file (expand-file-name "index.org" posts-dir)
      (insert "#+TITLE: Posts\n#+LAYOUT: list\n#+LANGUAGE: en-GB\n\n#+begin_export html\n")
      (insert (format "<header class=\"list-head\"><h1 class=\"title\">Posts</h1><p class=\"lede\">%s</p></header>\n"
                      (org-html-encode-plain-text blog-description)))
      (let ((tags (blog-tag-order entries)))
        (when tags
          (insert "<div class=\"pills\" role=\"group\" aria-label=\"Filter by topic\">")
          (insert "<button type=\"button\" class=\"pill is-active\" data-tag=\"\">All</button>")
          (dolist (tag tags)
            (insert (format "<button type=\"button\" class=\"pill\" data-tag=\"%s\">%s</button>"
                            (downcase tag) (org-html-encode-plain-text tag))))
          (insert "</div>\n")))
      (insert "<ul class=\"post-list\">\n")
      (dolist (entry entries)
        (let* ((meta (cdr entry))
               (href (concat (file-name-sans-extension
                              (file-relative-name (car entry) posts-dir))
                             ".html"))
               (hero (plist-get meta :hero)))
          (insert (format "<li data-tags=\"%s\"><a href=\"%s\"><span class=\"t\">%s</span><time>%s</time></a>"
                          (downcase (mapconcat #'identity (plist-get meta :tags) " "))
                          href
                          (org-html-encode-plain-text (blog-plain-title (plist-get meta :title)))
                          (blog-date-string (plist-get meta :date))))
          (when (and hero (not (string-empty-p hero)))
            (insert (format "<img class=\"preview\" src=\"%s\" alt=\"\" loading=\"lazy\" />"
                            (blog-url (concat "/" hero)))))
          (insert "</li>\n")))
      (insert "</ul>\n<p class=\"empty\" hidden>No posts match.</p>\n#+end_export\n"))))

;; ---------------------------------------------------------------
;; Search index
;; ---------------------------------------------------------------
;; content/search-index.json (git-ignored) holds each post's title, tags,
;; summary and plain text.  content/js/site.js loads it the first time the
;; search box is used and searches it in the browser.
(require 'json)

(defun blog-post-plain-text (file)
  "The readable text of the Org post FILE: no keywords, comments or markup."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (let ((lines nil))
      (dolist (line (split-string (buffer-string) "\n"))
        (unless (string-match-p "\\`[ \t]*#\\(\\+\\|[ \t]\\|\\'\\)" line)
          (setq line (replace-regexp-in-string "\\`\\*+[ \t]+" "" line))
          (setq line (replace-regexp-in-string
                      "\\[\\[[^]]*\\]\\[\\([^]]*\\)\\]\\]" "\\1" line))
          (setq line (replace-regexp-in-string "\\[\\[[^]]*\\]\\]" "" line))
          (push (blog-plain-title line) lines)))
      (let ((text (replace-regexp-in-string
                   "[ \t\n]+" " " (mapconcat #'identity (nreverse lines) " "))))
        (string-trim (substring text 0 (min (length text) 20000)))))))

(defun blog-write-search-index ()
  (let* ((posts-dir (blog-path "content/posts/"))
         (entries (sort (mapcar (lambda (file) (cons file (blog-post-meta file)))
                                (blog-post-files))
                        (lambda (a b)
                          (time-less-p (plist-get (cdr b) :date)
                                       (plist-get (cdr a) :date)))))
         (coding-system-for-write 'utf-8)
         (json-encoding-pretty-print nil))
    (with-temp-file (blog-path "content/search-index.json")
      (insert
       (json-encode
        (vconcat
         (mapcar
          (lambda (entry)
            (let ((meta (cdr entry)))
              `((title . ,(blog-plain-title (plist-get meta :title)))
                (url . ,(blog-url
                         (concat "/posts/"
                                 (file-name-sans-extension
                                  (file-relative-name (car entry) posts-dir))
                                 ".html")))
                (date . ,(blog-date-string (plist-get meta :date)))
                (tags . ,(vconcat (plist-get meta :tags)))
                (description . ,(plist-get meta :description))
                (text . ,(blog-post-plain-text (car entry))))))
          entries)))))))

;; Options shared by every HTML component.
(defvar blog-common
  `(:publishing-function org-html-publish-to-html
    :language "en-GB"
    :with-title nil                   ; blog-preamble draws the title
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
    :html-preamble blog-preamble
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

        ("blog-posts"                     ; content/posts/*.org  (+ generated index.org)
         :base-directory ,(blog-path "content/posts")
         :base-extension "org"
         :recursive t
         :publishing-directory ,(blog-path "public/posts")
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
         :base-extension "css\\|js\\|json\\|png\\|jpg\\|jpeg\\|gif\\|svg\\|webp\\|ico\\|txt"
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
  (blog-write-posts-index)
  (blog-write-search-index)
  (org-publish "blog" t)
  ;; Stop GitHub Pages running Jekyll over the output.
  (write-region "" nil (blog-path "public/.nojekyll") nil 'silent)
  (message "Blog published to %s" (blog-path "public")))

(provide 'publish)
;;; publish.el ends here
