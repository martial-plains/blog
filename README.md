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
  css/style.css            Site stylesheet (light and dark)
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
#+DESCRIPTION: One or two sentences, shown as the summary in the RSS feed.
#+LANGUAGE: en-GB

* First heading

Text...
```

The `#+DATE:` decides the order on the Posts page and in the feed (newest first).
Put images in `content/images/` and link them as `[[file:../images/name.png]]`.
Rebuild and the post appears on the Posts page and in the feed automatically.

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
