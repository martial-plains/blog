#!/usr/bin/env python3
"""Check the built site (public/) for broken internal links, images and #anchors.

    python3 scripts/check-links.py [public-dir]

Set BLOG_BASE to the site's subfolder (as for the build) if it has one.  Only links inside
the site are checked: external http(s) links are skipped, so the check is quick, free and
never fails because someone else's site is down.  Exits 1 if anything is broken, which
stops the deploy workflow before a bad link goes live.
"""
import os
import sys
from html.parser import HTMLParser
from urllib.parse import unquote, urldefrag, urlsplit

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "public")
BASE = os.environ.get("BLOG_BASE", "").rstrip("/")
SKIP = ("http:", "https:", "mailto:", "tel:", "data:", "javascript:", "sms:", "//")


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.refs = set(), []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get("id"):
            self.ids.add(a["id"])
        if tag == "a" and a.get("name"):
            self.ids.add(a["name"])
        for key in ("href", "src"):
            if a.get(key) is not None and tag in ("a", "img", "link", "script", "source", "video", "audio"):
                # <link rel=alternate/canonical> point at absolute URLs, which are skipped below
                self.refs.append((tag, a[key]))


def parse(path):
    p = Page()
    with open(path, encoding="utf-8", errors="replace") as f:
        p.feed(f.read())
    return p


pages = {}
for dirpath, _, files in os.walk(ROOT):
    for name in files:
        if name.endswith(".html"):
            full = os.path.join(dirpath, name)
            pages[full] = parse(full)


def url_of(path):
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    if rel.endswith("index.html"):
        rel = rel[: -len("index.html")]
    return BASE + "/" + rel


def resolve(page_path, ref):
    """The file a link points at, or None."""
    parts = urlsplit(ref)
    target = unquote(parts.path)
    if not target:
        return page_path
    if target.startswith("/"):
        if BASE and not (target == BASE or target.startswith(BASE + "/")):
            return None
        target = target[len(BASE):]
        full = os.path.join(ROOT, target.lstrip("/"))
    else:
        full = os.path.normpath(os.path.join(os.path.dirname(page_path), target))
    for candidate in (full, os.path.join(full, "index.html")):
        if os.path.isfile(candidate):
            return candidate
    return None


errors = []
checked = 0
for path, page in sorted(pages.items()):
    where = os.path.relpath(path, ROOT)
    for tag, ref in page.refs:
        ref = ref.strip()
        if not ref or ref.lower().startswith(SKIP):
            continue
        checked += 1
        _, frag = urldefrag(ref)
        target = resolve(path, ref)
        if target is None:
            errors.append(f"{where}: <{tag}> points to {ref}, which does not exist")
            continue
        if frag and target.endswith(".html") and tag == "a":
            ids = pages[target].ids if target in pages else parse(target).ids
            if unquote(frag) not in ids and frag != "top":
                errors.append(f"{where}: link {ref} points to a section that does not exist")

if errors:
    print(f"{len(errors)} broken link(s) found ({checked} internal links checked):\n")
    print("\n".join("  " + e for e in errors))
    sys.exit(1)
print(f"Links OK: {checked} internal links checked in {len(pages)} pages.")
