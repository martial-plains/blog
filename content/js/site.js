/* Dock behaviour: theme toggle, language menu, search palette, tag filter, table of contents, reading progress. */
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
  if (dock) dock.classList.toggle('reading', !!reading);

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
      dock.style.transition = ''; dock.style.overflow = '';   // don't leave a cancelled morph's clipping behind
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

  /* ---------- search palette ---------- */
  // The Search button (or Ctrl/Cmd+K) opens a centred palette: pages, matching posts and a
  // theme switch in one list.  Posts are searched in the browser from search-index.json.
  var openBtn = $('#search-open');
  var index = null, loading = null;
  // Lower-case, drop accents, and fold Icelandic letters one-for-one so offsets stay aligned.
  var fold = function (s) {
    return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
            .replace(/ð/g, 'd').replace(/þ/g, 't').replace(/æ/g, 'a');
  };
  var load = function () {
    if (index) return Promise.resolve(index);
    if (loading) return loading;
    loading = fetch(openBtn.getAttribute('data-index'))
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
    return (from > 0 ? '…' : '') + post.text.slice(from, to) + (to < post.text.length ? '…' : '');
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

  var ICONS = {
    home: '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',
    about: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    posts: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    privacy: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
    terms: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M8 13h8M8 17h5"/>',
    post: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/>',
    theme: '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>'
  };
  var svg = function (name) {
    return '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" ' +
           'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICONS[name] + '</svg>';
  };

  var pages = [];
  try { pages = JSON.parse(attr('data-pages', '[]')); } catch (e) {}
  var pageIcons = ['home', 'about', 'posts', 'privacy', 'terms'];

  var overlay = null, field, listEl, hlEl, rows = [], active = 0, returnFocus = null;

  var matches = function (text, terms) {
    var f = fold(text);
    return terms.every(function (t) { return f.indexOf(t) > -1; });
  };

  // What to show for the current text: pages, then posts, then the theme switch.
  var gather = function (query) {
    var terms = fold(query).split(/\s+/).filter(Boolean), out = [];
    pages.forEach(function (p, i) {
      if (matches(p.label, terms)) out.push({ group: attr('data-pages-label', 'Pages'), icon: pageIcons[i] || 'post', label: p.label, href: p.url, terms: terms });
    });
    var posts = [];
    if (!terms.length) {
      posts = (index || []).slice(0, 5).map(function (p) { return { post: p, score: 0 }; });
    } else {
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
        posts.push({ post: p, score: score });
      });
      posts.sort(function (a, b) { return b.score - a.score; });
      posts = posts.slice(0, 6);
    }
    posts.forEach(function (r) {
      out.push({ group: attr('data-posts-label', 'Posts'), icon: 'post', label: r.post.title, hint: terms.length ? '' : r.post.date,
                 snip: terms.length ? snippet(r.post, terms) : '', href: r.post.url, terms: terms });
    });
    var themeLabel = attr('data-theme-label', 'Toggle theme');
    if (matches(themeLabel, terms)) out.push({ group: '⚙', icon: 'theme', label: themeLabel, run: function () { var b = $('#theme-toggle'); if (b) b.click(); }, terms: terms });
    return out;
  };

  var setActive = function (n, instant) {
    if (!rows.length) return;
    active = (n + rows.length) % rows.length;
    rows.forEach(function (r, i) { r.li.setAttribute('aria-selected', i === active ? 'true' : 'false'); });
    var el = rows[active].li;
    field.setAttribute('aria-activedescendant', el.id);
    if (instant) { hlEl.style.transition = 'none'; }
    hlEl.style.height = el.offsetHeight + 'px';
    hlEl.style.transform = 'translateY(' + el.offsetTop + 'px)';
    hlEl.style.opacity = '1';
    if (instant) { void hlEl.offsetWidth; hlEl.style.transition = ''; }
    el.scrollIntoView({ block: 'nearest' });
  };

  var render = function () {
    var q = field.value, items = gather(q);
    listEl.textContent = '';
    hlEl = doc.createElement('div'); hlEl.className = 'cmd-hl'; hlEl.setAttribute('aria-hidden', 'true');
    listEl.appendChild(hlEl);
    rows = [];
    var last = null;
    items.forEach(function (it, i) {
      if (it.group !== last) {
        var h = doc.createElement('li'); h.setAttribute('role', 'presentation');
        h.className = it.group ? 'cmd-group' : 'cmd-gap';
        h.textContent = it.group;
        listEl.appendChild(h); last = it.group;
      }
      var li = doc.createElement('li'); li.id = 'cmd-' + i; li.setAttribute('role', 'option');
      var row = doc.createElement(it.href ? 'a' : 'button');
      row.className = 'cmd-row';
      if (it.href) row.href = it.href; else row.type = 'button';
      row.tabIndex = -1;
      var main = doc.createElement('span'); main.className = 'cmd-main';
      var ic = doc.createElement('span'); ic.className = 'cmd-ic'; ic.innerHTML = svg(it.icon);
      var txt = doc.createElement('span'); txt.className = 'cmd-txt';
      var t = doc.createElement('span'); t.className = 'cmd-title'; mark(t, it.label, it.terms);
      txt.appendChild(t);
      if (it.snip) { var sn = doc.createElement('span'); sn.className = 'cmd-snip'; mark(sn, it.snip, it.terms); txt.appendChild(sn); }
      main.appendChild(ic); main.appendChild(txt); row.appendChild(main);
      if (it.hint) { var hn = doc.createElement('span'); hn.className = 'cmd-hint'; hn.textContent = it.hint; row.appendChild(hn); }
      li.appendChild(row); listEl.appendChild(li);
      row.addEventListener('click', function (e) {
        if (it.run) { e.preventDefault(); close(true); it.run(); }
      });
      li.addEventListener('mousemove', function () { if (active !== i) setActive(i); });
      rows.push({ li: li, row: row, item: it });
    });
    if (!rows.length) {
      var none = doc.createElement('li'); none.className = 'cmd-none'; none.setAttribute('role', 'presentation');
      none.textContent = index || !q.trim()
        ? attr('data-no-match', 'No posts match “%s”.').replace('%s', q.trim())
        : attr('data-unavailable', 'Search is unavailable right now.');
      listEl.appendChild(none);
      hlEl.style.opacity = '0';
      field.removeAttribute('aria-activedescendant');
      return;
    }
    setActive(0, true);
  };

  var open = function () {
    if (overlay) return;
    if (tocOpen) setToc(false);
    returnFocus = doc.activeElement;
    overlay = doc.createElement('div'); overlay.className = 'cmd';
    var placeholder = attr('data-search', 'Search');
    overlay.innerHTML =
      '<div class="cmd-box" role="dialog" aria-modal="true">' +
      '<div class="cmd-field">' + svg('search') + '<input type="text" autocomplete="off" autocapitalize="off" spellcheck="false" ' +
      'role="combobox" aria-expanded="true" aria-controls="cmd-list"></div>' +
      '<ul id="cmd-list" class="cmd-list" role="listbox"></ul>' +
      '<div class="cmd-foot"><span></span><span></span></div></div>';
    var box = $('.cmd-box', overlay);
    box.setAttribute('aria-label', placeholder);
    field = $('input', overlay);
    field.placeholder = placeholder; field.setAttribute('aria-label', placeholder);
    listEl = $('.cmd-list', overlay);
    var foot = $$('.cmd-foot span', overlay);
    foot[0].textContent = attr('data-hint-move', '↑↓ to move, ↵ to open');
    foot[1].textContent = attr('data-hint-close', 'Esc to close');
    overlay.addEventListener('mousedown', function (e) { if (e.target === overlay) close(); });
    field.addEventListener('input', render);
    field.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); setActive(active + 1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active - 1); }
      else if (e.key === 'Enter' && rows[active] && !e.isComposing) { e.preventDefault(); rows[active].row.click(); }
      else if (e.key === 'Tab') e.preventDefault();       // keep focus in the box
    });
    doc.body.appendChild(overlay);
    openBtn.setAttribute('aria-expanded', 'true');
    render();
    field.focus();
    load().then(function () { if (overlay) render(); });   // posts appear as soon as the index arrives
  };
  var close = function (keepFocus) {
    if (!overlay) return;
    var el = overlay; overlay = null;
    openBtn.setAttribute('aria-expanded', 'false');
    el.classList.add('is-closing');
    setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 160);
    if (!keepFocus && returnFocus && returnFocus.focus) returnFocus.focus();
  };

  if (openBtn) {
    openBtn.addEventListener('click', open);
    doc.addEventListener('keydown', function (e) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); if (overlay) close(); else open(); }
      else if (e.key === 'Escape' && overlay) { e.preventDefault(); close(); }
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
