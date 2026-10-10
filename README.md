# My Org-mode blog

A small static blog built with Emacs' own `org-publish`. You need Emacs 27 or
later with Org mode (Org 9.5 or newer is recommended). The build script also installs two
packages for you the first time it runs, so that run needs a network connection:

- `htmlize`, which colours source code blocks.
- `org-contrib`, which provides `ox-rss` for the RSS feed.

## Layout

```
publish.el                 Build script: settings, project definitions, page header/footer
content/
  index.org                Home page            (index.is.org: its Icelandic translation)
  about.org                About page           (about.is.org, ...)
  posts/foo/index.org      A post in its own folder (index.is.org beside it is the translation)
  posts/foo/banner.png     ...with its images next to it
  posts/bar.org            A single-file post also works (bar.is.org is its translation)
                           (posts/index.org and posts/index.*.org are generated)
  css/style.css            Site stylesheet (warm grey, one column; light and dark)
  js/site.js               Bottom dock: theme toggle, language menu, search, tag filter, table of contents
  images/                  Optional: images shared by several pages, referenced as images/name.png
  fonts/                   Inter (self-hosted) and its licence
  404.org, favicon.svg     Not-found page and site icon
scripts/check-links.py     Broken-link check, run by the deploy workflow
public/                    Build output, including rss.xml and search-index.json (generated, git-ignored)
.github/workflows/         Optional: deploy to GitHub Pages
```

## Build and preview

```sh
emacs --batch -l publish.el -f blog-publish
python3 -m http.server -d public 8000
```

Then open <http://localhost:8000>. (Use the local server rather than opening the
files directly, because the links and stylesheet are root-relative.)

You can also build from inside Emacs: `M-x load-file RET publish.el RET`, then
`M-x blog-publish`.

## Writing a new post

Make a folder for the post, with the post and everything it uses inside it:

```
content/posts/my-post/
  index.org          the post
  banner.png         its hero image
  diagram.png        any other images
```

`content/posts/my-post/index.org` needs at least:

```org
#+TITLE: My post title
#+DATE: <2026-10-05 Mon>
#+TIMEZONE: America/Port_of_Spain
#+FILETAGS: :emacs:org-mode:
#+DESCRIPTION: One or two sentences, shown as the summary in the RSS feed.
#+HERO: banner.png
#+LANGUAGE: en-GB

* First heading

Text...

[[file:diagram.png]]
```

Links to files in the folder are written without any path (`[[file:diagram.png]]`,
`#+HERO: banner.png`). The post is published at `/posts/my-post/` and its images
at `/posts/my-post/diagram.png`, so the same relative link works on the page.
Rebuild and the post appears on the Posts page and in the feed automatically.

The `#+DATE:` decides the order on the Posts page and in the feed (newest first).

A post can also be a single file, `content/posts/my-post.org` (published at
`/posts/my-post.html`). For that style, put images in `content/images/` and
link them as `[[file:../images/name.png]]` with `#+HERO: images/name.png`.
`#+HERO:` is looked for beside the post first and then inside `content/`, and the
build prints a warning if it can't find the file.

## Extras built in

- **Reading time:** every post shows "N min read" beside its date, and the Posts
  list shows it too. It is worked out at build time from the post's text
  (`blog-words-per-minute`, 230 by default; Japanese counts characters at
  `blog-cjk-chars-per-minute`, 500). The wording per language lives in `blog-strings`.
- **Link previews and search engines:** each page gets a description, a canonical
  URL and Open Graph / Twitter tags (the hero image becomes the preview picture),
  and the `hreflang` links are fully qualified. These need `BLOG_ORIGIN` to be set,
  which the deploy workflow does.
- **`sitemap.xml` and `robots.txt`**, generated on every build.
- **`404.html`** (from `content/404.org`), which GitHub Pages shows for missing pages.
- **Copy button** on code blocks (appears on hover; always visible on touch screens).
- **Archive and Tags pages** (`/archive.html`, `/tags.html`, generated on every build
  like the Posts page and git-ignored). The Archive groups posts by year; Tags lists
  each tag with its posts. Both are linked under the heading of the Posts page, and
  a post's tags link to its entry on the Tags page. Their titles are in `blog-strings`.
- **End of a post:** its tags, up to three related posts (the ones sharing the most
  tags), and Older / Newer links.
- **Heading anchors:** hover a heading and click the `#` to copy a link to that
  section. Anchors are made from the heading's text (`#why-i-started-learning-icelandic`)
  so they don't change when you edit the post. A `:CUSTOM_ID:` property overrides one.
  Renaming a heading changes its anchor, so old links to it stop scrolling there.
- **Drafts and scheduled posts:** add `#+DRAFT: t` to a post, or give it a `#+DATE:` in
  the future, and it is left out of the site, feeds, search, sitemap, Archive and Tags
  (its images too) until you remove the line or the date arrives. A scheduled post goes
  live on the first build on or after its date. To see drafts while you write, build with
  `BLOG_DRAFTS=1 emacs --batch -l publish.el -f blog-publish`.
- **Accessibility:** a "skip to content" link; images get their alt text from the caption
  (`#+CAPTION:`), or from `#+ATTR_HTML: :alt description`, and count as decoration if they
  have neither. Describe the banner with `#+HERO_ALT: ...`. Images below the banner load lazily.
- **Inter, self-hosted** (`content/fonts/`), so every visitor sees the same typeface and no
  request goes to Google. Japanese text uses the system font.
- **Print stylesheet:** printing or saving a post as PDF drops the dock and shows the text, with
  external link addresses spelled out.
- **JSON Feed** (`/feed.json`, per language) beside `rss.xml`, and a default share image
  (`content/images/og-default.png`) for pages with no banner.
- **Link checker:** `python3 scripts/check-links.py public` checks every internal link, image
  and `#section` link in the built site. The deploy workflow runs it, so a broken link stops
  the deploy instead of going live. External links are not checked.
- **Favicon** (`content/favicon.svg`) and a browser theme colour for light and dark.

## Org features that work

Checked by building a post that uses them: links to other posts
(`[[file:../other-post/index.org][text]]`, also `::*Heading`), `[[id:...]]` links
(the build scans every `:ID:` first), custom-id and heading links, footnotes
(`[fn:1]` and inline), tables with captions, task lists, TODO keywords and heading
tags, quotes, verse, centred text, `#+begin_details`, callouts (`#+begin_note`,
`tip`, `warning`, `important`, `caution`), description lists, figures with
captions, raw `#+begin_export html`, entities, sub/superscripts and headings down
to six levels. LaTeX (`$x^2$`, `\[ ... \]`, `\begin{equation}`) is typeset by
MathJax, loaded from a CDN only on pages that contain maths.

Not supported: running code blocks at build time (`:exports results` /
`:exports both` do nothing useful, so paste output into the post), `#+INCLUDE:`
across the content folder, and links to files outside `content/`.

## Comments and analytics (optional, free)

Both are off until you fill in a setting near the top of `publish.el`.

**Comments** use [giscus](https://giscus.app), which stores them as GitHub Discussions in your
repository, so there is no extra account or database. Visitors sign in with GitHub to comment.

1. In the blog's GitHub repository: Settings, Features, tick **Discussions**.
2. Install the [giscus app](https://github.com/apps/giscus) on that repository.
3. Open <https://giscus.app>, enter your repository, and choose a category (an
   "Announcements" category is the usual pick). Under "Enable giscus" it shows
   `data-repo`, `data-repo-id`, `data-category` and `data-category-id`.
4. Put those four values into `blog-giscus` in `publish.el`:

   ```elisp
   (defvar blog-giscus
     '(:repo "you/blog" :repo-id "R_kgDO..." :category "Announcements" :category-id "DIC_kwDO..."))
   ```

Every language version of a post shares one discussion. The comment box follows the site's
light/dark toggle.

**Analytics** use [GoatCounter](https://www.goatcounter.com), which is free for personal sites,
uses no cookies and needs no consent banner. Sign up, pick a site code, and set
`(defvar blog-goatcounter "yourcode")`. Local previews are not counted.

## Timezones

`#+DATE:` is read as local time in the post's own zone, set with `#+TIMEZONE:`:

```org
#+DATE: <2027-03-02 Tue 09:30>
#+TIMEZONE: Atlantic/Reykjavik
```

If a post has no `#+TIMEZONE:`, it uses `blog-timezone` at the top of `publish.el`.
That is the only thing to change when you move country: new posts get the new
zone and old posts keep theirs, so nothing already written shifts.

A page only shows the date, and a date read and shown in the same zone always
shows what you typed, so the zone doesn't change what appears on a post. It sets
the exact moment the post was published, which matters for the order of posts
written in different countries and for the `pubDate` in the RSS feed. The feed
writes every date in the build's `blog-timezone`; feed readers convert it
correctly.

- Use IANA names such as `Europe/Stockholm`. POSIX-style strings such as `UTC+2`
  have the sign inverted, and the build stops with an error for a name it doesn't
  recognise rather than quietly using UTC.
- A translation is its own file, so give `index.is.org` its own `#+TIMEZONE:`
  line too.
- `#+PROPERTY: TIMEZONE name` is also understood, but `#+TIMEZONE:` is the
  spelling to use.
- This needs Emacs 27 or later.

## Look and feel

The design follows a reference video: a warm grey page, one narrow column, a bare
list of posts, and a floating bar at the bottom instead of a header.

- **Posts page:** a title, a one-line description (`blog-description` in
  `publish.el`), tag pills, then the posts newest first. Hovering a post shows its
  hero image beside the list. The pills filter by tag.
- **Post page:** hero image, title, then the date on the left and the author on the
  right, then the text. At the end are "Read more posts" and "Subscribe via RSS" links.
- **Bottom dock:** a floating bar on every page with a light/dark toggle (remembered in
  the browser) and buttons for Home, About and Posts. On short pages (home, About, the
  Posts page) it holds the search box. On a long post it shows the section you're
  reading with a progress ring, and a search button opens the box in its place.
- **Table of contents:** on a post, click the section name in the dock and it grows
  upward into a panel listing the post's headings (`*` as main entries, `**` indented
  beneath them). The section you're in is highlighted, clicking an entry scrolls
  there, and Esc or a click elsewhere closes it. It is built in the browser from the
  post's own headings, so there is nothing to maintain.
- **Dock animation:** the section name in the dock changes as you scroll, and the dock
  smoothly grows or shrinks to fit each new name (it does the same when the table of
  contents opens or the search box replaces the name). This is done by `morph()` in
  `content/js/site.js`; change the timing with the `transition: width` line on `.dock`
  in the stylesheet. It is skipped when the system's "reduce motion" setting is on.
- **Search:** press Ctrl/Cmd+K anywhere, or click the box. It searches every post's
  title, tags, summary and full text, ignores accents (so `hus` finds `hús`), needs
  every word you type to match, and shows the best matches with the matching text
  highlighted. Arrow keys and Enter pick a result; Esc closes it. The build writes the
  index to `public/search-index.json` (`public/is/search-index.json` for Icelandic) and it is fetched the first time
  you use the box.
- **Motion:** content fades up on load and the dock springs in. Everything respects
  the "reduce motion" setting, and the dock stays put when you move between pages in
  browsers that support cross-page view transitions.

Two extra keywords in a post's header feed this:

- `#+FILETAGS: :emacs:org-mode:` gives the post its tag pills on the Posts page.
- `#+HERO: banner.png` (a file in the post's folder, 2:1 works best) sets the hero
  image on the post and its hover preview in the list. Leave it out for no image.
  For a single-file post use a path inside `content/`, e.g. `images/name.png`.

The "avatar" next to the author's name is their initials in a circle. To use a photo
instead, change `.avatar` in `content/css/style.css` (a `background-image` and an
empty initials span would do it).

To change colours, fonts or widths, edit the variables at the top of
`content/css/style.css`.

## Languages

The site is in English by default and can have translations. A translation
sits **right beside its original**, with the language code before the extension:

```
content/
  index.org                  English home        ->  /
  index.is.org               Icelandic home      ->  /is/
  about.org                  English About       ->  /about.html
  posts/
    foo/
      index.org              English post        ->  /posts/foo/
      index.is.org           Icelandic post      ->  /is/posts/foo/
      index.sv.org           Swedish post        ->  /sv/posts/foo/
      banner.png             Images used by every version
    bar/
      index.org              English only: no Icelandic version
    baz.org                  A single-file post  ->  /posts/baz.html
    baz.is.org               ...and its translation  ->  /is/posts/baz.html
```

A page counts as translated when its `.is.org` file exists. To translate a post, copy
`index.org` to `index.is.org` in the same folder and translate the text (keep `#+DATE:`,
`#+TIMEZONE:`, `#+FILETAGS:` and `#+HERO:` the same; translate `#+TITLE:` and
`#+DESCRIPTION:`). Untranslated pages simply stay English-only. The build publishes
each language separately and drops the `.is` from the output name, so the URLs stay
tidy.

A translated post uses the images in its folder with the same plain links
(`[[file:diagram.png]]`): the build copies the folder's images next to each
translated page, so there is no `../../` to climb out of the language folder.
(Single-file posts still need the long way round, e.g. `[[file:../../images/name.png]]`
from `baz.is.org`.)

What readers get:

- **Their own language automatically.** On a page that exists in more than one
  language, a visitor is sent to the version matching the first language in their
  browser's preference list that the page is available in. Anyone whose list has no
  match, or has English first, stays on the English page.
- **A language dropdown** (globe icon and `EN`/`IS` at the right of the dock) on those
  pages. Choosing a language is remembered in the browser and from then on beats the
  automatic choice, so someone with an Icelandic browser who picks English stays on
  English. Pages with only one version have no dropdown.
- **Translated furniture.** The dock, table of contents, search box and messages,
  end-of-post links, dates (`30. september 2026`), the posts page, the RSS feed
  (`/is/rss.xml`) and the search index are all per language. Text the site adds itself
  lives in `blog-strings` in `publish.el`.
- **Sensible fallbacks.** If a language has no posts yet, its Posts button, feed and
  search use the English ones. If it has no About page, About links to the English one.
- **Search-engine markup.** Every translated page declares its other versions with
  `hreflang` links and the right `<html lang>`.

One thing to know when writing links: `[[file:bar.org]]` in a translation points to
`bar` **in the same language folder** (`/is/posts/bar.html`), which only exists if
`bar.is.org` does. To link to the English page from an Icelandic one, use a relative
path that climbs out of the language folder, e.g. `[[file:../posts/bar.org]]` from
`index.is.org` (as the sample home page does).

To add another language (say Swedish), add a line to `blog-languages` and entries for
`sv` to `blog-strings` and `blog-months` in `publish.el`, then write some
`something.sv.org` files.

`content/index.is.org` is a short sample so the dropdown shows up straight away; edit
or delete it. The Icelandic interface text in `blog-strings` is a first draft: have
someone who writes Icelandic well look it over before you rely on it.

## RSS feed

The build writes `public/rss.xml`, linked from the nav bar and from every page's
`<head>` so feed readers can find it. Each item has the post's title and date, its
`#+DESCRIPTION:` as the summary, and a link to the full post. (Posts without a
`#+DESCRIPTION:` get just the link.)

`ox-rss` turns each top-level headline of one Org file into a feed item, and posts
here are one file each. So before publishing, `blog-write-rss-source` in
`publish.el` writes a small generated `.cache/rss/<language>/rss.org` with one headline per
post, and the `blog-rss` project turns that into `rss.xml`.

Feed readers need absolute URLs, so the build also needs to know where the site
lives: `BLOG_ORIGIN` (scheme and host, e.g. `https://user.github.io`) plus
`BLOG_BASE` for any subfolder. If `BLOG_ORIGIN` is unset it defaults to
`http://localhost:8000`, which is fine for previewing but not for uploading.

## Syntax highlighting

With `htmlize` installed, Org wraps each token in a source block in a
`<span class="org-...">`. The colours are the `--syn-*` variables at the top of
`content/css/style.css` (with a dark-mode set), and the `.org-*` rules further down.
To see which classes your posts use:

```sh
grep -roh --include='*.html' 'class="org-[a-z0-9-]*"' public/posts | sort | uniq -c
```

## First things to edit

- `publish.el`: `blog-title`, `blog-author` and `blog-description` (the feed's
  description).
- `content/about.org`: replace the placeholder text.
- `content/posts/2026-09-30-from-icelandic-notes-to-a-published-book/index.org`: swap in your real
  Amazon link, and add the two screenshots marked `TODO`.

## Deploying

The output in `public/` is plain HTML, so it can go on any static host
(GitHub Pages, Netlify, Cloudflare Pages, your own server).

**GitHub Pages:** push this folder to a repository, then in the repository's
Settings, Pages, choose "GitHub Actions" as the source. `.github/workflows/deploy.yml`
builds and publishes on every push to `main`. If the site lives at
`user.github.io/REPO/`, the workflow already sets `BLOG_BASE=/REPO` and
`BLOG_ORIGIN=https://user.github.io`; for a `user.github.io` repository or a custom
domain, set `BLOG_BASE` to an empty string, and for a custom domain also set
`BLOG_ORIGIN` to it (e.g. `https://example.com`).

For other hosts, build locally (setting `BLOG_BASE` if the site is in a subfolder,
e.g. `BLOG_BASE=/blog BLOG_ORIGIN=https://example.com emacs --batch -l publish.el -f blog-publish`)
and upload `public/`.

## Ideas for later

- Full-text feed: items currently carry only the summary and a link. Putting each
  post's whole body in the feed is possible, but needs care with headings, images
  and relative links inside `blog-write-rss-source`.
