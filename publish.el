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
(defvar blog-timezone "America/Port_of_Spain"
  "Timezone used when generating RSS publication dates.")

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
     (read-full . "Read the full post") (date-format . "%d %s %d"))
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
     (read-full . "Lesa alla færsluna") (date-format . "%d. %s %d"))
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
     (read-full . "Läs hela inlägget") (date-format . "%d %s %d"))
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

(defun blog-date-string (time &optional lang)
  "TIME as a date such as \"30 September 2026\", in LANG."
  (let* ((lang (or lang blog-default-language))
         (months (or (cdr (assoc lang blog-months))
                     (cdr (assoc blog-default-language blog-months))))
         (d (decode-time time)))
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

(defun blog-post-files (&optional lang)
  "LANG's post files under content/posts, leaving out the generated index."
  (let* ((lang (or lang blog-default-language))
         (dir (blog-path "content/posts"))
         (index (blog-source-file lang "posts/index.org")))
    (when (file-directory-p dir)
      (seq-filter (lambda (file)
                    (and (equal (blog-lang-of-file file) lang)
                         (not (string= (expand-file-name file) index))))
                  (directory-files-recursively dir "\\`[^.#].*\\.org\\'")))))

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

(defun blog-search-index-url (lang)
  (blog-url (concat (blog-lang-prefix (blog-content-lang lang)) "/search-index.json")))

;; ---------------------------------------------------------------
;; Page furniture
;; ---------------------------------------------------------------
(defun blog-url (path)
  (concat blog-base-path path))

(defun blog-head (lang)
  (concat
   "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />"
   "<meta name=\"color-scheme\" content=\"light dark\" />"
   (format "<meta name=\"blog-language\" content=\"%s\" />" lang)
   ;; Apply a saved theme before the page paints, so there is no flash.
   "<script>try{var t=localStorage.getItem('theme');if(t)document.documentElement.dataset.theme=t}catch(e){}</script>"
   (format "<link rel=\"stylesheet\" href=\"%s\" />" (blog-url "/css/style.css"))
   (format "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"%s\" href=\"%s\" />"
           (blog-site-title lang) (blog-feed-url lang))
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
  (unless (equal (blog-keyword info "LAYOUT") "list")
    (let ((hero (blog-keyword info "HERO"))
          (time (blog-info-date info))
          (lang (blog-info-lang info)))
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
                 (blog-date-string time lang)
                 (blog-initials)
                 blog-author))))))

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
   (format "<nav class=\"dock\" aria-label=\"Site\" data-no-match=\"%s\" data-unavailable=\"%s\">"
           (blog-attr (blog-str lang 'no-match))
           (blog-attr (blog-str lang 'unavailable)))
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

(defun blog-postamble (info)
  "Footer for every page: end-of-post links (dated posts only), colophon, dock."
  (let ((lang (blog-info-lang info))
        (rel (blog-info-rel info)))
    (concat
     (when (blog-info-date info)
       (format (concat "<nav class=\"endnav\"><a href=\"%s\">&larr; %s</a>"
                       "<a href=\"%s\">%s &rarr;</a></nav>")
               (blog-nav-url lang "posts/index.org")
               (blog-text (blog-str lang 'read-more))
               (blog-feed-url lang)
               (blog-text (blog-str lang 'rss))))
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
   "var c=l.hreflang.toLowerCase().split('-')[0];if(c!=='x'&&!alts[c])alts[c]=l.href;});"
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
      (format "<link rel=\"alternate\" hreflang=\"%s\" href=\"%s\" />"
              (blog-lang-prop (car alt) :hreflang) (cdr alt)))
    alts "")
   (let ((default (assoc blog-default-language alts)))
     (if default
         (format "<link rel=\"alternate\" hreflang=\"x-default\" href=\"%s\" />" (cdr default))
       ""))
   blog-redirect-script))

(defun blog-final-output (output backend info)
  "Give every exported page the right <html lang> and its language alternates."
  (let ((file (plist-get info :input-file)))
    (if (not (and file
                  (org-export-derived-backend-p backend 'html)
                  (not (org-export-derived-backend-p backend 'rss))
                  (string-prefix-p (blog-path "content") (expand-file-name file))))
        output
      (let ((lang (blog-lang-of-file file))
            (alts (blog-alternates (blog-rel-file file))))
        (setq output (replace-regexp-in-string
                      "<html lang=\"[^\"]*\""
                      (format "<html lang=\"%s\"" (blog-lang-prop lang :locale))
                      output t t))
        (if (or (< (length alts) 2) (not (string-match "</head>" output)))
            output
          (let ((pos (match-beginning 0)))
            (concat (substring output 0 pos) (blog-alternate-head alts) (substring output pos))))))))

(add-to-list 'org-export-filter-final-output-functions #'blog-final-output)

;; ---------------------------------------------------------------
;; Posts: metadata, feed, index page, search index
;; ---------------------------------------------------------------
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

(defun blog-post-entries (lang)
  "(FILE . META) for each of LANG's posts, newest first."
  (sort (mapcar (lambda (file) (cons file (blog-post-meta file)))
                (blog-post-files lang))
        (lambda (a b)
          (time-less-p (plist-get (cdr b) :date)
                       (plist-get (cdr a) :date)))))

(defun blog-post-html-path (entry)
  "ENTRY's page path below its language's site folder, e.g. \"posts/foo.html\"."
  (concat (file-name-sans-extension (blog-rel-file (car entry))) ".html"))

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
                 (path (blog-post-html-path entry)))
            (insert (format (concat "* %s\n:PROPERTIES:\n:RSS_PERMALINK: %s\n"
                                    ":PUBDATE: %s\n:ID: %s\n:END:\n")
                            (blog-plain-title (plist-get meta :title))
                            path
                            (format-time-string "%Y-%m-%d %a %H:%M" (plist-get meta :date))
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
        (insert (format "<header class=\"list-head\"><h1 class=\"title\">%s</h1><p class=\"lede\">%s</p></header>\n"
                        (blog-text (blog-str lang 'posts))
                        (blog-text (blog-site-description lang))))
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
                 (href (substring (blog-post-html-path entry) (length "posts/")))
                 (hero (plist-get meta :hero)))
            (insert (format "<li data-tags=\"%s\"><a href=\"%s\"><span class=\"t\">%s</span><time>%s</time></a>"
                            (downcase (mapconcat #'identity (plist-get meta :tags) " "))
                            href
                            (blog-text (blog-plain-title (plist-get meta :title)))
                            (blog-date-string (plist-get meta :date) lang)))
            (when (and hero (not (string-empty-p hero)))
              (insert (format "<img class=\"preview\" src=\"%s\" alt=\"\" loading=\"lazy\" />"
                              (blog-url (concat "/" hero)))))
            (insert "</li>\n")))
        (insert (format "</ul>\n<p class=\"empty\" hidden>%s</p>\n#+end_export\n"
                        (blog-text (blog-str lang 'none-list))))))))

;; public/[<lang>/]search-index.json holds each post's title, tags, summary
;; and plain text.  content/js/site.js loads it the first time
;; the search box is used and searches it in the browser.
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
                                            (blog-post-html-path entry))))
                  (date . ,(blog-date-string (plist-get meta :date) lang))
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
  (let (projects names)
    (dolist (code (blog-codes))
      (when (blog-lang-exists-p code)
        (let* ((out (blog-lang-out code))
               (common (blog-common code))
               ;; Which files belong to this language.  The default language is every
               ;; .org file that is not a translation; a translation is foo.<code>.org.
               (select (if (blog-default-p code)
                           (list :base-extension "org"
                                 :exclude (blog-translation-regexp)
                                 :publishing-function 'org-html-publish-to-html)
                         (list :base-extension (concat code "\\.org")
                               :publishing-function 'blog-publish-translation)))
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
      ;; css, js and images are copied as they are.
      (list "blog-static"
            :base-directory (blog-path "content")
            :base-extension "css\\|js\\|png\\|jpg\\|jpeg\\|gif\\|svg\\|webp\\|ico\\|txt"
            :recursive t
            :publishing-directory (blog-path "public")
            :publishing-function 'org-publish-attachment)
      (list "blog" :components (append (nreverse names) (list "blog-static")))))))

(setq org-publish-project-alist (blog-projects))

;; ---------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------
(defun blog-publish ()
  "Build the whole site into public/."
  (interactive)
  (set-time-zone-rule blog-timezone)
  (dolist (code (blog-codes))
    (when (blog-lang-exists-p code)
      (blog-write-rss-source code)
      (blog-write-posts-index code)))
  (org-publish "blog" t)
  (dolist (code (blog-codes))
    (when (blog-lang-exists-p code)
      (blog-write-search-index code)))
  ;; Stop GitHub Pages running Jekyll over the output.
  (write-region "" nil (blog-path "public/.nojekyll") nil 'silent)
  (message "Blog published to %s" (blog-path "public")))

(provide 'publish)
;;; publish.el ends here
