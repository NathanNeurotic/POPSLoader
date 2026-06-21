/* POPStarter Docs — self-contained search + nav. No dependencies. */
(function () {
  "use strict";
  var INDEX = [], ready = false;
  var q = document.getElementById('q');
  var box = document.getElementById('results');
  var sel = -1, current = [];
  var BASE = (document.body.getAttribute('data-base') || '');

  function load() {
    fetch(BASE + 'data/search-index.json')
      .then(function (r) { return r.json(); })
      .then(function (j) { INDEX = j; ready = true; if (q && q.value) run(q.value); })
      .catch(function () {});
  }

  function esc(s) { return s.replace(/[&<>"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]; }); }

  function score(item, terms) {
    var hay = item._h || (item._h = (item.title + ' ' + (item.cat || '') + ' ' + (item.text || '')).toLowerCase());
    var s = 0;
    for (var i = 0; i < terms.length; i++) {
      var t = terms[i]; if (!t) continue;
      var ti = item.title.toLowerCase();
      if (ti === t) s += 100;
      else if (ti.indexOf(t) === 0) s += 40;
      else if (ti.indexOf(t) >= 0) s += 22;
      var n = hay.indexOf(t);
      if (n < 0) return -1;
      s += 8 + Math.max(0, 12 - n / 40);
    }
    if (item.cat === 'cheats' || item.cat === 'config' || item.cat === 'patches' || item.cat === 'igr') s += 4;
    if (item.url && item.url.indexOf('#') >= 0) s += 5;   // anchored card entries rank above full pages
    return s;
  }

  function snippet(item, terms) {
    var txt = item.text || item.desc || '';
    if (!txt) return '';
    var low = txt.toLowerCase(), at = -1;
    for (var i = 0; i < terms.length; i++) { var p = low.indexOf(terms[i]); if (p >= 0) { at = p; break; } }
    var start = at < 0 ? 0 : Math.max(0, at - 38);
    var frag = txt.slice(start, start + 150);
    if (start > 0) frag = '…' + frag;
    frag = esc(frag);
    for (var j = 0; j < terms.length; j++) {
      if (!terms[j]) continue;
      frag = frag.replace(new RegExp('(' + terms[j].replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'), '<mark>$1</mark>');
    }
    return frag;
  }

  function run(val) {
    var terms = val.toLowerCase().trim().split(/\s+/).filter(Boolean);
    if (!terms.length) { box.classList.remove('open'); box.innerHTML = ''; return; }
    if (!ready) { box.innerHTML = '<div class="res-empty">loading index…</div>'; box.classList.add('open'); return; }
    var hits = [];
    for (var i = 0; i < INDEX.length; i++) { var sc = score(INDEX[i], terms); if (sc > 0) hits.push([sc, INDEX[i]]); }
    hits.sort(function (a, b) { return b[0] - a[0]; });
    current = hits.slice(0, 30).map(function (h) { return h[1]; });
    sel = -1;
    if (!current.length) { box.innerHTML = '<div class="res-empty">No matches for “' + esc(val) + '”.</div>'; box.classList.add('open'); return; }
    box.innerHTML = current.map(function (it, i) {
      return '<a class="res" data-i="' + i + '" href="' + BASE + it.url + '">' +
        '<span class="t">' + esc(it.title) + '</span><span class="c">' + esc(it.cat || '') + '</span>' +
        '<div class="s">' + snippet(it, terms) + '</div></a>';
    }).join('');
    box.classList.add('open');
  }

  function move(d) {
    var els = box.querySelectorAll('.res'); if (!els.length) return;
    sel = (sel + d + els.length) % els.length;
    for (var i = 0; i < els.length; i++) els[i].classList.toggle('sel', i === sel);
    els[sel].scrollIntoView({ block: 'nearest' });
  }

  if (q) {
    q.addEventListener('input', function () { run(q.value); });
    q.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
      else if (e.key === 'Enter') { var el = box.querySelector('.res.sel') || box.querySelector('.res'); if (el) location.href = el.href; }
      else if (e.key === 'Escape') { box.classList.remove('open'); q.blur(); }
    });
    document.addEventListener('click', function (e) { if (!e.target.closest('.search')) box.classList.remove('open'); });
    document.addEventListener('keydown', function (e) {
      if (e.key === '/' && document.activeElement !== q) { e.preventDefault(); q.focus(); }
    });
    load();
  }

  var mb = document.querySelector('.menu-btn'), sb = document.querySelector('.sidebar');
  if (mb && sb) mb.addEventListener('click', function () { sb.classList.toggle('open'); });

  document.querySelectorAll('table[data-sortable] th').forEach(function (th, ci) {
    th.style.cursor = 'pointer'; th.title = 'Sort';
    th.addEventListener('click', function () {
      var tb = th.closest('table'), rows = Array.prototype.slice.call(tb.tBodies[0].rows);
      var asc = tb.getAttribute('data-asc') !== ('' + ci); tb.setAttribute('data-asc', asc ? ci : '-' + ci);
      rows.sort(function (a, b) {
        var x = a.cells[ci].textContent.trim(), y = b.cells[ci].textContent.trim();
        var nx = parseInt(x.replace(/^[$0x]+/i, ''), 16), ny = parseInt(y.replace(/^[$0x]+/i, ''), 16);
        if (!isNaN(nx) && !isNaN(ny)) return asc ? nx - ny : ny - nx;
        return asc ? x.localeCompare(y) : y.localeCompare(x);
      });
      rows.forEach(function (r) { tb.tBodies[0].appendChild(r); });
    });
  });
})();

/* right-rail "On this page" table of contents + scroll-spy */
(function () {
  "use strict";
  var nav = document.getElementById('toc-nav');
  var aside = document.querySelector('.toc');
  if (!nav || !aside) return;
  var heads = Array.prototype.slice.call(document.querySelectorAll('.content h2, .content h3'))
    .filter(function (h) { return !h.closest('.card') && !h.closest('.step') && !h.closest('details'); });
  if (heads.length < 2) { aside.classList.add('hide'); return; }
  var used = {}, links = [], byId = {};
  heads.forEach(function (h) {
    var id = h.id;
    if (!id) {
      id = (h.textContent || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48) || 'sec';
      while (used[id]) id += '-x';
      h.id = id;
    }
    used[id] = 1;
    var a = document.createElement('a');
    a.href = '#' + id; a.textContent = h.textContent;
    a.className = h.tagName === 'H3' ? 'lv3' : 'lv2';
    nav.appendChild(a); links.push(a); byId[id] = a;
  });
  if ('IntersectionObserver' in window) {
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          links.forEach(function (a) { a.classList.remove('active'); });
          if (byId[e.target.id]) byId[e.target.id].classList.add('active');
        }
      });
    }, { rootMargin: '-72px 0px -68% 0px' });
    heads.forEach(function (h) { obs.observe(h); });
  }
})();
