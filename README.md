# My Org-mode blog

A small static blog built with Emacs' own `org-publish`. You need Emacs with Org
mode (Org 9.5 or newer is recommended). The build script also installs two
packages for you the first time it runs, so that run needs a network connection:

- `htmlize`, which colours source code blocks.
- `org-contrib`, which provides `ox-rss` for the RSS feed.

## Layout

```
publish.el                 Build script: settings, project definitions, page header/footer
content/
  index.org                Home page            (index.is.org: its Icelandic translation)
  about.org                About page           (about.is.org, ...)
  posts/foo.org            One file per post    (foo.is.org beside it is the translation)
                           (posts/index.org and index.*.org are generated)
  css/style.css            Site stylesheet (warm grey, one column; light and dark)
  js/site.js               Bottom dock: theme toggle, language menu, search, tag filter, table of contents
  images/                  Images, referenced from posts as ../images/name.png
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

Create `content/posts/my-post.org` with at least:

```org
#+TITLE: My post title
#+DATE: <2026-10-05 Mon>
#+FILETAGS: :emacs:org-mode:
#+DESCRIPTION: One or two sentences, shown as the summary in the RSS feed.
#+HERO: images/my-post-banner.png
#+LANGUAGE: en-GB

* First heading

Text...
```

The `#+DATE:` decides the order on the Posts page and in the feed (newest first).
Put images in `content/images/` and link them as `[[file:../images/name.png]]`.
Rebuild and the post appears on the Posts page and in the feed automatically.

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
- `#+HERO: images/name.png` (a path inside `content/`, 2:1 works best) sets the hero
  image on the post and its hover preview in the list. Leave it out for no image.

The "avatar" next to the author's name is their initials in a circle. To use a photo
instead, change `.avatar` in `content/css/style.css` (a `background-image` and an
empty initials span would do it).

To change colours, fonts or widths, edit the variables at the top of
`content/css/style.css`.

## Languages

The site is in British English by default and can have translations. A translation
sits **right beside its original**, with the language code before the extension:

```
content/
  index.org                  English home        ->  /
  index.is.org               Icelandic home      ->  /is/
  about.org                  English About       ->  /about.html
  posts/
    foo.org                  English post        ->  /posts/foo.html
    foo.is.org               Icelandic post      ->  /is/posts/foo.html
    bar.org                  English only: no Icelandic version
```

A page counts as translated when its `.is.org` file exists. To translate a post, copy
`foo.org` to `foo.is.org` in the same folder and translate the text (keep `#+DATE:`,
`#+FILETAGS:` and `#+HERO:` the same; translate `#+TITLE:` and `#+DESCRIPTION:`).
Untranslated pages simply stay English-only. The build publishes each language
separately and drops the `.is` from the output name, so the URLs stay tidy.

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
grep -oh 'class="org-[a-z0-9-]*"' public/posts/*.html | sort | uniq -c
```

## First things to edit

- `publish.el`: `blog-title`, `blog-author` and `blog-description` (the feed's
  description).
- `content/about.org`: replace the placeholder text.
- `content/posts/from-icelandic-notes-to-a-published-book.org`: swap in your real
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
