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

/* ---- PS2 OSDSYS Cursor Orbs Canvas ---- */
(function () {
  "use strict";
  if (window.__ps2OrbsLoaded) return;
  window.__ps2OrbsLoaded = true;

  function startOrbs() {
    var canvas = document.getElementById('ps2-orbs');
    if (!canvas) {
      canvas = document.createElement('canvas');
      canvas.id = 'ps2-orbs';
      canvas.className = 'ps2-orbs-canvas';
      canvas.setAttribute('aria-hidden', 'true');
      if (document.body) {
        document.body.appendChild(canvas);
      } else {
        document.addEventListener('DOMContentLoaded', function () {
          document.body.appendChild(canvas);
        });
      }
    }
    var ctx = canvas.getContext('2d');
    if (!ctx) return;

    var width = window.innerWidth;
    var height = window.innerHeight;
    var dpr = window.devicePixelRatio || 1;

    function resize() {
      dpr = window.devicePixelRatio || 1;
      width = window.innerWidth;
      height = window.innerHeight;
      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = width + 'px';
      canvas.style.height = height + 'px';
    }
    window.addEventListener('resize', resize);
    resize();

    var mouse = {
      x: width / 2,
      y: height / 2,
      targetX: width / 2,
      targetY: height / 2,
      speed: 0,
      hasMoved: false
    };

    function onPointerMove(x, y) {
      mouse.targetX = x;
      mouse.targetY = y;
      if (!mouse.hasMoved) {
        mouse.x = x;
        mouse.y = y;
        mouse.hasMoved = true;
      }
    }

    window.addEventListener('mousemove', function (e) {
      onPointerMove(e.clientX, e.clientY);
    });
    document.addEventListener('mousemove', function (e) {
      onPointerMove(e.clientX, e.clientY);
    });

    window.addEventListener('touchmove', function (e) {
      if (e.touches && e.touches.length > 0) {
        onPointerMove(e.touches[0].clientX, e.touches[0].clientY);
      }
    }, { passive: true });

    // 7 authentic PS2 OSDSYS orbs with visible sizing
    var ORBS = [
      { radius: 36, speed: 0.038, tiltX: 0.65, tiltY: 0.35, phase: 0.0, size: 4.8, hue: 'cyan' },
      { radius: 52, speed: -0.028, tiltX: -0.55, tiltY: 0.50, phase: 1.1, size: 4.2, hue: 'blue' },
      { radius: 26, speed: 0.046, tiltX: 0.40, tiltY: -0.70, phase: 2.3, size: 3.8, hue: 'cyan' },
      { radius: 64, speed: -0.022, tiltX: 0.75, tiltY: -0.30, phase: 3.5, size: 5.2, hue: 'ice' },
      { radius: 44, speed: 0.032, tiltX: -0.70, tiltY: -0.45, phase: 4.4, size: 4.0, hue: 'blue' },
      { radius: 74, speed: 0.020, tiltX: 0.30, tiltY: 0.80, phase: 5.2, size: 4.6, hue: 'cyan' },
      { radius: 58, speed: -0.030, tiltX: -0.45, tiltY: -0.60, phase: 5.9, size: 3.9, hue: 'ice' }
    ];

    var orbStates = [];
    for (var i = 0; i < ORBS.length; i++) {
      orbStates.push({
        cfg: ORBS[i],
        angle: ORBS[i].phase,
        history: []
      });
    }

    // Trailing stardust particles emitted as cursor sweeps
    var particles = [];
    var lastTime = performance.now();

    function tick(now) {
      var dt = Math.min((now - lastTime) / 1000, 0.05);
      lastTime = now;

      // Fluid spring cursor tracking
      var dx = mouse.targetX - mouse.x;
      var dy = mouse.targetY - mouse.y;
      mouse.x += dx * 0.16;
      mouse.y += dy * 0.16;
      mouse.speed = Math.sqrt(dx * dx + dy * dy);

      // Spawn subtle stardust trail when cursor moves
      if (mouse.speed > 1.5 && particles.length < 40) {
        particles.push({
          x: mouse.x + (Math.random() - 0.5) * 12,
          y: mouse.y + (Math.random() - 0.5) * 12,
          vx: (Math.random() - 0.5) * 0.8 - (dx * 0.03),
          vy: (Math.random() - 0.5) * 0.8 - (dy * 0.03),
          life: 1.0,
          decay: 0.03 + Math.random() * 0.03,
          size: 1.5 + Math.random() * 2.2,
          hue: Math.random() > 0.4 ? 'cyan' : 'blue'
        });
      }

      // Ambient floating wave when resting
      var idleWaveX = Math.sin(now * 0.001) * 6;
      var idleWaveY = Math.cos(now * 0.0013) * 5;

      var cx = mouse.x + idleWaveX;
      var cy = mouse.y + idleWaveY;

      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      // 1. Update and render stardust particles
      for (var p = particles.length - 1; p >= 0; p--) {
        var pt = particles[p];
        pt.x += pt.vx;
        pt.y += pt.vy;
        pt.life -= pt.decay;
        if (pt.life <= 0) {
          particles.splice(p, 1);
          continue;
        }
        var pAlpha = pt.life * 0.85;
        var pColor = pt.hue === 'cyan'
          ? 'rgba(56, 189, 248, ' + pAlpha + ')'
          : 'rgba(96, 165, 250, ' + pAlpha + ')';
        ctx.fillStyle = pColor;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, pt.size * pt.life, 0, Math.PI * 2);
        ctx.fill();
      }

      // 2. Calculate 3D positions for the 7 satellite orbs
      var renderedOrbs = [];
      for (var k = 0; k < orbStates.length; k++) {
        var o = orbStates[k];
        o.angle += o.cfg.speed * (dt * 60);

        var rad = o.cfg.radius;
        var ox = Math.cos(o.angle) * rad;
        var oy = Math.sin(o.angle) * rad;

        // 3D rotation by inclined orbital plane
        var x3 = ox * Math.cos(o.cfg.tiltY) - oy * Math.sin(o.cfg.tiltX) * Math.sin(o.cfg.tiltY);
        var y3 = oy * Math.cos(o.cfg.tiltX);
        var z3 = ox * Math.sin(o.cfg.tiltY) + oy * Math.sin(o.cfg.tiltX) * Math.cos(o.cfg.tiltY);

        // Depth projection: front is brighter & larger, rear is dimmer & smaller
        var depth = (z3 + 90) / 180;
        depth = Math.max(0.25, Math.min(1.0, depth));

        var screenX = cx + x3;
        var screenY = cy + y3;

        // Update trail history
        o.history.unshift({ x: screenX, y: screenY, depth: depth });
        if (o.history.length > 7) {
          o.history.pop();
        }

        renderedOrbs.push({
          orb: o,
          x: screenX,
          y: screenY,
          z: z3,
          depth: depth,
          size: o.cfg.size * (0.75 + 0.55 * depth),
          hue: o.cfg.hue
        });
      }

      // Sort rear to front for correct depth order
      renderedOrbs.sort(function (a, b) { return a.z - b.z; });

      // 3. Draw ethereal motion trails for orbs
      for (var t = 0; t < renderedOrbs.length; t++) {
        var item = renderedOrbs[t];
        var hist = item.orb.history;
        if (hist.length > 1) {
          for (var h = 1; h < hist.length; h++) {
            var p0 = hist[h - 1];
            var p1 = hist[h];
            var trailAlpha = (1 - h / hist.length) * 0.45 * p1.depth;
            var trailCol = item.hue === 'blue'
              ? 'rgba(96, 165, 250, ' + trailAlpha + ')'
              : (item.hue === 'ice' ? 'rgba(224, 242, 254, ' + trailAlpha + ')' : 'rgba(56, 189, 248, ' + trailAlpha + ')');
            ctx.strokeStyle = trailCol;
            ctx.lineWidth = Math.max(0.9, item.size * 0.6 * (1 - h / hist.length));
            ctx.beginPath();
            ctx.moveTo(p0.x, p0.y);
            ctx.lineTo(p1.x, p1.y);
            ctx.stroke();
          }
        }
      }

      // 4. Draw glowing orb bodies
      for (var i = 0; i < renderedOrbs.length; i++) {
        var ro = renderedOrbs[i];
        var glowRadius = ro.size * 5.0;

        // Outer soft ambient glow
        var grad = ctx.createRadialGradient(ro.x, ro.y, 0, ro.x, ro.y, glowRadius);

        var colorCore = 'rgba(255, 255, 255, ' + (0.98 * ro.depth) + ')';
        var colorInner, colorOuter;

        if (ro.hue === 'blue') {
          colorInner = 'rgba(96, 165, 250, ' + (0.75 * ro.depth) + ')';
          colorOuter = 'rgba(30, 64, 175, 0)';
        } else if (ro.hue === 'ice') {
          colorInner = 'rgba(186, 230, 253, ' + (0.85 * ro.depth) + ')';
          colorOuter = 'rgba(56, 189, 248, 0)';
        } else { // cyan
          colorInner = 'rgba(56, 189, 248, ' + (0.85 * ro.depth) + ')';
          colorOuter = 'rgba(14, 116, 144, 0)';
        }

        grad.addColorStop(0, colorCore);
        grad.addColorStop(0.3, colorInner);
        grad.addColorStop(1, colorOuter);

        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(ro.x, ro.y, glowRadius, 0, Math.PI * 2);
        ctx.fill();

        // Sharp intense center core
        ctx.fillStyle = colorCore;
        ctx.beginPath();
        ctx.arc(ro.x, ro.y, Math.max(1.5, ro.size * 0.45), 0, Math.PI * 2);
        ctx.fill();
      }

      // 5. Connect close orbs with subtle ethereal energy filaments
      for (var a = 0; a < renderedOrbs.length; a++) {
        for (var b = a + 1; b < renderedOrbs.length; b++) {
          var oA = renderedOrbs[a];
          var oB = renderedOrbs[b];
          var distSq = (oA.x - oB.x) * (oA.x - oB.x) + (oA.y - oB.y) * (oA.y - oB.y);
          var maxDist = 55;
          if (distSq < maxDist * maxDist) {
            var dist = Math.sqrt(distSq);
            var filamentAlpha = (1 - dist / maxDist) * 0.28 * Math.min(oA.depth, oB.depth);
            ctx.strokeStyle = 'rgba(56, 189, 248, ' + filamentAlpha + ')';
            ctx.lineWidth = 1.0;
            ctx.beginPath();
            ctx.moveTo(oA.x, oA.y);
            ctx.lineTo(oB.x, oB.y);
            ctx.stroke();
          }
        }
      }

      requestAnimationFrame(tick);
    }

    requestAnimationFrame(tick);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startOrbs);
  } else {
    startOrbs();
  }
})();
