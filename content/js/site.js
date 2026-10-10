/* Dock behaviour: theme toggle, language menu, site search, tag filter, table of contents, reading progress. */
(function () {
  var doc = document, root = doc.documentElement;
  var $ = function (sel, ctx) { return (ctx || doc).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || doc).querySelectorAll(sel)); };

  /* ---------- theme ---------- */
  var toggle = $('#theme-toggle');
  if (toggle) toggle.addEventListener('click', function () {
    var dark = root.dataset.theme
      ? root.dataset.theme === 'dark'
      : matchMedia('(prefers-color-scheme: dark)').matches;
    var next = dark ? 'light' : 'dark';
    root.dataset.theme = next;
    try { localStorage.setItem('theme', next); } catch (e) {}
    syncComments();
  });

  // Giscus comments (if the site has them) follow the site's light/dark choice, not just the system's.
  function syncComments() {
    var frame = doc.querySelector('iframe.giscus-frame');
    if (!frame || !frame.contentWindow) return;
    var dark = root.dataset.theme ? root.dataset.theme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
    frame.contentWindow.postMessage({ giscus: { setConfig: { theme: dark ? 'dark' : 'light' } } }, 'https://giscus.app');
  }
  addEventListener('message', function (e) {
    if (e.origin === 'https://giscus.app' && e.data && e.data.giscus) syncComments();
  });

  /* ---------- copying: code blocks and heading links ---------- */
  var navEl = $('.dock');
  var attr = function (name, fallback) { return (navEl && navEl.getAttribute(name)) || fallback; };
  var copyText = attr('data-copy', 'Copy'), copiedText = attr('data-copied', 'Copied');
  var copyToClipboard = function (text, done) {
    var fallback = function () {
      var ta = doc.createElement('textarea');
      ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
      doc.body.appendChild(ta); ta.select();
      try { doc.execCommand('copy'); done(); } catch (e) {}
      doc.body.removeChild(ta);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback);
    else fallback();
  };

  $$('#content pre.src').forEach(function (pre) {
    var box = pre.parentNode;
    if (!box.classList.contains('org-src-container')) {   // make sure the button has something to sit in
      box = doc.createElement('div'); box.className = 'org-src-container';
      pre.parentNode.insertBefore(box, pre); box.appendChild(pre);
    }
    var btn = doc.createElement('button');
    btn.type = 'button'; btn.className = 'copy-btn'; btn.textContent = copyText;
    btn.addEventListener('click', function () {
      copyToClipboard(pre.textContent.replace(/\n$/, ''), function () {
        btn.textContent = copiedText; btn.classList.add('is-done');
        setTimeout(function () { btn.textContent = copyText; btn.classList.remove('is-done'); }, 1600);
      });
    });
    box.appendChild(btn);
  });

  // A "#" after each heading copies a link straight to that section.  It is an empty
  // link drawn with CSS, so the heading's own text (used by the contents list) stays clean.
  var anchorLabel = attr('data-anchor', 'Copy link to this section');
  $$('#content h2[id], #content h3[id], #content h4[id], #content h5[id], #content h6[id]').forEach(function (h) {
    if (h.classList.contains('footnotes')) return;
    var a = doc.createElement('a');
    a.className = 'anchor'; a.href = '#' + h.id;
    a.setAttribute('aria-label', anchorLabel); a.title = anchorLabel;
    a.addEventListener('click', function (e) {
      e.preventDefault();
      try { history.replaceState(null, '', '#' + h.id); } catch (err) {}
      copyToClipboard(location.href.split('#')[0] + '#' + h.id, function () {
        a.classList.add('is-done');
        setTimeout(function () { a.classList.remove('is-done'); }, 1600);
      });
    });
    h.appendChild(a);
  });

  /* ---------- posts index: tag pills ---------- */
  var list = $('.post-list');
  if (list) {
    var rows = $$('li', list), empty = $('.empty'), pills = $$('.pill');
    pills.forEach(function (pill) {
      pill.addEventListener('click', function () {
        var tag = pill.getAttribute('data-tag') || '', shown = 0;
        pills.forEach(function (p) { p.classList.toggle('is-active', p === pill); });
        rows.forEach(function (li) {
          var tags = (li.getAttribute('data-tags') || '').split(' ');
          li.hidden = !!tag && tags.indexOf(tag) < 0;
          if (!li.hidden) shown++;
        });
        if (empty) empty.hidden = shown > 0;
      });
    });
  }

  /* ---------- dock layout ---------- */
  var dock = $('.dock');
  var heads = $$('#content h2, #content h3');
  var label = $('#dock-label'), bar = $('.ring .bar');
  var reading = !list && heads.length > 0 && label && bar;   // long page: show the section name
  if (dock) {
    dock.classList.toggle('reading', !!reading);
    dock.classList.toggle('searching', !reading);              // short pages: search box is always open
  }

  // Run fn (which changes the dock's contents or classes) and animate the dock from its
  // old width to its new one, so it grows and shrinks instead of jumping.
  var morph = function (fn) {
    if (!dock) { fn(); return; }
    var from = dock.getBoundingClientRect().width;
    if (dock._onEnd) dock.removeEventListener('transitionend', dock._onEnd);
    dock.style.transition = 'none';
    dock.style.width = '';
    fn();
    var to = dock.getBoundingClientRect().width;
    if (Math.abs(from - to) < 1 || matchMedia('(prefers-reduced-motion: reduce)').matches) {
      dock.style.transition = '';
      return;
    }
    dock.style.width = from + 'px';
    dock.style.overflow = 'hidden';            // keep content inside while the width is mid-animation
    void dock.offsetWidth;                     // commit the starting width
    dock.style.transition = '';
    dock.style.width = to + 'px';
    var done = function () {
      clearTimeout(dock._morphTimer);
      dock.removeEventListener('transitionend', onEnd);
      dock.style.width = ''; dock.style.overflow = '';
    };
    var onEnd = function (e) { if (e.target === dock && e.propertyName === 'width') done(); };
    dock._onEnd = onEnd;
    dock.addEventListener('transitionend', onEnd);
    clearTimeout(dock._morphTimer);
    dock._morphTimer = setTimeout(done, 700);  // safety net if no transition event arrives
  };

  /* ---------- table of contents ---------- */
  var toggleBtn = $('#toc-toggle'), panel = $('#toc-panel'), tocList = $('#toc-list');
  var tocItems = [];
  var tocOpen = false;
  var setToc = function (open) {
    if (!dock || !panel || open === tocOpen) return;
    tocOpen = open;
    morph(function () {
      dock.classList.toggle('toc-open', open);
      panel.inert = !open;
      toggleBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    if (open) revealActive();
  };
  var revealActive = function () {
    var cur = tocItems.filter(function (t) { return t.li.classList.contains('is-active'); })[0];
    if (cur) cur.li.scrollIntoView({ block: 'nearest' });
  };
  if (reading && tocList && toggleBtn) {
    heads.forEach(function (h) {
      var li = doc.createElement('li'), b = doc.createElement('button');
      li.className = h.tagName === 'H3' ? 'l3' : 'l2';
      b.type = 'button'; b.textContent = h.textContent.trim();
      b.addEventListener('click', function () {
        h.scrollIntoView({ behavior: 'smooth', block: 'start' });
        setToc(false);
      });
      li.appendChild(b); tocList.appendChild(li);
      tocItems.push({ head: h, li: li });
    });
    toggleBtn.addEventListener('click', function () { setToc(!tocOpen); });
    doc.addEventListener('click', function (e) { if (tocOpen && !dock.contains(e.target)) setToc(false); });
    doc.addEventListener('keydown', function (e) { if (e.key === 'Escape' && tocOpen) { setToc(false); toggleBtn.focus(); } });
  }

  /* ---------- language menu ---------- */
  // The dropdown only exists on pages that are available in more than one language.
  // Choosing a language is remembered, and from then on the site opens in it.
  var langBtn = $('#lang-toggle'), langMenu = $('#lang-menu');
  if (langBtn && langMenu) {
    var showLang = function (open) {
      langMenu.hidden = !open;
      langBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    };
    langBtn.addEventListener('click', function () {
      var open = langMenu.hidden;
      if (open && tocOpen) setToc(false);
      showLang(open);
    });
    $$('a', langMenu).forEach(function (a) {
      a.addEventListener('click', function () {
        try { localStorage.setItem('lang', a.getAttribute('data-lang')); } catch (e) {}
      });
    });
    doc.addEventListener('click', function (e) {
      if (!langMenu.hidden && !langMenu.contains(e.target) && !langBtn.contains(e.target)) showLang(false);
    });
    doc.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !langMenu.hidden) { showLang(false); langBtn.focus(); }
    });
  }

  /* ---------- search ---------- */
  var input = $('#dock-search'), results = $('#search-results'), openBtn = $('#search-open');
  var kbd = $('.dock-search kbd');
  if (kbd && /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent)) kbd.textContent = '\u2318 K';

  var index = null, loading = null, active = -1, shown = [];
  // Lower-case, drop accents, and fold Icelandic letters one-for-one so offsets stay aligned.
  var fold = function (s) {
    return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
            .replace(/\u00f0/g, 'd').replace(/\u00fe/g, 't').replace(/\u00e6/g, 'a');
  };
  var load = function () {
    if (index) return Promise.resolve(index);
    if (loading) return loading;
    loading = fetch(input.getAttribute('data-index'))
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) {
        index = data.map(function (p) {
          p._title = fold(p.title); p._tags = fold(p.tags.join(' '));
          p._desc = fold(p.description || ''); p._text = fold(p.text || '');
          return p;
        });
        return index;
      })
      .catch(function () { loading = null; return null; });
    return loading;
  };

  var snippet = function (post, terms) {
    var at = -1, i;
    for (i = 0; i < terms.length && at < 0; i++) at = post._text.indexOf(terms[i]);
    if (at < 0) return (post.description || '').slice(0, 140);
    var from = Math.max(0, at - 50), to = Math.min(post.text.length, at + 90);
    return (from > 0 ? '\u2026' : '') + post.text.slice(from, to) + (to < post.text.length ? '\u2026' : '');
  };
  var mark = function (el, text, terms) {
    var f = fold(text), spans = [];
    terms.forEach(function (t) {
      for (var at = f.indexOf(t); at > -1; at = f.indexOf(t, at + t.length)) spans.push([at, at + t.length]);
    });
    spans.sort(function (a, b) { return a[0] - b[0]; });
    var pos = 0;
    spans.forEach(function (sp) {
      if (sp[0] < pos) return;
      el.appendChild(doc.createTextNode(text.slice(pos, sp[0])));
      var m = doc.createElement('mark'); m.textContent = text.slice(sp[0], sp[1]); el.appendChild(m);
      pos = sp[1];
    });
    el.appendChild(doc.createTextNode(text.slice(pos)));
  };

  var closeResults = function () { results.hidden = true; active = -1; input.removeAttribute('aria-activedescendant'); };
  var setActive = function (n) {
    var items = $$('li', results);
    if (!items.length) return;
    active = (n + items.length) % items.length;
    items.forEach(function (li, i) { li.classList.toggle('is-active', i === active); });
    items[active].scrollIntoView({ block: 'nearest' });
  };
  var render = function (query) {
    results.textContent = '';
    var terms = fold(query).split(/\s+/).filter(Boolean);
    if (!terms.length) { closeResults(); return; }
    shown = [];
    (index || []).forEach(function (p) {
      var score = 0;
      for (var i = 0; i < terms.length; i++) {
        var t = terms[i], s = 0;
        if (p._title.indexOf(t) > -1) s += 10;
        if (p._tags.indexOf(t) > -1) s += 5;
        if (p._desc.indexOf(t) > -1) s += 3;
        if (p._text.indexOf(t) > -1) s += 1;
        if (!s) return;                       // every word must match somewhere
        score += s;
      }
      shown.push({ post: p, score: score });
    });
    shown.sort(function (a, b) { return b.score - a.score; });
    if (!shown.length) {
      var none = doc.createElement('li'); none.className = 'none';
      none.textContent = index
        ? (dock.getAttribute('data-no-match') || 'No posts match \u201c%s\u201d.').replace('%s', query)
        : (dock.getAttribute('data-unavailable') || 'Search is unavailable right now.');
      results.appendChild(none);
    }
    shown.slice(0, 6).forEach(function (r) {
      var li = doc.createElement('li'), a = doc.createElement('a');
      a.href = r.post.url; li.setAttribute('role', 'option');
      var t = doc.createElement('span'); t.className = 'r-title'; mark(t, r.post.title, terms);
      var d = doc.createElement('span'); d.className = 'r-snip'; mark(d, snippet(r.post, terms), terms);
      a.appendChild(t); a.appendChild(d); li.appendChild(a); results.appendChild(li);
    });
    results.hidden = false; active = -1;
  };

  var openSearch = function () {
    if (!input) return;
    if (dock && !dock.classList.contains('searching')) {
      morph(function () {
        if (tocOpen) { tocOpen = false; dock.classList.remove('toc-open'); if (panel) panel.inert = true; if (toggleBtn) toggleBtn.setAttribute('aria-expanded', 'false'); }
        dock.classList.add('searching');
      });
    }
    input.focus(); input.select();
    load();
  };
  var closeSearch = function () {
    input.value = ''; closeResults(); input.blur();
    if (dock && reading) morph(function () { dock.classList.remove('searching'); });
  };

  if (input && results) {
    input.addEventListener('focus', load);
    input.addEventListener('input', function () {
      var q = input.value;
      load().then(function () { if (input.value === q) render(q); });
    });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); setActive(active + 1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active - 1); }
      else if (e.key === 'Enter') {
        var link = $$('li a', results)[Math.max(active, 0)];
        if (link) { e.preventDefault(); location.href = link.href; }
      }
    });
    input.addEventListener('blur', function () {
      // Wait a moment so a click on a result still registers.
      setTimeout(function () {
        if (doc.activeElement === input) return;
        closeResults();
        if (reading && dock && !input.value && dock.classList.contains('searching')) morph(function () { dock.classList.remove('searching'); });
      }, 150);
    });
    if (openBtn) openBtn.addEventListener('click', openSearch);
    doc.addEventListener('keydown', function (e) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openSearch(); }
      else if (e.key === 'Escape' && doc.activeElement === input) closeSearch();
    });
  }

  /* ---------- long pages: current section name + reading progress ring ---------- */
  if (reading) {
    var title = ($('h1.title') || {}).textContent || doc.title;
    var ticking = false, lastIdx = -2;
    var update = function () {
      ticking = false;
      var max = doc.documentElement.scrollHeight - innerHeight;
      var p = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 1;
      bar.style.strokeDashoffset = String(1 - p);

      var idx = -1;
      heads.forEach(function (h, i) { if (h.getBoundingClientRect().top <= innerHeight * 0.35) idx = i; });
      if (idx === lastIdx) return;
      var first = lastIdx === -2;
      lastIdx = idx;
      var text = idx > -1 ? heads[idx].textContent.trim() : title.trim();
      tocItems.forEach(function (t, i) { t.li.classList.toggle('is-active', i === idx); });
      if (tocOpen) revealActive();
      if (label.textContent === text) return;
      if (first) { label.textContent = text; return; }
      // The new name is a different length, so the dock grows or shrinks to fit it.
      morph(function () { label.textContent = text; });
      if (label.animate && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
        label.animate([{ opacity: 0, transform: 'translateY(5px)' }, { opacity: 1, transform: 'none' }],
                      { duration: 280, easing: 'cubic-bezier(.2,.8,.2,1)' });
      }
    };
    addEventListener('scroll', function () { if (!ticking) { ticking = true; requestAnimationFrame(update); } }, { passive: true });
    addEventListener('resize', update);
    update();
  }
})();
