EMACS ?= emacs
PORT  ?= 8000

.PHONY: all build clean serve check

all: build

# Build the site into public/ (set BLOG_ORIGIN / BLOG_BASE for a real deploy).
build:
	$(EMACS) --batch -l publish.el -f blog-publish

# Remove the build output, Org's publish cache and the generated Posts pages.
clean:
	rm -rf public .cache
	rm -f content/posts/index.org content/posts/index.*.org

# Preview the built site at http://localhost:$(PORT)
serve: build
	python3 -m http.server -d public $(PORT)

# Check internal links in the built site.
check: build
	python3 scripts/check-links.py public
