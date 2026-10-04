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
  index.org                Home page
  about.org                About page
  posts/*.org              One file per post (index.org in here is generated)
  css/style.css            Site stylesheet (warm grey, one column; light and dark)
  js/site.js               Bottom dock: theme toggle, search, tag filter, reading progress
  search-index.json        Generated search index (git-ignored)
  images/                  Images, referenced from posts as ../images/name.png
public/                    Build output, including rss.xml (generated, git-ignored)
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
  Posts page) it holds the search box; on a long post it shows the section you're
  reading with a progress ring, and a search button opens the box in its place.
- **Search:** press Ctrl/Cmd+K anywhere, or click the box. It searches every post's
  title, tags, summary and full text, ignores accents (so `hus` finds `hús`), needs
  every word you type to match, and shows the best matches with the matching text
  highlighted. Arrow keys and Enter pick a result; Esc closes it. The build writes the
  index to `content/search-index.json` (git-ignored) and it is fetched the first time
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

## RSS feed

The build writes `public/rss.xml`, linked from the nav bar and from every page's
`<head>` so feed readers can find it. Each item has the post's title and date, its
`#+DESCRIPTION:` as the summary, and a link to the full post. (Posts without a
`#+DESCRIPTION:` get just the link.)

`ox-rss` turns each top-level headline of one Org file into a feed item, and posts
here are one file each. So before publishing, `blog-write-rss-source` in
`publish.el` writes a small generated `.cache/rss/rss.org` with one headline per
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
