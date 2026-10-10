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
  "Things I’m learning, and how I’m learning them: languages, code, science, math, music and everyday self-improvement.")
;; Optional, free extras.  Both are off until you fill them in (see README, "Comments and
;; analytics").
(defvar blog-giscus nil
  "Comments under each post, powered by GitHub Discussions (https://giscus.app).
Set it to a plist copied from giscus.app, for example
  '(:repo \"you/blog\" :repo-id \"R_kgDO...\" :category \"Announcements\" :category-id \"DIC_kwDO...\")
Leave it nil for no comments.")

(defvar blog-goatcounter nil
  "Your GoatCounter site code (https://www.goatcounter.com), e.g. \"isaiah\" for
isaiah.goatcounter.com.  GoatCounter is free for personal sites and uses no cookies.
Leave it nil for no analytics.  Local previews are never counted.")

(defvar blog-timezone "America/Port_of_Spain"
  "Timezone for posts that have no #+TIMEZONE: line.
A post's #+DATE: is read as local time in its zone, and its date is shown
and written to the feed in that same zone.  Use IANA names such as
\"Europe/Reykjavik\".")

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
;; Languages
;; ---------------------------------------------------------------
;; The default language (British English) is written as ordinary .org files and
;; published at the top of the site.  A translation sits right beside its
;; original with the language code before the extension:
;;
;;   content/posts/foo.org     ->  /posts/foo.html
;;   content/posts/foo.is.org  ->  /is/posts/foo.html
;;
;; A post can also live in its own folder, with its images beside it:
;;
;;   content/posts/foo/index.org     ->  /posts/foo/
;;   content/posts/foo/index.is.org  ->  /is/posts/foo/
;;   content/posts/foo/banner.png    ->  /posts/foo/banner.png
;;
;; A page counts as translated when its .<code>.org file exists.  The build
;; publishes each language separately and drops the ".is" from the output name.
;;
;; To add a language: add a line to `blog-languages', add its entry to
;; `blog-strings' and `blog-months', then write some foo.<code>.org files.
(defvar blog-default-language "en")

(defvar blog-languages
  '(("en" :name "English"  :hreflang "en-GB" :locale "en-GB")
    ("is" :name "Íslenska" :hreflang "is"    :locale "is")
    ("sv" :name "Svenska"  :hreflang "sv"    :locale "sv")
    ("ja" :name "日本語"   :hreflang "ja"    :locale "ja")))

(defvar blog-months
  '(("en" . ["January" "February" "March" "April" "May" "June" "July"
             "August" "September" "October" "November" "December"])
    ("is" . ["janúar" "febrúar" "mars" "apríl" "maí" "júní" "júlí"
             "ágúst" "september" "október" "nóvember" "desember"])
    ("sv" . ["januari" "februari" "mars" "april" "maj" "juni" "juli"
             "augusti" "september" "oktober" "november" "december"])
    ("ja" . ["1月" "2月" "3月" "4月" "5月" "6月" "7月"
             "8月" "9月" "10月" "11月" "12月"])))

;; Every piece of text the site itself adds around your writing.  Anything
;; missing for a language falls back to the default language.  The site title
;; and description fall back to `blog-title' and `blog-description'.
(defvar blog-strings
  '(("en"
     (home . "Home") (about . "About") (posts . "Posts") (all-posts . "All posts")
     (search . "Search posts") (toc . "Table of contents")
     (theme . "Toggle light and dark theme") (language . "Language")
     (read-more . "Read more posts") (rss . "Subscribe via RSS")
     (built . "Built with Emacs and Org mode.")
     (all . "All") (filter . "Filter by topic")
     (none-list . "No posts match.") (no-match . "No posts match “%s”.")
     (unavailable . "Search is unavailable right now.")
     (read-full . "Read the full post") (date-format . "%d %s %d")
     (reading-time . "%d min read") (copy . "Copy") (copied . "Copied")
     (archive . "Archive") (tags . "Tags")
     (archive-lede . "Every post, newest first.") (tags-lede . "Browse posts by topic.")
     (related . "Related posts") (older . "Older post") (newer . "Newer post")
     (anchor . "Copy link to this section") (skip . "Skip to content"))
    ("is"
     (description . "Pistlar um íslensku, Emacs, Org mode og skrýtin verkefni sem spretta upp úr þeim.")
     (home . "Heim") (about . "Um mig") (posts . "Færslur") (all-posts . "Allar færslur")
     (search . "Leita í færslum") (toc . "Efnisyfirlit")
     (theme . "Skipta á milli ljóss og dökks útlits") (language . "Tungumál")
     (read-more . "Fleiri færslur") (rss . "Fylgstu með í gegnum RSS")
     (built . "Smíðað með Emacs og Org mode.")
     (all . "Allt") (filter . "Sía eftir efni")
     (none-list . "Engar færslur fundust.") (no-match . "Engar færslur fundust fyrir „%s“.")
     (unavailable . "Leit er ekki tiltæk núna.")
     (read-full . "Lesa alla færsluna") (date-format . "%d. %s %d")
     (reading-time . "%d mín. lestur") (copy . "Afrita") (copied . "Afritað")
     (archive . "Safn") (tags . "Efnisorð")
     (archive-lede . "Allar færslur, nýjustu fyrst.") (tags-lede . "Skoðaðu færslur eftir efni.")
     (related . "Tengdar færslur") (older . "Eldri færsla") (newer . "Nýrri færsla")
     (anchor . "Afrita tengil á þennan kafla") (skip . "Fara beint í efnið"))
    ("sv"
     (description . "Anteckningar om isländska, Emacs, Org mode och de udda projekt som växer fram ur dem.")
     (home . "Hem") (about . "Om mig") (posts . "Inlägg") (all-posts . "Alla inlägg")
     (search . "Sök i inlägg") (toc . "Innehållsförteckning")
     (theme . "Växla mellan ljust och mörkt tema") (language . "Språk")
     (read-more . "Fler inlägg") (rss . "Prenumerera via RSS")
     (built . "Byggd med Emacs och Org mode.")
     (all . "Alla") (filter . "Filtrera efter ämne")
     (none-list . "Inga inlägg hittades.") (no-match . "Inga inlägg matchar ”%s”.")
     (unavailable . "Sökningen är inte tillgänglig just nu.")
     (read-full . "Läs hela inlägget") (date-format . "%d %s %d")
     (reading-time . "%d min läsning") (copy . "Kopiera") (copied . "Kopierat")
     (archive . "Arkiv") (tags . "Ämnen")
     (archive-lede . "Alla inlägg, nyaste först.") (tags-lede . "Bläddra bland inlägg efter ämne.")
     (related . "Relaterade inlägg") (older . "Äldre inlägg") (newer . "Nyare inlägg")
     (anchor . "Kopiera länk till det här avsnittet") (skip . "Hoppa till innehållet"))
    ("ja"
     (description . "アイスランド語、Emacs、Org mode、そしてそこから生まれる風変わりなプロジェクトについてのメモ。")
     (home . "ホーム") (about . "自己紹介") (posts . "記事") (all-posts . "すべての記事")
     (search . "記事を検索") (toc . "目次")
     (theme . "ライト/ダークテーマを切り替える") (language . "言語")
     (read-more . "ほかの記事を読む") (rss . "RSS で購読する")
     (built . "Emacs と Org mode で作られています。")
     (all . "すべて") (filter . "トピックで絞り込む")
     (none-list . "該当する記事はありません。") (no-match . "「%s」に一致する記事はありません。")
     (unavailable . "現在、検索を利用できません。")
     (read-full . "記事の全文を読む")
     (reading-time . "読了目安 %d分") (copy . "コピー") (copied . "コピーしました")
     (archive . "アーカイブ") (tags . "タグ")
     (archive-lede . "すべての記事を新しい順に。") (tags-lede . "トピック別に記事を見る。")
     (related . "関連記事") (older . "前の記事") (newer . "次の記事")
     (anchor . "このセクションへのリンクをコピー") (skip . "本文へスキップ")
     ;; Arguments are (day month year), so number the fields to get 2026年9月30日.
     (date-format . "%3$d年%2$s%1$d日"))))

(defun blog-codes ()
  (mapcar #'car blog-languages))

(defun blog-lang-prop (code prop)
  (plist-get (cdr (assoc code blog-languages)) prop))

(defun blog-str (lang key)
  "The text for KEY in LANG, else in the default language, else \"\"."
  (or (cdr (assq key (cdr (assoc lang blog-strings))))
      (cdr (assq key (cdr (assoc blog-default-language blog-strings))))
      ""))

(defun blog-site-title (lang)
  (let ((s (blog-str lang 'title))) (if (string-empty-p s) blog-title s)))

(defun blog-site-description (lang)
  (let ((s (blog-str lang 'description))) (if (string-empty-p s) blog-description s)))

;; Timezones.  Each post may carry its own #+TIMEZONE: (an IANA name such as
;; Europe/Reykjavik), so you can move country and keep writing the date as it
;; was on your wall.  The zone is passed explicitly to `encode-time',
;; `decode-time' and `format-time-string' rather than changing the process's
;; zone per file.  That needs Emacs 27 or later.
(defun blog-zone (name)
  "NAME, an IANA zone such as \"Europe/Reykjavik\", or `blog-timezone' if NAME is empty."
  (let ((zone (if (or (null name) (string-empty-p name)) blog-timezone name))
        (db "/usr/share/zoneinfo/"))
    ;; An unknown name would silently mean UTC, so fail the build instead.
    (when (and (file-directory-p db)
               (or (string-match-p "\\`/\\|\\.\\." zone)
                   (not (file-regular-p (expand-file-name zone db)))))
      (error "Unknown timezone %S (use names like Europe/Reykjavik)" zone))
    zone))

(defun blog-zone-from-properties (values)
  "The zone named by a \"TIMEZONE name\" entry among #+PROPERTY: VALUES, or nil.
This reads the older `#+PROPERTY: TIMEZONE name' spelling; prefer `#+TIMEZONE:'."
  (cl-some (lambda (value)
             (when (string-match "\\`[ \t]*TIMEZONE[ \t]+\\([^ \t]+\\)" value)
               (match-string 1 value)))
           values))

(defun blog-parse-date (string zone)
  "The Org date STRING as a time value, read as local time in ZONE."
  (let ((p (org-parse-time-string string)))
    (encode-time (list (nth 0 p) (nth 1 p) (nth 2 p)
                       (nth 3 p) (nth 4 p) (nth 5 p)
                       nil -1 zone))))

(defun blog-date-string (time &optional lang zone)
  "TIME as a date such as \"30 September 2026\", in LANG and ZONE."
  (let* ((lang (or lang blog-default-language))
         (months (or (cdr (assoc lang blog-months))
                     (cdr (assoc blog-default-language blog-months))))
         (d (decode-time time (or zone blog-timezone))))
    (format (blog-str lang 'date-format) (nth 3 d) (aref months (1- (nth 4 d))) (nth 5 d))))

(defun blog-default-p (code)
  (equal code blog-default-language))

(defun blog-lang-out (code)
  "Where CODE's pages are published."
  (if (blog-default-p code) (blog-path "public") (blog-path "public" code)))

(defun blog-lang-prefix (code)
  "URL prefix of CODE's pages: \"\" for the default language, else \"/code\"."
  (if (blog-default-p code) "" (concat "/" code)))

(defun blog-lang-exists-p (code)
  "Does CODE have any translated pages?  (The default language always counts.)"
  (or (blog-default-p code)
      (let ((index (blog-source-file code "posts/index.org")))   ; generated, so ignore it
        (cl-some (lambda (file) (not (string= (expand-file-name file) index)))
                 (directory-files-recursively
                  (blog-path "content")
                  (concat "\\`[^.#].*\\." (regexp-quote code) "\\.org\\'"))))))

(defun blog-lang-of-file (file)
  "The language code of the Org source FILE, from its name: foo.is.org is \"is\"."
  (let ((name (file-name-nondirectory file)))
    (or (cl-find-if (lambda (code)
                      (and (not (blog-default-p code))
                           (string-suffix-p (concat "." code ".org") name)))
                    (blog-codes))
        blog-default-language)))

(defun blog-source-file (code rel)
  "The Org source of page REL (e.g. \"posts/foo.org\") in language CODE.
For the default language that is foo.org; otherwise foo.<code>.org beside it."
  (expand-file-name
   (concat (file-name-sans-extension rel)
           (if (blog-default-p code) "" (concat "." code))
           ".org")
   (blog-path "content")))

(defun blog-translation-regexp ()
  "Matches the names of translated files (foo.is.org, ...)."
  (concat "\\.\\("
          (mapconcat #'regexp-quote
                     (seq-remove #'blog-default-p (blog-codes))
                     "\\|")
          "\\)\\.org\\'"))

(defun blog-rel-file (file)
  "FILE's path below content/ without the language suffix, e.g. \"posts/foo.org\"."
  (let ((rel (file-relative-name (expand-file-name file) (blog-path "content")))
        (code (blog-lang-of-file file)))
    (if (blog-default-p code)
        rel
      (concat (substring rel 0 (- (length rel) (length (concat "." code ".org"))))
              ".org"))))

;; Drafts.  A post with `#+DRAFT: t', or with a #+DATE: that has not arrived yet, is
;; left out of the site, the feeds, search and the sitemap.  Build with BLOG_DRAFTS=1
;; to see drafts and scheduled posts while you write.
(defvar blog-show-drafts (not (member (getenv "BLOG_DRAFTS") '(nil "" "0"))))

(defvar blog--published-cache (make-hash-table :test 'equal)
  "File name -> whether the post is published, so each file is read once per build.")

(defun blog-file-published-p (file)
  "Is the post FILE to be published (not a draft, and not dated in the future)?"
  (or blog-show-drafts
      (let ((hit (gethash file blog--published-cache 'none)))
        (if (not (eq hit 'none))
            hit
          (puthash
           file
           (with-temp-buffer
             (let ((coding-system-for-read 'utf-8))
               (insert-file-contents file))
             (delay-mode-hooks (org-mode))
             (let* ((kw (org-collect-keywords '("DRAFT" "DATE" "TIMEZONE" "PROPERTY")))
                    (get (lambda (key) (string-trim (mapconcat #'identity (cdr (assoc key kw)) " "))))
                    (draft (downcase (funcall get "DRAFT")))
                    (date (funcall get "DATE"))
                    (zone (blog-zone (let ((name (funcall get "TIMEZONE")))
                                       (if (string-empty-p name)
                                           (blog-zone-from-properties (cdr (assoc "PROPERTY" kw)))
                                         name))))
                    (time (and (not (string-empty-p date))
                               (ignore-errors (blog-parse-date date zone)))))
               (and (member draft '("" "nil" "no" "false" "0"))
                    (not (and time (time-less-p (current-time) time))))))
           blog--published-cache)))))

(defun blog-all-post-files (&optional lang)
  "Every post file under content/posts (in LANG, if given), drafts included."
  (let* ((dir (blog-path "content/posts"))
         (index-re "/posts/index\\(?:\\.[a-z]+\\)?\\.org\\'"))
    (when (file-directory-p dir)
      (seq-filter (lambda (file)
                    (and (not (string-match-p index-re file))
                         (or (null lang) (equal (blog-lang-of-file file) lang))))
                  (directory-files-recursively dir "\\`[^.#].*\\.org\\'")))))

(defun blog-post-files (&optional lang)
  "LANG's published post files under content/posts, leaving out the generated index."
  (let ((lang (or lang blog-default-language)))
    (seq-filter #'blog-file-published-p (blog-all-post-files lang))))

(defun blog-draft-excludes ()
  "Regexps keeping unpublished posts, and the folders only they use, out of the build.
Returns (ORG-FILES-REGEXP . FOLDERS-REGEXP); either is nil when there is nothing to exclude."
  (let* ((all (blog-all-post-files))
         (hidden (seq-remove #'blog-file-published-p all))
         (shown (seq-filter #'blog-file-published-p all))
         (folders (seq-uniq
                   (seq-remove (lambda (dir)
                                 (seq-some (lambda (f) (string= (file-name-directory f) dir)) shown))
                               (mapcar #'file-name-directory
                                       (seq-filter (lambda (f)
                                                     (string= (file-name-base (blog-rel-file f)) "index"))
                                                   hidden))))))
    ;; org-publish matches :exclude against names relative to the project's base folder:
    ;; content/posts/ for the posts, content/ for the static files.
    (cons (and hidden
               (concat "\\`" (regexp-opt (mapcar (lambda (f) (file-relative-name f (blog-path "content/posts")))
                                                 hidden))))
          (and folders
               (concat "\\`" (regexp-opt (mapcar (lambda (d) (file-relative-name d (blog-path "content")))
                                                 folders)))))))

(defun blog-join-regexps (&rest regexps)
  (let ((rs (delq nil regexps)))
    (and rs (mapconcat (lambda (r) (concat "\\(?:" r "\\)")) rs "\\|"))))

(defun blog-has-posts-p (lang)
  (and (blog-post-files lang) t))

(defun blog-page-exists-p (code rel)
  "Does the page REL (e.g. \"about.org\") exist in language CODE?"
  (if (equal rel "posts/index.org")
      (blog-has-posts-p code)                  ; generated, so look for posts instead
    (file-exists-p (blog-source-file code rel))))

(defun blog-page-url (code rel)
  "The URL of the page REL in language CODE (index pages get a trailing slash)."
  (let ((html (concat (file-name-sans-extension rel) ".html")))
    (cond ((string= html "index.html")
           (setq html ""))
          ((string-suffix-p "/index.html" html)
           (setq html (substring html 0 (- (length html) (length "index.html"))))))
    (blog-url (concat (blog-lang-prefix code) "/" html))))

(defun blog-alternates (rel)
  "(CODE . URL) for every language the page REL exists in."
  (let (alts)
    (dolist (code (blog-codes))
      (when (and (blog-lang-exists-p code) (blog-page-exists-p code rel))
        (push (cons code (blog-page-url code rel)) alts)))
    (nreverse alts)))

(defun blog-nav-url (lang rel)
  "Link to REL in LANG, or in the default language if it is not translated."
  (blog-page-url (if (blog-page-exists-p lang rel) lang blog-default-language) rel))

(defun blog-content-lang (lang)
  "LANG if it has posts of its own (so its feed and search index exist), else the default."
  (if (blog-has-posts-p lang) lang blog-default-language))

(defun blog-feed-url (lang)
  (blog-url (concat (blog-lang-prefix (blog-content-lang lang)) "/rss.xml")))

(defun blog-json-feed-url (lang)
  (blog-url (concat (blog-lang-prefix (blog-content-lang lang)) "/feed.json")))

(defun blog-search-index-url (lang)
  (blog-url (concat (blog-lang-prefix (blog-content-lang lang)) "/search-index.json")))

;; ---------------------------------------------------------------
;; Page furniture
;; ---------------------------------------------------------------
(defun blog-url (path)
  (concat blog-base-path path))

;; Files copied to the site as they are: stylesheets, scripts, and anything a
;; post links to (images, PDFs, audio, video), including files that sit in a
;; post's own folder.
(defvar blog-asset-extensions
  "css\\|js\\|png\\|jpg\\|jpeg\\|gif\\|svg\\|webp\\|avif\\|ico\\|txt\\|pdf\\|mp3\\|ogg\\|wav\\|mp4\\|webm\\|woff2?")

(defun blog-asset-url (file ref)
  "The URL of the asset REF named in the Org source FILE.
REF is looked for first beside FILE (so a post in its own folder can say
`banner.png'), then below content/ (`images/banner.png', the older
style).  A leading / always means below content/, and a full URL such as
https://... is used as it is.  The URL is always the default language's,
because the build copies every asset there."
  (if (string-match-p "\\`[a-z][a-z0-9+.-]*:" ref)
      ref
    (let* ((content (blog-path "content"))
           (beside (and (not (string-prefix-p "/" ref))
                        (expand-file-name ref (file-name-directory (expand-file-name file)))))
           (found (if (and beside (file-exists-p beside))
                      beside
                    (expand-file-name (string-remove-prefix "/" ref) content))))
      (unless (file-exists-p found)
        (message "Warning: %s refers to %s, which does not exist"
                 (file-relative-name file blog-root) ref))
      (blog-url (concat "/" (replace-regexp-in-string
                             " " "%20" (file-relative-name found content)))))))

(defun blog-head (lang)
  (concat
   "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />"
   "<meta name=\"color-scheme\" content=\"light dark\" />"
   (format "<meta name=\"blog-language\" content=\"%s\" />" lang)
   "<meta name=\"theme-color\" content=\"#eeede9\" media=\"(prefers-color-scheme: light)\" />"
   "<meta name=\"theme-color\" content=\"#141414\" media=\"(prefers-color-scheme: dark)\" />"
   (format "<link rel=\"icon\" type=\"image/svg+xml\" href=\"%s\" />" (blog-url "/favicon.svg"))
   ;; Apply a saved theme before the page paints, so there is no flash.
   "<script>try{var t=localStorage.getItem('theme');if(t)document.documentElement.dataset.theme=t}catch(e){}</script>"
   (format "<link rel=\"preload\" href=\"%s\" as=\"font\" type=\"font/woff2\" crossorigin />"
           (blog-url "/fonts/inter-latin-wght-normal.woff2"))
   (format "<link rel=\"stylesheet\" href=\"%s\" />" (blog-url "/css/style.css"))
   (format "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"%s\" href=\"%s\" />"
           (blog-site-title lang) (blog-feed-url lang))
   (format "<link rel=\"alternate\" type=\"application/feed+json\" title=\"%s\" href=\"%s\" />"
           (blog-site-title lang) (blog-json-feed-url lang))
   (when (and blog-goatcounter (not (string-match-p "localhost\\|127\\.0\\.0\\.1" blog-origin)))
     (format (concat "<script data-goatcounter=\"https://%s.goatcounter.com/count\" async "
                     "src=\"//gc.zgo.at/count.js\"></script>")
             blog-goatcounter))
   (format "<script defer src=\"%s\"></script>" (blog-url "/js/site.js"))))

(defun blog-keyword (info key)
  "Value of the #+KEY: line in the page being exported, or nil."
  (org-element-map (plist-get info :parse-tree) 'keyword
    (lambda (k)
      (when (string= (upcase (org-element-property :key k)) key)
        (string-trim (org-element-property :value k))))
    info t))

(defun blog-info-zone (info)
  "The page's timezone: its #+TIMEZONE: line, else `blog-timezone'."
  (blog-zone
   (or (blog-keyword info "TIMEZONE")
       (blog-zone-from-properties
        (org-element-map (plist-get info :parse-tree) 'keyword
          (lambda (k)
            (when (string= (upcase (org-element-property :key k)) "PROPERTY")
              (org-element-property :value k)))
          info)))))

(defun blog-info-date (info)
  "The page's #+DATE: as a time value, or nil."
  (let ((d (blog-keyword info "DATE"))
        (zone (blog-info-zone info)))   ; outside ignore-errors, so a bad zone fails the build
    (and d (not (string-empty-p d))
         (ignore-errors (blog-parse-date d zone)))))

(defun blog-info-lang (info)
  (let ((file (plist-get info :input-file)))
    (if file (blog-lang-of-file file) blog-default-language)))

(defun blog-info-rel (info)
  (let ((file (plist-get info :input-file)))
    (if file (blog-rel-file file) "index.org")))

(defun blog-initials ()
  (let ((words (split-string blog-author)))
    (upcase (concat (substring (car words) 0 1)
                    (substring (car (last words)) 0 1)))))

(defun blog-svg (body)
  (format (concat "<svg viewBox=\"0 0 24 24\" width=\"18\" height=\"18\" fill=\"none\" "
                  "stroke=\"currentColor\" stroke-width=\"1.7\" stroke-linecap=\"round\" "
                  "stroke-linejoin=\"round\" aria-hidden=\"true\">%s</svg>")
          body))

(defun blog-text (s)
  "S made safe to put inside HTML text."
  (org-html-encode-plain-text s))

(defun blog-attr (s)
  "S made safe to put inside a double-quoted HTML attribute."
  (replace-regexp-in-string "\"" "&quot;" (org-html-encode-plain-text s) t t))

;; Header of every page except the posts index: optional hero image,
;; title, and (for dated posts) the date and author line.
(defun blog-preamble (info)
  (concat
   ;; First thing on every page, so keyboard users can jump past the header.
   (format "<a class=\"skip-link\" href=\"#content\">%s</a>"
           (blog-text (blog-str (blog-info-lang info) 'skip)))
   (unless (equal (blog-keyword info "LAYOUT") "list")
     (let ((hero (blog-keyword info "HERO"))
           (hero-alt (or (blog-keyword info "HERO_ALT") ""))
           (time (blog-info-date info))
           (zone (blog-info-zone info))
           (lang (blog-info-lang info))
           (file (plist-get info :input-file)))
       (concat
        ;; The hero image is the first thing seen, so it loads at once; #+HERO_ALT: describes it
        ;; for screen readers (leave it out and the image is treated as decoration).
        (when (and hero (not (string-empty-p hero)) file)
          (format "<div class=\"hero\"><img src=\"%s\" alt=\"%s\" loading=\"eager\" fetchpriority=\"high\" /></div>"
                  (blog-asset-url file hero) (blog-attr hero-alt)))
        (format "<h1 class=\"title\">%s</h1>"
                (org-export-data (plist-get info :title) info))
        (when time
          (format (concat "<div class=\"post-meta\"><span class=\"when\"><time datetime=\"%s\">%s</time>"
                          "%s</span>"
                          "<span class=\"author\"><span class=\"avatar\">%s</span>%s</span></div>")
                  (format-time-string "%F" time zone)
                  (blog-date-string time lang zone)
                  (if file
                      (format "<span class=\"sep-dot\" aria-hidden=\"true\">&middot;</span><span class=\"reading-time\">%s</span>"
                              (blog-text (blog-reading-time-string file lang)))
                    "")
                  (blog-initials)
                  blog-author)))))))

;; The language dropdown.  Only pages that exist in more than one language get one.
(defun blog-lang-switcher (lang rel)
  (let ((alts (blog-alternates rel)))
    (if (< (length alts) 2)
        ""
      (concat
       "<div class=\"lang\">"
       (format (concat "<button id=\"lang-toggle\" type=\"button\" aria-haspopup=\"true\" "
                       "aria-expanded=\"false\" aria-controls=\"lang-menu\" aria-label=\"%s\" "
                       "title=\"%s\">%s<span>%s</span></button>")
               (blog-attr (blog-str lang 'language))
               (blog-attr (blog-str lang 'language))
               (blog-svg (concat "<circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M2 12h20\"/>"
                                 "<path d=\"M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 "
                                 "15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z\"/>"))
               (upcase lang))
       "<ul id=\"lang-menu\" class=\"lang-menu\" hidden>"
       (mapconcat
        (lambda (alt)
          (let ((code (car alt)))
            (format "<li><a href=\"%s\" hreflang=\"%s\" lang=\"%s\" data-lang=\"%s\"%s>%s</a></li>"
                    (cdr alt)
                    (blog-lang-prop code :hreflang)
                    (blog-lang-prop code :hreflang)
                    code
                    (if (equal code lang) " aria-current=\"true\"" "")
                    (blog-text (blog-lang-prop code :name)))))
        alts "")
       "</ul></div>"))))

;; The floating bar at the bottom of every page (see content/js/site.js).
(defun blog-dock (lang rel)
  (concat
   "<div class=\"bottom-fade\" aria-hidden=\"true\"></div>"
   (format (concat "<nav class=\"dock\" aria-label=\"Site\" data-no-match=\"%s\" data-unavailable=\"%s\" "
                   "data-copy=\"%s\" data-copied=\"%s\" data-anchor=\"%s\">")
           (blog-attr (blog-str lang 'no-match))
           (blog-attr (blog-str lang 'unavailable))
           (blog-attr (blog-str lang 'copy))
           (blog-attr (blog-str lang 'copied))
           (blog-attr (blog-str lang 'anchor)))
   ;; Table of contents: filled in by content/js/site.js from the post's headings.
   (format (concat "<div class=\"toc-panel\" id=\"toc-panel\" inert><div class=\"toc-clip\">"
                   "<p class=\"toc-head\">%s</p><ul class=\"toc-list\" id=\"toc-list\"></ul>"
                   "</div></div>")
           (blog-text (blog-str lang 'toc)))
   "<div class=\"dock-row\">"
   ;; Search box (with its results list) and, on long pages, a button that opens it.
   "<div class=\"dock-search\"><label>"
   (blog-svg "<circle cx=\"11\" cy=\"11\" r=\"8\"/><path d=\"m21 21-4.3-4.3\"/>")
   (format (concat "<input id=\"dock-search\" type=\"search\" placeholder=\"%s\" "
                   "autocomplete=\"off\" aria-label=\"%s\" data-index=\"%s\" />")
           (blog-attr (blog-str lang 'search))
           (blog-attr (blog-str lang 'search))
           (blog-search-index-url lang))
   "<kbd>Ctrl K</kbd></label>"
   "<ul id=\"search-results\" class=\"results\" role=\"listbox\" hidden></ul></div>"
   (format "<button id=\"search-open\" type=\"button\" aria-label=\"%s\" title=\"%s\">"
           (blog-attr (blog-str lang 'search))
           (blog-attr (blog-str lang 'search)))
   (blog-svg "<circle cx=\"11\" cy=\"11\" r=\"8\"/><path d=\"m21 21-4.3-4.3\"/>")
   "</button>"
   ;; Which part of the post you are reading, with a progress ring.
   (format (concat "<button class=\"dock-section\" id=\"toc-toggle\" type=\"button\" "
                   "aria-expanded=\"false\" aria-controls=\"toc-panel\" title=\"%s\">")
           (blog-attr (blog-str lang 'toc)))
   "<i class=\"dot\"></i><span id=\"dock-label\"></span>"
   "<svg class=\"ring\" viewBox=\"0 0 20 20\" width=\"18\" height=\"18\" aria-hidden=\"true\">"
   "<circle class=\"track\" cx=\"10\" cy=\"10\" r=\"8\"/>"
   "<circle class=\"bar\" cx=\"10\" cy=\"10\" r=\"8\" pathLength=\"1\"/></svg></button>"
   "<span class=\"sep\"></span>"
   (format (concat "<button id=\"theme-toggle\" type=\"button\" aria-label=\"%s\" title=\"%s\">"
                   "<span class=\"icon-moon\">")
           (blog-attr (blog-str lang 'theme))
           (blog-attr (blog-str lang 'theme)))
   (blog-svg "<path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z\"/>")
   "</span><span class=\"icon-sun\">"
   (blog-svg (concat "<circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2m0 16v2M4.93 4.93l1.41 1.41"
                     "m11.32 11.32 1.41 1.41M2 12h2m16 0h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41\"/>"))
   "</span></button>"
   (format "<a href=\"%s\" aria-label=\"%s\" title=\"%s\">%s</a>"
           (blog-nav-url lang "index.org")
           (blog-attr (blog-str lang 'home))
           (blog-attr (blog-str lang 'home))
           (blog-svg "<path d=\"m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\"/><path d=\"M9 22V12h6v10\"/>"))
   (format "<a href=\"%s\" aria-label=\"%s\" title=\"%s\">%s</a>"
           (blog-nav-url lang "about.org")
           (blog-attr (blog-str lang 'about))
           (blog-attr (blog-str lang 'about))
           (blog-svg "<circle cx=\"12\" cy=\"8\" r=\"4\"/><path d=\"M4 21a8 8 0 0 1 16 0\"/>"))
   (format "<a class=\"dock-text\" href=\"%s\" title=\"%s\">%s<span>%s</span></a>"
           (blog-nav-url lang "posts/index.org")
           (blog-attr (blog-str lang 'all-posts))
           (blog-svg "<path d=\"M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01\"/>")
           (blog-text (blog-str lang 'posts)))
   (blog-lang-switcher lang rel)
   "</div></nav>"))

(defun blog-entry-url (entry lang)
  (blog-url (concat (blog-lang-prefix lang) "/" (blog-post-url-path entry))))

(defun blog-entry-li (entry lang)
  "A list row (title, date and reading time) linking to the post ENTRY."
  (let ((meta (cdr entry)))
    (format "<li><a href=\"%s\"><span class=\"t\">%s</span><time>%s &middot; %s</time></a></li>\n"
            (blog-entry-url entry lang)
            (blog-text (blog-plain-title (plist-get meta :title)))
            (blog-date-string (plist-get meta :date) lang (plist-get meta :timezone))
            (blog-text (blog-reading-time-string (car entry) lang)))))

(defun blog-post-extras (file lang)
  "Tags, previous/next links and related posts for the post FILE, as HTML."
  (let* ((entries (blog-post-entries lang))
         (pos (cl-position (expand-file-name file) entries
                           :key (lambda (e) (expand-file-name (car e))) :test #'string=)))
    (when pos
      (let* ((me (nth pos entries))
             (tags (plist-get (cdr me) :tags))
             (newer (and (> pos 0) (nth (1- pos) entries)))
             (older (nth (1+ pos) entries))
             (mine (mapcar #'downcase tags))
             (scored (delq nil
                           (mapcar (lambda (e)
                                     (let ((n (length (cl-intersection
                                                       mine (mapcar #'downcase (plist-get (cdr e) :tags))
                                                       :test #'string=))))
                                       (and (not (eq e me)) (> n 0) (cons n e))))
                                   entries)))
             ;; most tags in common first; entries are already newest first, and the sort is stable
             (related (mapcar #'cdr (seq-take (sort scored (lambda (a b) (> (car a) (car b)))) 3)))
             (tags-url (and tags (blog-page-exists-p lang "tags.org") (blog-nav-url lang "tags.org"))))
        (concat
         (when tags-url
           (concat "<p class=\"post-tags\">"
                   (mapconcat (lambda (tag)
                                (format "<a href=\"%s#%s\">%s</a>" tags-url (blog-slug tag) (blog-text tag)))
                              tags "")
                   "</p>"))
         (when related
           (concat (format "<section class=\"related\"><h2>%s</h2><ul class=\"archive-list\">\n"
                           (blog-text (blog-str lang 'related)))
                   (mapconcat (lambda (e) (blog-entry-li e lang)) related "")
                   "</ul></section>"))
         (when (or newer older)
           (concat "<nav class=\"post-nav\">"
                   (if older
                       (format "<a class=\"older\" href=\"%s\"><span>&larr; %s</span><b>%s</b></a>"
                               (blog-entry-url older lang) (blog-text (blog-str lang 'older))
                               (blog-text (blog-plain-title (plist-get (cdr older) :title))))
                     "<span></span>")
                   (if newer
                       (format "<a class=\"newer\" href=\"%s\"><span>%s &rarr;</span><b>%s</b></a>"
                               (blog-entry-url newer lang) (blog-text (blog-str lang 'newer))
                               (blog-text (blog-plain-title (plist-get (cdr newer) :title))))
                     "<span></span>")
                   "</nav>")))))))

;; Comments.  Every language version of a post shares one discussion, because the thread is
;; named after the default-language address.
(defun blog-comments (lang rel)
  (when blog-giscus
    (format (concat "<section class=\"comments\"><script src=\"https://giscus.app/client.js\" "
                    "data-repo=\"%s\" data-repo-id=\"%s\" data-category=\"%s\" data-category-id=\"%s\" "
                    "data-mapping=\"specific\" data-term=\"%s\" data-strict=\"0\" "
                    "data-reactions-enabled=\"1\" data-emit-metadata=\"0\" data-input-position=\"top\" "
                    "data-theme=\"preferred_color_scheme\" data-lang=\"%s\" "
                    "crossorigin=\"anonymous\" async></script></section>")
            (blog-attr (plist-get blog-giscus :repo))
            (blog-attr (plist-get blog-giscus :repo-id))
            (blog-attr (plist-get blog-giscus :category))
            (blog-attr (plist-get blog-giscus :category-id))
            (blog-attr (blog-page-url blog-default-language rel))
            (if (member lang '("en" "ja")) lang "en"))))

(defun blog-postamble (info)
  "Footer for every page: post extras and end-of-post links (dated posts only), colophon, dock."
  (let ((lang (blog-info-lang info))
        (rel (blog-info-rel info))
        (file (plist-get info :input-file)))
    (concat
     (when (blog-info-date info)
       (concat
        (and file (blog-post-extras file lang))
        (blog-comments lang rel)
        (format (concat "<nav class=\"endnav\"><a href=\"%s\">&larr; %s</a>"
                        "<a href=\"%s\">%s &rarr;</a></nav>")
                (blog-nav-url lang "posts/index.org")
                (blog-text (blog-str lang 'read-more))
                (blog-feed-url lang)
                (blog-text (blog-str lang 'rss)))))
     (format "<p class=\"colophon\">&copy; %s %s. %s</p>"
             (format-time-string "%Y") blog-author (blog-text (blog-str lang 'built)))
     (blog-dock lang rel))))

;; ---------------------------------------------------------------
;; Language alternates and automatic language choice
;; ---------------------------------------------------------------
;; Added to every exported page that exists in more than one language:
;;  - <link rel="alternate" hreflang="..."> for each version, so search
;;    engines know the pages are translations of one another;
;;  - a tiny script that sends a visitor to the version in their language.
;;    It uses their saved choice (from the dropdown) if they have made one,
;;    otherwise the first language in their browser's preference list that
;;    this page is available in.  If none match, they stay on the default.
(defvar blog-redirect-script
  (concat
   "<script>(function(){try{"
   "var m=document.querySelector('meta[name=blog-language]');"
   "var cur=(m?m.content:document.documentElement.lang).split('-')[0].toLowerCase();"
   "var alts={};"
   "document.querySelectorAll('link[rel=alternate][hreflang]').forEach(function(l){"
   "var c=l.hreflang.toLowerCase().split('-')[0];if(c!=='x'&&!alts[c])alts[c]=new URL(l.href).pathname;});"
   "var want=localStorage.getItem('lang');"
   "if(!want||!alts[want]){want=null;var ls=navigator.languages||[navigator.language];"
   "for(var i=0;i<ls.length;i++){var c=String(ls[i]||'').toLowerCase().split('-')[0];"
   "if(alts[c]){want=c;break}}}"
   "if(want&&want!==cur&&alts[want])location.replace(alts[want]);"
   "}catch(e){}})();</script>"))

(defun blog-alternate-head (alts)
  (concat
   (mapconcat
    (lambda (alt)
      ;; Search engines want fully qualified URLs here.
      (format "<link rel=\"alternate\" hreflang=\"%s\" href=\"%s%s\" />"
              (blog-lang-prop (car alt) :hreflang) blog-origin (cdr alt)))
    alts "")
   (let ((default (assoc blog-default-language alts)))
     (if default
         (format "<link rel=\"alternate\" hreflang=\"x-default\" href=\"%s%s\" />"
                 blog-origin (cdr default))
       ""))
   blog-redirect-script))

;; Link-preview and search-engine tags: a description, the canonical URL,
;; and Open Graph / Twitter card tags, so a shared link shows the title,
;; summary and hero image instead of a bare address.  These need absolute
;; URLs, so set BLOG_ORIGIN when you build for the real site (the deploy
;; workflow already does).
(defun blog-social-head (info lang rel file)
  (let* ((title (blog-plain-title
                 (or (blog-keyword info "TITLE") (blog-site-title lang))))
         (desc (let ((d (blog-keyword info "DESCRIPTION")))
                 (if (and d (not (string-empty-p d))) d (blog-site-description lang))))
         (hero (blog-keyword info "HERO"))
         ;; The hero image, else the site-wide picture in content/images/og-default.png.
         (image (cond ((and hero (not (string-empty-p hero)))
                       (concat blog-origin (blog-asset-url file hero)))
                      ((file-exists-p (blog-path "content/images/og-default.png"))
                       (concat blog-origin (blog-url "/images/og-default.png")))))
         (dated (blog-info-date info))
         (url (concat blog-origin (blog-page-url lang rel))))
    (concat
     (format "<meta name=\"description\" content=\"%s\" />" (blog-attr desc))
     (format "<link rel=\"canonical\" href=\"%s\" />" url)
     (format "<meta property=\"og:site_name\" content=\"%s\" />" (blog-attr (blog-site-title lang)))
     (format "<meta property=\"og:type\" content=\"%s\" />" (if dated "article" "website"))
     (format "<meta property=\"og:title\" content=\"%s\" />" (blog-attr title))
     (format "<meta property=\"og:description\" content=\"%s\" />" (blog-attr desc))
     (format "<meta property=\"og:url\" content=\"%s\" />" url)
     (format "<meta property=\"og:locale\" content=\"%s\" />"
             (replace-regexp-in-string "-" "_" (blog-lang-prop lang :locale)))
     (when dated
       (format "<meta property=\"article:published_time\" content=\"%s\" />"
               (format-time-string "%FT%T%z" dated (blog-info-zone info))))
     (when image
       (format "<meta property=\"og:image\" content=\"%s\" />" image))
     (format "<meta name=\"twitter:card\" content=\"%s\" />"
             (if image "summary_large_image" "summary"))
     (format "<meta name=\"twitter:title\" content=\"%s\" />" (blog-attr title))
     (format "<meta name=\"twitter:description\" content=\"%s\" />" (blog-attr desc))
     (when image
       (format "<meta name=\"twitter:image\" content=\"%s\" />" image)))))

;; Images.  Org gives an image the file's name as its alt text ("cover.png"), which is
;; noise for a screen reader.  A figure with a caption uses the caption instead; any other
;; image whose alt is still the file name becomes decoration (alt=""), unless the post says
;; otherwise with `#+ATTR_HTML: :alt a description'.  Images below the hero load lazily.
(defun blog-strip-tags (html)
  (string-trim (replace-regexp-in-string
                "[ \t\n]+" " "
                (replace-regexp-in-string "<[^>]*>" "" html))))

(defun blog-fix-img (tag caption)
  "TAG, an <img ...> element, with a useful alt and lazy loading."
  (let ((src (and (string-match "src=\"\\([^\"]*\\)\"" tag) (match-string 1 tag)))
        (alt (and (string-match "alt=\"\\([^\"]*\\)\"" tag) (match-string 1 tag))))
    (when (and src alt (string= (url-unhex-string alt)
                                (file-name-nondirectory (url-unhex-string src))))
      (setq tag (replace-regexp-in-string
                 "alt=\"[^\"]*\"" (concat "alt=\"" (or caption "") "\"") tag t t)))
    (if (string-match-p "loading=" tag)
        tag
      (replace-regexp-in-string "\\`<img " "<img loading=\"lazy\" decoding=\"async\" " tag t t))))

(defun blog-fix-images (html)
  (require 'url-util)
  (let ((html (replace-regexp-in-string
               "<figure\\b[^>]*>\\(?:.\\|\n\\)*?</figure>"
               (lambda (fig)
                 (save-match-data
                  (let ((caption (when (string-match "<figcaption>\\(\\(?:.\\|\n\\)*?\\)</figcaption>" fig)
                                  ;; already HTML text, so only the quotes need care
                                  (replace-regexp-in-string
                                   "\"" "&quot;"
                                   (blog-strip-tags
                                    (replace-regexp-in-string
                                     "<span class=\"figure-number\">[^<]*</span>" ""
                                     (match-string 1 fig)))
                                   t t))))
                   (replace-regexp-in-string "<img [^>]*>"
                                             (lambda (img) (save-match-data (blog-fix-img img caption)))
                                             fig t t))))
               html t t)))
    (replace-regexp-in-string "<img [^>]*>" (lambda (img) (save-match-data (blog-fix-img img nil))) html t t)))

(defun blog-final-output (output backend info)
  "Give every exported page the right <html lang>, its social tags and its language alternates."
  (let ((file (plist-get info :input-file)))
    (if (not (and file
                  (org-export-derived-backend-p backend 'html)
                  (not (org-export-derived-backend-p backend 'rss))
                  (string-prefix-p (blog-path "content") (expand-file-name file))))
        output
      (let* ((lang (blog-lang-of-file file))
             (rel (blog-rel-file file))
             (alts (blog-alternates rel)))
        (setq output (replace-regexp-in-string
                      "<html lang=\"[^\"]*\""
                      (format "<html lang=\"%s\"" (blog-lang-prop lang :locale))
                      output t t))
        (setq output (blog-fix-images output))
        ;; The generator tag has no use on a published site.
        (when (string-match "<meta name=\"generator\"[^>]*>\n?" output)
          (setq output (replace-match "" t t output)))
        ;; Org already writes a <meta name="description"> when #+DESCRIPTION: is set.
        ;; Ours replaces it, so a page never gets two.
        (when (string-match "<meta name=\"description\"[^>]*>\n?" output)
          (setq output (replace-match "" t t output)))
        (if (not (string-match "</head>" output))
            output
          (let ((pos (match-beginning 0)))
            (concat (substring output 0 pos)
                    (blog-social-head info lang rel file)
                    (if (< (length alts) 2) "" (blog-alternate-head alts))
                    (substring output pos))))))))

(add-to-list 'org-export-filter-final-output-functions #'blog-final-output)

;; ---------------------------------------------------------------
;; Posts: metadata, feed, index page, search index
;; ---------------------------------------------------------------
(defun blog-post-meta (file)
  "Return (:title :timezone :date :description :tags :hero) for the post FILE."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (delay-mode-hooks (org-mode))
    (let* ((kw (org-collect-keywords
                '("TITLE" "DATE" "DESCRIPTION" "FILETAGS" "HERO" "TIMEZONE" "PROPERTY")))
           (get (lambda (key)
                  (string-trim (mapconcat #'identity (cdr (assoc key kw)) " "))))
           (title (funcall get "TITLE"))
           (date (funcall get "DATE"))
           (zone (blog-zone (let ((name (funcall get "TIMEZONE")))
                              (if (string-empty-p name)
                                  (blog-zone-from-properties (cdr (assoc "PROPERTY" kw)))
                                name)))))
      (list :title (if (string-empty-p title) (file-name-base file) title)
            :timezone zone
            :date (or (and (not (string-empty-p date))
                           (ignore-errors (blog-parse-date date zone)))
                      (file-attribute-modification-time (file-attributes file)))
            :description (funcall get "DESCRIPTION")
            :tags (split-string (funcall get "FILETAGS") "[: ]+" t)
            :hero (funcall get "HERO")))))

(defun blog-plain-title (title)
  "TITLE without Org emphasis markers (/italic/, *bold*, =code=, ...)."
  (replace-regexp-in-string
   "\\(\\`\\|[[:space:](]\\)\\([*/=~+_]\\)\\([^[:space:]]\\(?:[^\n]*?[^[:space:]]\\)?\\)\\2\\([[:space:].,;:!?)]\\|\\'\\)"
   "\\1\\3\\4" title))

(defvar blog--entries-cache nil
  "Alist of (LANG . ENTRIES), so each post is read once per build.")

(defun blog-post-entries (lang)
  "(FILE . META) for each of LANG's posts, newest first."
  (or (cdr (assoc lang blog--entries-cache))
      (let ((entries (sort (mapcar (lambda (file) (cons file (blog-post-meta file)))
                                   (blog-post-files lang))
                           (lambda (a b)
                             (time-less-p (plist-get (cdr b) :date)
                                          (plist-get (cdr a) :date))))))
        (push (cons lang entries) blog--entries-cache)
        entries)))

(defun blog-post-url-path (entry)
  "ENTRY's page path below its language's site folder.
\"posts/foo/\" for a post in its own folder (posts/foo/index.org), or
\"posts/foo.html\" for a single-file post (posts/foo.org)."
  (let ((html (concat (file-name-sans-extension (blog-rel-file (car entry))) ".html")))
    (if (string= (file-name-nondirectory html) "index.html")
        (file-name-directory html)
      html)))

(defun blog-delete-if-exists (file)
  (when (file-exists-p file) (delete-file file)))

;; ox-rss turns every top-level headline of one Org file into a feed item.
;; Our posts are one file each, so before publishing we write a small
;; .cache/rss/<lang>/rss.org with a headline per post (title, date,
;; #+DESCRIPTION as the summary, and a link to the full post).  The
;; "blog-rss-<lang>" project below then turns that file into rss.xml.
(defun blog-write-rss-source (lang)
  (let ((entries (blog-post-entries lang))
        (dir (blog-path ".cache/rss" lang))
        (coding-system-for-write 'utf-8)
        (system-time-locale "C"))
    (if (null entries)
        (blog-delete-if-exists (expand-file-name "rss.org" dir))
      (make-directory dir t)
      (with-temp-file (expand-file-name "rss.org" dir)
        (insert (format "#+TITLE: %s\n#+DESCRIPTION: %s\n#+AUTHOR: %s\n#+LANGUAGE: %s\n\n"
                        (blog-site-title lang) (blog-site-description lang) blog-author
                        (blog-lang-prop lang :locale)))
        (dolist (entry entries)
          (let* ((meta (cdr entry))
                 (path (blog-post-url-path entry)))
            (insert (format (concat "* %s\n:PROPERTIES:\n:RSS_PERMALINK: %s\n"
                                    ":PUBDATE: %s\n:ID: %s\n:END:\n")
                            (blog-plain-title (plist-get meta :title))
                            path
                            ;; ox-rss reads this back in the build's own zone
                            ;; (blog-timezone, set in `blog-publish'), so write
                            ;; it there: the instant stays the post's real one
                            ;; and feed readers convert it correctly.
                            (format-time-string "%Y-%m-%d %a %H:%M"
                                                (plist-get meta :date) blog-timezone)
                            path))
            (unless (string-empty-p (plist-get meta :description))
              (insert (plist-get meta :description) "\n\n"))
            (insert (format "[[%s%s/%s][%s]]\n\n"
                            blog-site-url (blog-lang-prefix lang) path
                            (blog-str lang 'read-full)))))))))

;; The posts index is written to content/posts/index.org (index.<lang>.org for
;; a translation) before publishing; it is git-ignored.  The list is raw HTML so each row can carry
;; its tags and hero image; the tag pills, search box and hover preview are
;; driven by content/js/site.js.
(defun blog-tag-order (entries)
  "All tags used by ENTRIES, most used first."
  (let (counts)
    (dolist (entry entries)
      (dolist (tag (plist-get (cdr entry) :tags))
        (let ((cell (assoc tag counts)))
          (if cell (cl-incf (cdr cell)) (push (cons tag 1) counts)))))
    (mapcar #'car (sort (nreverse counts) (lambda (a b) (> (cdr a) (cdr b)))))))

(defun blog-write-posts-index (lang)
  (let* ((index (blog-source-file lang "posts/index.org"))
         (entries (blog-post-entries lang))
         (coding-system-for-write 'utf-8))
    (if (null entries)
        (blog-delete-if-exists index)
      (with-temp-file index
        (insert (format "#+TITLE: %s\n#+LAYOUT: list\n#+LANGUAGE: %s\n\n#+begin_export html\n"
                        (blog-str lang 'posts) (blog-lang-prop lang :locale)))
        (insert (format "<header class=\"list-head\"><h1 class=\"title\">%s</h1><p class=\"lede\">%s</p>%s</header>\n"
                        (blog-text (blog-str lang 'posts))
                        (blog-text (blog-site-description lang))
                        (format "<p class=\"subnav\"><a href=\"%s\">%s</a>%s</p>"
                                (blog-nav-url lang "archive.org") (blog-text (blog-str lang 'archive))
                                (if (blog-page-exists-p lang "tags.org")
                                    (format "<a href=\"%s\">%s</a>"
                                            (blog-nav-url lang "tags.org") (blog-text (blog-str lang 'tags)))
                                  ""))))
        (let ((tags (blog-tag-order entries)))
          (when tags
            (insert (format "<div class=\"pills\" role=\"group\" aria-label=\"%s\">"
                            (blog-attr (blog-str lang 'filter))))
            (insert (format "<button type=\"button\" class=\"pill is-active\" data-tag=\"\">%s</button>"
                            (blog-text (blog-str lang 'all))))
            (dolist (tag tags)
              (insert (format "<button type=\"button\" class=\"pill\" data-tag=\"%s\">%s</button>"
                              (downcase tag) (blog-text tag))))
            (insert "</div>\n")))
        (insert "<ul class=\"post-list\">\n")
        (dolist (entry entries)
          (let* ((meta (cdr entry))
                 (href (substring (blog-post-url-path entry) (length "posts/")))
                 (hero (plist-get meta :hero)))
            (insert (format "<li data-tags=\"%s\"><a href=\"%s\"><span class=\"t\">%s</span><time>%s &middot; %s</time></a>"
                            (downcase (mapconcat #'identity (plist-get meta :tags) " "))
                            href
                            (blog-text (blog-plain-title (plist-get meta :title)))
                            (blog-date-string (plist-get meta :date) lang
                                              (plist-get meta :timezone))
                            (blog-text (blog-reading-time-string (car entry) lang))))
            (when (and hero (not (string-empty-p hero)))
              (insert (format "<img class=\"preview\" src=\"%s\" alt=\"\" loading=\"lazy\" />"
                              (blog-asset-url (car entry) hero))))
            (insert "</li>\n")))
        (insert (format "</ul>\n<p class=\"empty\" hidden>%s</p>\n#+end_export\n"
                        (blog-text (blog-str lang 'none-list))))))))

;; JSON Feed (https://jsonfeed.org): the same posts as rss.xml, for readers that prefer it.
(defun blog-iso-date (time zone)
  "TIME as 2026-09-30T00:00:00-04:00 in ZONE."
  (replace-regexp-in-string
   "\\([+-][0-9][0-9]\\)\\([0-9][0-9]\\)\\'" "\\1:\\2"
   (format-time-string "%Y-%m-%dT%H:%M:%S%z" time zone)))

(defun blog-write-json-feed (lang)
  (let* ((entries (blog-post-entries lang))
         (file (expand-file-name "feed.json" (blog-lang-out lang)))
         (coding-system-for-write 'utf-8)
         (json-encoding-pretty-print t)
         (prefix (blog-lang-prefix lang)))
    (if (null entries)
        (blog-delete-if-exists file)
      (make-directory (file-name-directory file) t)
      (with-temp-file file
        (insert
         (json-encode
          `((version . "https://jsonfeed.org/version/1.1")
            (title . ,(blog-site-title lang))
            (description . ,(blog-site-description lang))
            (language . ,(blog-lang-prop lang :hreflang))
            (home_page_url . ,(concat blog-origin (blog-url (concat prefix "/"))))
            (feed_url . ,(concat blog-origin (blog-url (concat prefix "/feed.json"))))
            (authors . [((name . ,blog-author))])
            (items
             . ,(vconcat
                 (mapcar
                  (lambda (entry)
                    (let* ((meta (cdr entry))
                           (url (concat blog-origin (blog-entry-url entry lang)))
                           (hero (plist-get meta :hero)))
                      (append
                       `((id . ,url)
                         (url . ,url)
                         (title . ,(blog-plain-title (plist-get meta :title)))
                         (date_published . ,(blog-iso-date (plist-get meta :date) (plist-get meta :timezone)))
                         (tags . ,(vconcat (plist-get meta :tags))))
                       (unless (string-empty-p (plist-get meta :description))
                         `((summary . ,(plist-get meta :description))))
                       (when (and hero (not (string-empty-p hero)))
                         `((image . ,(concat blog-origin (blog-asset-url (car entry) hero))))))))
                  entries))))))))))

;; The Archive and Tags pages are generated like the posts index: content/archive.org
;; and content/tags.org (archive.<lang>.org for a translation), git-ignored.
(defun blog-list-header (lang title lede)
  (format "#+TITLE: %s\n#+LAYOUT: list\n#+LANGUAGE: %s\n#+DESCRIPTION: %s\n\n#+begin_export html\n<header class=\"list-head\"><h1 class=\"title\">%s</h1><p class=\"lede\">%s</p></header>\n"
          title (blog-lang-prop lang :locale) lede
          (blog-text title) (blog-text lede)))

(defun blog-write-archive (lang)
  "Every post, grouped by year."
  (let* ((file (blog-source-file lang "archive.org"))
         (entries (blog-post-entries lang))
         (coding-system-for-write 'utf-8)
         (year nil))
    (if (null entries)
        (blog-delete-if-exists file)
      (with-temp-file file
        (insert (blog-list-header lang (blog-str lang 'archive) (blog-str lang 'archive-lede)))
        (dolist (entry entries)
          (let ((y (nth 5 (decode-time (plist-get (cdr entry) :date)
                                       (plist-get (cdr entry) :timezone)))))
            (unless (eql y year)
              (when year (insert "</ul></section>\n"))
              (setq year y)
              (insert (format "<section><h2 id=\"%d\">%d</h2><ul class=\"archive-list\">\n" y y)))
            (insert (blog-entry-li entry lang))))
        (insert "</ul></section>\n#+end_export\n")))))

(defun blog-write-tags (lang)
  "Every tag, most used first, with its posts."
  (let* ((file (blog-source-file lang "tags.org"))
         (entries (blog-post-entries lang))
         (tags (blog-tag-order entries))
         (coding-system-for-write 'utf-8))
    (if (or (null entries) (null tags))
        (blog-delete-if-exists file)
      (with-temp-file file
        (insert (blog-list-header lang (blog-str lang 'tags) (blog-str lang 'tags-lede)))
        (dolist (tag tags)
          (let ((posts (seq-filter (lambda (e) (member tag (plist-get (cdr e) :tags))) entries)))
            (insert (format "<section><h2 id=\"%s\" data-count=\"%d\">%s</h2><ul class=\"archive-list\">\n"
                            (blog-slug tag) (length posts) (blog-text tag)))
            (dolist (e posts) (insert (blog-entry-li e lang)))
            (insert "</ul></section>\n")))
        (insert "#+end_export\n")))))

;; public/[<lang>/]search-index.json holds each post's title, tags, summary
;; and plain text.  content/js/site.js loads it the first time
;; the search box is used and searches it in the browser.
(require 'json)

(defun blog-post-plain-text (file &optional whole)
  "The readable text of the Org post FILE: no keywords, comments or markup.
The text is cut to 20000 characters (enough for search) unless WHOLE is non-nil."
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
        (string-trim (if whole text (substring text 0 (min (length text) 20000))))))))

;; Reading time.  Words are counted for spaced languages; Japanese has no
;; spaces, so its characters are counted instead.
(defvar blog-words-per-minute 230
  "Reading speed for languages written with spaces between words.")
(defvar blog-cjk-chars-per-minute 500
  "Reading speed for Japanese, in characters per minute.")

(defun blog-reading-minutes (file)
  "Whole minutes (at least 1) to read the Org post FILE."
  (let* ((text (blog-post-plain-text file t))
         (cjk (with-temp-buffer
                (insert text)
                (goto-char (point-min))
                (let ((n 0))
                  (while (re-search-forward "\\cj" nil t) (cl-incf n))
                  n)))
         (rest (replace-regexp-in-string "\\cj" " " text))
         (words (length (split-string rest "[ \t\n]+" t))))
    (max 1 (ceiling (+ (/ (float words) blog-words-per-minute)
                       (/ (float cjk) blog-cjk-chars-per-minute))))))

(defun blog-reading-time-string (file lang)
  "\"8 min read\" for the post FILE, worded for LANG."
  (format (blog-str lang 'reading-time) (blog-reading-minutes file)))

(defun blog-write-search-index (lang)
  "Write public/[<lang>/]search-index.json, or remove a stale one."
  (let* ((entries (blog-post-entries lang))
         (file (expand-file-name "search-index.json" (blog-lang-out lang)))
         (coding-system-for-write 'utf-8)
         (json-encoding-pretty-print nil))
    (if (null entries)
        (blog-delete-if-exists file)
      (make-directory (file-name-directory file) t)
      (with-temp-file file
        (insert
         (json-encode
          (vconcat
           (mapcar
            (lambda (entry)
              (let ((meta (cdr entry)))
                `((title . ,(blog-plain-title (plist-get meta :title)))
                  (url . ,(blog-url (concat (blog-lang-prefix lang) "/"
                                            (blog-post-url-path entry))))
                  (date . ,(blog-date-string (plist-get meta :date) lang
                                             (plist-get meta :timezone)))
                  (tags . ,(vconcat (plist-get meta :tags)))
                  (description . ,(plist-get meta :description))
                  (text . ,(blog-post-plain-text (car entry))))))
            entries))))))))

;; ---------------------------------------------------------------
;; Projects
;; ---------------------------------------------------------------
;; Publish foo.is.org as foo.html: a translation sits beside its original in
;; the source tree, but each language is published into its own folder.
(defun blog-publish-translation (plist filename pub-dir)
  (org-html-publish-to-html plist filename pub-dir)
  (let* ((base (file-name-sans-extension (file-name-nondirectory filename)))   ; "foo.is"
         (made (expand-file-name (concat base ".html") pub-dir))
         (final (expand-file-name
                 (concat (file-name-sans-extension base) ".html") pub-dir)))   ; "foo.html"
    (when (file-exists-p made)
      (rename-file made final t))))

;; Options shared by every HTML component of language LANG.
(defun blog-common (lang)
  (list :language (blog-lang-prop lang :locale)
        :with-title nil                   ; blog-preamble draws the title
        :with-toc nil
        :section-numbers nil
        :headline-levels 6                ; Org's default of 3 turns deeper headings into bullet lists
        :html-footnotes-section
        "<div id=\"footnotes\"><h2 class=\"footnotes\">%s</h2><div id=\"text-footnotes\">%s</div></div>"
        :with-author nil
        :with-creator nil
        :time-stamp-file nil
        :html-doctype "html5"
        :html-html5-fancy t
        :html-head-include-default-style nil
        :html-head-include-scripts nil
        :html-validation-link nil
        :html-head (blog-head lang)
        :html-preamble 'blog-preamble
        :html-postamble 'blog-postamble))

(defun blog-projects ()
  "Pages, posts and feed for each language that has pages, plus the static files."
  (let* ((drafts (blog-draft-excludes))
         projects names)
    (dolist (code (blog-codes))
      (when (blog-lang-exists-p code)
        (let* ((out (blog-lang-out code))
               (common (blog-common code))
               ;; Which files belong to this language.  The default language is every
               ;; .org file that is not a translation; a translation is foo.<code>.org.
               (select (if (blog-default-p code)
                           (list :base-extension "org"
                                 :exclude (blog-join-regexps (blog-translation-regexp) (car drafts))
                                 :publishing-function 'org-html-publish-to-html)
                         (append (list :base-extension (concat code "\\.org")
                                       :publishing-function 'blog-publish-translation)
                                 (and (car drafts) (list :exclude (car drafts))))))
               (pages (concat "blog-pages-" code))
               (posts (concat "blog-posts-" code))
               (rss (concat "blog-rss-" code)))
          ;; Home, about, ... : the .org files directly inside content/.
          (push (append (list pages
                              :base-directory (blog-path "content")
                              :recursive nil
                              :publishing-directory out)
                        select common)
                projects)
          (push pages names)
          ;; Posts (and the generated index beside them).
          (when (and (file-directory-p (blog-path "content/posts"))
                     (or (blog-default-p code) (blog-has-posts-p code)))
            (push (append (list posts
                                :base-directory (blog-path "content/posts")
                                :recursive t
                                :publishing-directory (expand-file-name "posts" out))
                          select common)
                  projects)
            (push posts names))
          ;; The feed, made from .cache/rss/<lang>/rss.org.
          (when (blog-has-posts-p code)
            (push (list rss
                        :base-directory (blog-path ".cache/rss" code)
                        :base-extension "org"
                        :recursive nil
                        :publishing-directory out
                        :publishing-function 'org-rss-publish-to-rss
                        :rss-extension "xml"
                        :html-link-home (concat blog-site-url (blog-lang-prefix code))
                        :html-link-use-abs-url t
                        :with-toc nil
                        :section-numbers nil)
                  projects)
            (push rss names)))))
    (append
     (nreverse projects)
     (list
      ;; css, js and images are copied as they are, including the images
      ;; that sit in a post's own folder.
      (list "blog-static"
            :base-directory (blog-path "content")
            :base-extension blog-asset-extensions
            :recursive t
            :exclude (or (cdr drafts) "\\`\\'a")   ; the folders of unpublished posts
            :publishing-directory (blog-path "public")
            :publishing-function 'org-publish-attachment)
      (list "blog" :components (append (nreverse names) (list "blog-static")))))))

(setq org-publish-project-alist (blog-projects))

;; A post in its own folder keeps its images beside it, and writes them as
;; plain relative links ([[file:cover.png]]).  The "blog-static" project puts
;; those files next to the default-language page, but a translation is
;; published somewhere else (/is/posts/foo/), so its links would break.  Copy
;; the folder's assets there too, for each translated post folder.
(defun blog-copy-post-assets (lang)
  "Copy the files in each of LANG's post folders next to LANG's pages."
  (unless (blog-default-p lang)
    (dolist (file (blog-post-files lang))
      (when (string= (file-name-base (blog-rel-file file)) "index")   ; posts/foo/index.<lang>.org
        (let* ((src (file-name-directory file))
               (dest (expand-file-name (file-relative-name src (blog-path "content"))
                                       (blog-lang-out lang))))
          (dolist (asset (directory-files-recursively
                          src (concat "\\`[^.#].*\\.\\(?:" blog-asset-extensions "\\)\\'")))
            (let ((target (expand-file-name (file-relative-name asset src) dest)))
              (make-directory (file-name-directory target) t)
              (copy-file asset target t t))))))))

;; [[id:...]] links.  Org needs to know which file holds each :ID: before it
;; can turn such a link into a URL, so scan the originals (not the translations,
;; which would repeat the same IDs) before publishing.  Without this, one id: link
;; stops the whole build.
(require 'org-id)

;; Heading anchors.  Org's own ids (org65e3b9e) change whenever a post is edited,
;; which would break every shared link to a section, so each heading gets one made
;; from its text instead (#why-i-started-learning-icelandic), kept unique per page.
;; A heading with an :ID: gets the anchor "ID-<id>" instead, which is where Org
;; points [[id:...]] links that lead to another file.  A heading with a
;; :CUSTOM_ID: keeps it.
(defun blog-slug (text)
  "TEXT as a URL-safe anchor: lower case, letters and digits joined by hyphens."
  (let ((slug (string-trim
               (downcase (replace-regexp-in-string
                          "[^[:alnum:]]+" "-" (blog-plain-title text)))
               "-+" "-+")))
    (if (string-empty-p slug) "section" slug)))

(defun blog-heading-anchors (tree backend _info)
  (unless (org-export-derived-backend-p backend 'rss)
    (let ((used (list "content" "footnotes" "text-footnotes" "preamble" "postamble")))
      (org-element-map tree 'headline
        (lambda (h)
          (let ((c (org-element-property :CUSTOM_ID h))) (when c (push c used)))))
      (org-element-map tree 'headline
        (lambda (h)
          (unless (org-element-property :CUSTOM_ID h)
            (let ((id (org-element-property :ID h)))
              (if id
                  (org-element-put-property h :CUSTOM_ID (concat "ID-" id))
                (let* ((base (blog-slug (org-element-property :raw-value h)))
                       (slug base) (n 1))
                  (while (member slug used)
                    (setq n (1+ n) slug (format "%s-%d" base n)))
                  (push slug used)
                  (org-element-put-property h :CUSTOM_ID slug)))))))))
  tree)

(add-to-list 'org-export-filter-parse-tree-functions #'blog-heading-anchors)

(defun blog-register-ids ()
  (setq org-id-locations-file (blog-path ".cache/org-id-locations")
        org-id-track-globally t)
  (make-directory (blog-path ".cache") t)
  (let ((files (seq-remove (lambda (f)
                             (or (string-match-p (blog-translation-regexp) f)
                                 (string-match-p "/posts/index\\.org\\'" f)))
                           (directory-files-recursively
                            (blog-path "content") "\\`[^.#].*\\.org\\'"))))
    (setq org-id-locations (make-hash-table :test 'equal))
    (org-id-update-id-locations files t)))

;; sitemap.xml lists every page in every language, each with its translations,
;; so search engines find them all.  robots.txt points to it (it only works at
;; the root of a domain, so it is skipped when the site lives in a subfolder).
(defun blog-xml (s)
  (replace-regexp-in-string
   ">" "&gt;" (replace-regexp-in-string
               "<" "&lt;" (replace-regexp-in-string "&" "&amp;" s t t) t t) t t))

(defun blog-write-sitemap ()
  (let ((rels (list "index.org" "about.org" "posts/index.org" "archive.org" "tags.org"))
        (coding-system-for-write 'utf-8))
    (dolist (code (blog-codes))
      (dolist (file (blog-post-files code))
        (cl-pushnew (blog-rel-file file) rels :test #'string=)))
    (setq rels (nreverse rels))
    (with-temp-file (blog-path "public/sitemap.xml")
      (insert "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
              "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" "
              "xmlns:xhtml=\"http://www.w3.org/1999/xhtml\">\n")
      (dolist (rel rels)
        (let ((alts (blog-alternates rel)))
          (dolist (alt alts)
            (insert "<url><loc>" (blog-xml (concat blog-origin (cdr alt))) "</loc>")
            (when (string-prefix-p "posts/" rel)
              (let ((src (blog-source-file (car alt) rel)))
                (when (and (file-exists-p src) (not (string= rel "posts/index.org")))
                  (insert "<lastmod>"
                          (format-time-string "%F" (plist-get (blog-post-meta src) :date)
                                              (plist-get (blog-post-meta src) :timezone))
                          "</lastmod>"))))
            (when (> (length alts) 1)
              (dolist (other alts)
                (insert (format "<xhtml:link rel=\"alternate\" hreflang=\"%s\" href=\"%s\"/>"
                                (blog-lang-prop (car other) :hreflang)
                                (blog-xml (concat blog-origin (cdr other)))))))
            (insert "</url>\n"))))
      (insert "</urlset>\n"))
    (when (string-empty-p blog-base-path)
      (with-temp-file (blog-path "public/robots.txt")
        (insert "User-agent: *\nAllow: /\n\nSitemap: " blog-origin "/sitemap.xml\n")))))

;; ---------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------
(defun blog-publish ()
  "Build the whole site into public/."
  (interactive)
  (set-time-zone-rule blog-timezone)
  (setq blog--entries-cache nil)
  (clrhash blog--published-cache)
  (blog-register-ids)
  (dolist (code (blog-codes))
    (when (blog-lang-exists-p code)
      (blog-write-rss-source code)
      (blog-write-archive code)
      (blog-write-tags code)
      (blog-write-posts-index code)))
  (org-publish "blog" t)
  (dolist (code (blog-codes))
    (when (blog-lang-exists-p code)
      (blog-copy-post-assets code)
      (blog-write-json-feed code)
      (blog-write-search-index code)))
  (blog-write-sitemap)
  ;; Stop GitHub Pages running Jekyll over the output.
  (write-region "" nil (blog-path "public/.nojekyll") nil 'silent)
  (message "Blog published to %s" (blog-path "public")))

(provide 'publish)
;;; publish.el ends here
