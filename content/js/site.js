/* Dock behaviour: theme toggle, site search, tag filter, reading progress. */
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
  var heads = $$('#content h2');
  var label = $('#dock-label'), bar = $('.ring .bar');
  var reading = !list && heads.length > 0 && label && bar;   // long page: show the section name
  if (dock) {
    dock.classList.toggle('reading', !!reading);
    dock.classList.toggle('searching', !reading);              // short pages: search box is always open
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
      none.textContent = index ? 'No posts match \u201c' + query + '\u201d.' : 'Search is unavailable right now.';
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
    if (dock) dock.classList.add('searching');
    input.focus(); input.select();
    load();
  };
  var closeSearch = function () {
    input.value = ''; closeResults(); input.blur();
    if (dock && reading) dock.classList.remove('searching');
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
        if (reading && dock && !input.value) dock.classList.remove('searching');
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
    var ticking = false;
    var update = function () {
      ticking = false;
      var max = doc.documentElement.scrollHeight - innerHeight;
      var p = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 1;
      bar.style.strokeDashoffset = String(1 - p);
      var current = title;
      heads.forEach(function (h) { if (h.getBoundingClientRect().top <= innerHeight * 0.35) current = h.textContent; });
      if (label.textContent !== current) label.textContent = current;
    };
    addEventListener('scroll', function () { if (!ticking) { ticking = true; requestAnimationFrame(update); } }, { passive: true });
    addEventListener('resize', update);
    update();
  }
})();
