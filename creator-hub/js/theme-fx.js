/* CordX — character-interface cursor effects.
   One transparent overlay canvas, drawn only while something is animating (the loop stops when idle).
     laser   (Optic)   red beam trail while you move; a visor beam + impact flash on click / Generate
     streak  (Speed)   white speed lines behind the cursor; sonic ring on click
     slash   (Claw)    steel sparks while you move; three claw slashes on click
     sparkle (Wraith)  twinkling four-point stars
   Mouse movement effects run in "full" mode only. Clicks/taps work in "lite" too. "off" disables everything. */
(function () {
  'use strict';
  var CH = window.CH, CORDX = window.CORDX, root = document.documentElement, clamp = CH.clamp;
  var cv = document.createElement('canvas'); cv.id = 'fx-top'; cv.setAttribute('aria-hidden', 'true');
  cv.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;z-index:95;pointer-events:none';
  document.body.appendChild(cv);
  var ctx = cv.getContext('2d'), W = 0, H = 0, objs = [], raf = 0, mode = 'sparkle', col = { a: '#8b7bff', b: '#38e8ff' };
  var trail = null, last = null, pend = null, pRaf = 0, MAX = 170;

  function resize() { W = innerWidth; H = innerHeight; cv.width = W; cv.height = H; }
  resize(); window.addEventListener('resize', CH.debounce(function () { resize(); }, 150));
  function level() { return root.getAttribute('data-fx'); }
  function enabled() { return root.getAttribute('data-themefx') !== '0' && level() !== 'off'; }
  function moving() { return enabled() && level() === 'full' && window.matchMedia && matchMedia('(pointer: fine)').matches; }
  function readTheme() {
    var cs = getComputedStyle(root), t = root.getAttribute('data-theme') || 'wraith';
    mode = (CORDX.themes[t] || CORDX.themes.wraith).fx;
    col.a = cs.getPropertyValue('--accent').trim() || '#8b7bff'; col.b = cs.getPropertyValue('--accent-2').trim() || '#38e8ff';
  }
  document.addEventListener('ch:settings', function () { readTheme(); if (!enabled()) { objs = []; trail = null; ctx.clearRect(0, 0, W, H); } });
  readTheme();
  function add(o) { if (objs.length < MAX) { o.t0 = performance.now(); objs.push(o); kick(); } }
  function kick() { if (!raf) raf = requestAnimationFrame(frame); }

  /* ---------- drawing ---------- */
  function star(x, y, r, rot) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(rot || 0); ctx.beginPath();
    ctx.moveTo(0, -r); ctx.quadraticCurveTo(r * .12, -r * .12, r, 0); ctx.quadraticCurveTo(r * .12, r * .12, 0, r); ctx.quadraticCurveTo(-r * .12, r * .12, -r, 0); ctx.quadraticCurveTo(-r * .12, -r * .12, 0, -r);
    ctx.closePath(); ctx.fill(); ctx.restore();
  }
  function line(x1, y1, x2, y2, w, c, a) { ctx.globalAlpha = a; ctx.strokeStyle = c; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); }
  function glowLine(x1, y1, x2, y2, w, c, a, core) { line(x1, y1, x2, y2, w * 2.6, c, a * .28); line(x1, y1, x2, y2, w, c, a * .8); line(x1, y1, x2, y2, Math.max(1, w * .38), core || '#fff', a); }

  function frame(now) {
    raf = 0; ctx.clearRect(0, 0, W, H); ctx.globalCompositeOperation = 'lighter';
    var keep = [];
    for (var i = 0; i < objs.length; i++) {
      var o = objs[i], age = Math.max(0, now - o.t0), k = age / o.life; if (k >= 1) continue;
      switch (o.k) {
        case 'flash': ctx.globalAlpha = (1 - k) * o.a; ctx.fillStyle = o.c; ctx.fillRect(0, 0, W, H); break;
        case 'spark': {
          var s = age / 16, x = o.x + o.vx * s, y = o.y + o.vy * s + o.g * s * s * .5;
          ctx.globalAlpha = (1 - k) * (o.star ? (.55 + .45 * Math.sin(age * .02 + o.ph)) : 1); ctx.fillStyle = o.c;
          if (o.star) { star(x, y, o.r * (1 - k * .5), age * .002 + o.ph); ctx.globalAlpha *= .35; star(x, y, o.r * 2.2, 0); } else { ctx.beginPath(); ctx.arc(x, y, o.r * (1 - k * .6), 0, 6.283); ctx.fill(); }
          break; }
        case 'line': glowLine(o.x1, o.y1, o.x2, o.y2, o.w * (1 - k * .6), o.c, 1 - k, '#fff'); break;
        case 'beam': {
          var g = k < .18 ? k / .18 : 1, a = 1 - Math.max(0, (k - .3) / .7), tx = o.x1 + (o.x2 - o.x1) * Math.min(1, k / .14);
          glowLine(o.x1, o.y1, tx, o.y1 + (o.y2 - o.y1) * Math.min(1, k / .14), o.w * (1 - k * .55) * g, col.a, a, '#fff');
          if (k > .1) { ctx.globalAlpha = a * .8; var rg = ctx.createRadialGradient(o.x2, o.y2, 0, o.x2, o.y2, 70 * (1 - k * .4)); rg.addColorStop(0, '#fff'); rg.addColorStop(.25, col.a); rg.addColorStop(1, 'rgba(255,0,0,0)'); ctx.fillStyle = rg; ctx.beginPath(); ctx.arc(o.x2, o.y2, 70, 0, 6.283); ctx.fill(); }
          break; }
        case 'ring': { var r = o.r0 + (o.r1 - o.r0) * (1 - Math.pow(1 - k, 3)); ctx.globalAlpha = (1 - k) * .9; ctx.strokeStyle = o.c; ctx.lineWidth = o.w * (1 - k); ctx.beginPath(); ctx.arc(o.x, o.y, r, 0, 6.283); ctx.stroke(); break; }
        case 'slash': {
          var p = clamp(age / 130, 0, 1), fade = 1 - clamp((age - 160) / (o.life - 160), 0, 1), ca = Math.cos(o.ang), sa = Math.sin(o.ang), ox = o.x + o.off * -sa, oy = o.y + o.off * ca, half = o.len / 2;
          var x0 = ox - ca * half, y0 = oy - sa * half, x1 = x0 + ca * o.len * p, y1 = y0 + sa * o.len * p;
          glowLine(x0, y0, x1, y1, 6 * (1 - k * .5), col.a, fade, '#fff'); break; }
        case 'trail': {
          var pts = o.pts, cut = now - 280; while (pts.length && pts[0].t < cut) pts.shift();
          for (var j = 1; j < pts.length; j++) { var f = 1 - (now - pts[j].t) / 280; if (f > 0) glowLine(pts[j - 1].x, pts[j - 1].y, pts[j].x, pts[j].y, 7 * f + 1, col.a, f, '#fff'); }
          if (!pts.length) continue; break; }
      }
      keep.push(o);
    }
    objs = keep; ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    if (objs.length) raf = requestAnimationFrame(frame); else ctx.clearRect(0, 0, W, H);
  }

  /* ---------- emitters ---------- */
  function sparkBurst(x, y, n, speed, g, star) {
    for (var i = 0; i < n; i++) { var a = Math.random() * 6.283, v = speed * (.3 + Math.random() * .9); add({ k: 'spark', x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, g: g, life: 380 + Math.random() * 360, r: 1.4 + Math.random() * 2.4, c: Math.random() < .5 ? col.a : (Math.random() < .5 ? col.b : '#fff'), star: star, ph: Math.random() * 6 }); }
  }
  function visorOrigin(y) {
    var a = document.querySelector('.stk.cur .stk-art svg, .stk.cur .stk-art img');
    if (mode === 'laser' && a) { var r = a.getBoundingClientRect(); if (r.bottom > 0 && r.top < H && r.width) return { x: r.left + r.width * .5, y: r.top + r.height * .37 }; }
    return { x: -30, y: y };
  }
  function hit(x, y, big) {
    if (!enabled()) return;
    var sc = big ? 1.5 : 1;
    if (mode === 'laser') {
      var o = visorOrigin(y); add({ k: 'beam', x1: o.x, y1: o.y, x2: x, y2: y, w: 11 * sc, life: big ? 520 : 380 });
      if (big) { add({ k: 'flash', a: .10, c: '#ff1f35', life: 160 }); shake(); }
      sparkBurst(x, y, big ? 16 : 8, 5, .06, false); add({ k: 'ring', x: x, y: y, r0: 4, r1: 60 * sc, w: 5, c: col.a, life: 420 });
    } else if (mode === 'streak') {
      var n = big ? 22 : 12;
      for (var i = 0; i < n; i++) { var a = (i / n) * 6.283 + Math.random() * .2, r0 = 14 + Math.random() * 14, r1 = r0 + 50 + Math.random() * 70 * sc; add({ k: 'line', x1: x + Math.cos(a) * r0, y1: y + Math.sin(a) * r0, x2: x + Math.cos(a) * r1, y2: y + Math.sin(a) * r1, w: 2 + Math.random() * 2, c: i % 3 ? '#cfe3ff' : '#ffffff', life: 340 + Math.random() * 160 }); }
      add({ k: 'ring', x: x, y: y, r0: 6, r1: 110 * sc, w: 4, c: '#ffffff', life: 520 }); if (big) add({ k: 'flash', a: .07, c: '#cfe3ff', life: 140 });
    } else if (mode === 'slash') {
      var ang = -0.9 + (Math.random() - .5) * .3; for (var s = -1; s <= 1; s++) add({ k: 'slash', x: x, y: y, ang: ang, off: s * 20, len: 150 * sc, life: 720 });
      sparkBurst(x, y, big ? 22 : 12, 6, .12, false); if (big) { add({ k: 'flash', a: .06, c: '#ffd25a', life: 130 }); shake(); }
    } else {
      sparkBurst(x, y, big ? 22 : 12, 4.5, -.01, true); add({ k: 'ring', x: x, y: y, r0: 4, r1: 70 * sc, w: 3, c: col.b, life: 520 });
    }
  }
  var shaking = 0;
  function shake() { var v = document.getElementById('view'); if (!v || level() !== 'full') return; v.classList.remove('fx-shake'); void v.offsetWidth; v.classList.add('fx-shake'); clearTimeout(shaking); shaking = setTimeout(function () { v.classList.remove('fx-shake'); }, 200); }

  function move(e) {
    if (!moving() || e.pointerType === 'touch') return;
    var x = e.clientX, y = e.clientY, now = performance.now();
    if (!last) { last = { x: x, y: y }; return; }
    var dx = x - last.x, dy = y - last.y, d = Math.hypot(dx, dy); if (d < 5) return;
    if (mode === 'laser') {
      if (!trail) { trail = { k: 'trail', pts: [], life: 1e9, t0: now }; objs.push(trail); } else if (objs.indexOf(trail) < 0) { objs.push(trail); }
      trail.pts.push({ x: x, y: y, t: now }); if (trail.pts.length > 24) trail.pts.shift(); kick();
    } else if (mode === 'streak') {
      if (d > 14) { var ux = dx / d, uy = dy / d, len = clamp(d * 2.2, 24, 150);
        for (var i = -1; i <= 1; i++) add({ k: 'line', x1: x - ux * len + -uy * i * 7, y1: y - uy * len + ux * i * 7, x2: x + -uy * i * 7, y2: y + ux * i * 7, w: i ? 1.4 : 2.2, c: i ? '#bcd6ff' : '#fff', life: 230 }); }
    } else if (mode === 'slash') {
      add({ k: 'spark', x: x, y: y, vx: (Math.random() - .5) * 3 - dx * .05, vy: -Math.random() * 2.6, g: .16, life: 420, r: 1.3 + Math.random() * 1.6, c: Math.random() < .5 ? '#ffd25a' : '#fff', ph: 0 });
    } else {
      if (Math.random() < .6) add({ k: 'spark', x: x, y: y, vx: (Math.random() - .5) * 1.6, vy: -.6 - Math.random() * 1.2, g: -.01, life: 620 + Math.random() * 300, r: 2.5 + Math.random() * 3.5, c: Math.random() < .5 ? col.a : col.b, star: true, ph: Math.random() * 6 });
    }
    last = { x: x, y: y };
  }
  document.addEventListener('pointermove', function (e) { pend = e; if (!pRaf) pRaf = requestAnimationFrame(function () { pRaf = 0; if (pend) move(pend); }); }, { passive: true });
  document.addEventListener('mouseleave', function () { last = null; });
  document.addEventListener('pointerdown', function (e) {
    if (e.button > 0 || !enabled()) return;
    var big = !!(e.target.closest && e.target.closest('.btn-primary, .h-go, .eye-cta, .sticky-actions .btn, .th-card'));
    hit(e.clientX, e.clientY, big);
  }, { passive: true });

  CH.themeFx = { hit: hit, hitEl: function (el) { var r = el.getBoundingClientRect(); hit(r.left + r.width / 2, r.top + r.height / 2, true); }, add: add, sparkBurst: sparkBurst };
})();
