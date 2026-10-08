/* Creator Hub — visual effects. Loaded lazily after first paint.
   • Particle field (single canvas, pre-rendered sprites, capped DPR)
   • Cursor light, card spotlight, subtle 3D tilt (transform-only, rAF-throttled)
   • Frame-time governor: drops particles, then stops, if the device can't keep up
   Everything is gated by <html data-fx="full|lite|off"> and the individual settings toggles. */
(function () {
  'use strict';
  var CH = window.CH, root = document.documentElement;
  var canvas = document.getElementById('fx-canvas'), glow = document.getElementById('cursor-glow');
  var ctx = canvas && canvas.getContext ? canvas.getContext('2d', { alpha: true }) : null;
  var clamp = CH.clamp;

  var P = { hold: 0, list: [], w: 0, h: 0, res: .5, raf: 0, last: 0, running: false, mx: -1e4, my: -1e4, sprites: [], bad: 0, scale: 1, dead: false };
  var G = { x: 0, y: 0, tx: 0, ty: 0, raf: 0, active: false, shown: false };

  function lvl() { return root.getAttribute('data-fx'); }
  function on(name) { return root.getAttribute('data-' + name) !== '0'; }
  function fine() { return window.matchMedia && matchMedia('(pointer: fine)').matches; }

  /* ---------------- Particles ---------------- */
  function makeSprites() {
    var cs = getComputedStyle(root);
    var cols = [cs.getPropertyValue('--accent-rgb').trim() || '124,108,255', cs.getPropertyValue('--accent-2-rgb').trim() || '53,212,255', '200,210,255'];
    P.sprites = cols.map(function (c) {
      var s = document.createElement('canvas'); s.width = s.height = 32;
      var x = s.getContext('2d'), g = x.createRadialGradient(16, 16, 0, 16, 16, 16);
      g.addColorStop(0, 'rgba(' + c + ',1)'); g.addColorStop(.35, 'rgba(' + c + ',.55)'); g.addColorStop(1, 'rgba(' + c + ',0)');
      x.fillStyle = g; x.fillRect(0, 0, 32, 32); return s;
    });
  }
  function resize() {
    // Soft glows don't need pixel-perfect output: render at half resolution and let CSS scale it up (4× fewer pixels to composite).
    P.res = .5;
    P.w = window.innerWidth; P.h = window.innerHeight;
    canvas.width = Math.round(P.w * P.res); canvas.height = Math.round(P.h * P.res);
    ctx.setTransform(P.res, 0, 0, P.res, 0, 0);
    var want = Math.round(clamp(P.w * P.h / 30000, 20, 44) * P.scale);
    while (P.list.length < want) P.list.push(spawn(true));
    P.list.length = Math.min(P.list.length, want);
  }
  function spawn(anywhere) {
    var z = .25 + Math.random() * .75;
    return {
      x: Math.random() * P.w, y: anywhere ? Math.random() * P.h : P.h + 10, z: z,
      vx: (Math.random() - .5) * .012, vy: -(.006 + Math.random() * .018) * (.5 + z),
      r: 5 + z * 11, a: .12 + Math.random() * .38, s: Math.floor(Math.random() * 3), t: Math.random() * 6.28
    };
  }
  function frame(now) {
    if (!P.running) return;
    P.raf = requestAnimationFrame(frame);
    var elapsed = now - (P.last || now - 33);
    if (elapsed < 30 || now < P.hold) return;       // cap at ~30 fps; hold still while scrolling so scroll stays smooth
    P.last = now;
    var dt = Math.min(elapsed, 64);
    // governor: sustained slow frames → fewer particles → stop entirely
    if (dt > 52) P.bad++; else if (P.bad > 0) P.bad -= .5;
    if (P.bad > 45) {
      P.bad = 0;
      if (P.scale > .45) { P.scale = .4; resize(); } else { P.dead = true; stopParticles(); canvas.style.display = 'none'; return; }
    }
    ctx.clearRect(0, 0, P.w, P.h);
    var mx = P.mx, my = P.my, W = P.w, H = P.h, px = (mx - W / 2) * .015, py = (my - H / 2) * .015;
    for (var i = 0; i < P.list.length; i++) {
      var p = P.list[i];
      var dx = mx - p.x, dy = my - p.y, d2 = dx * dx + dy * dy;
      if (d2 < 26000 && d2 > 1) { var d = Math.sqrt(d2), f = (1 - d / 161) * .00009 * dt * p.z; p.vx += dx / d * f; p.vy += dy / d * f; }
      p.vx *= .995; p.vy = p.vy * .995 + (-.012 - p.z * .006) * .0025;
      p.x += p.vx * dt; p.y += p.vy * dt; p.t += dt * .0012;
      if (p.y < -12) { P.list[i] = p = spawn(false); } if (p.x < -12) p.x = W + 12; else if (p.x > W + 12) p.x = -12;
      ctx.globalAlpha = p.a * (.7 + .3 * Math.sin(p.t * 3));
      var s = p.r * 2;
      ctx.drawImage(P.sprites[p.s], p.x - p.r - px * p.z, p.y - p.r - py * p.z, s, s);
    }
    ctx.globalAlpha = 1;
  }
  function startParticles() {
    if (!ctx || P.running || P.dead || document.hidden) return;
    canvas.style.display = '';
    if (!P.sprites.length) makeSprites();
    resize(); P.running = true; P.last = 0; P.raf = requestAnimationFrame(frame);
  }
  function stopParticles() { P.running = false; cancelAnimationFrame(P.raf); if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height); }

  /* ---------------- Cursor light ---------------- */
  function glowTick() {
    G.x += (G.tx - G.x) * .14; G.y += (G.ty - G.y) * .14;
    glow.style.transform = 'translate3d(' + G.x.toFixed(1) + 'px,' + G.y.toFixed(1) + 'px,0)';
    if (Math.abs(G.tx - G.x) + Math.abs(G.ty - G.y) > .6) G.raf = requestAnimationFrame(glowTick); else G.raf = 0;
  }

  /* ---------------- Pointer: glow + particles + tilt + spotlight ---------------- */
  var pend = null, pendRaf = 0, lastTilt = null;
  function onMove(e) {
    if (e.pointerType && e.pointerType !== 'mouse') return;
    var l = lvl(); if (l === 'off') return;
    pend = e;
    if (!pendRaf) pendRaf = requestAnimationFrame(flush);
  }
  function flush() {
    pendRaf = 0; var e = pend; if (!e) return;
    var l = lvl();
    if (l === 'full') {
      P.mx = e.clientX; P.my = e.clientY;
      if (on('glow') && glow) { G.tx = e.clientX; G.ty = e.clientY; if (!G.shown) { G.x = G.tx; G.y = G.ty; G.shown = true; glow.classList.add('on'); } if (!G.raf) G.raf = requestAnimationFrame(glowTick); }
    }
    var t = e.target && e.target.closest ? e.target : null;
    var spot = t && t.closest('.spot');
    if (spot) { var r = spot.getBoundingClientRect(); spot.style.setProperty('--mx', (e.clientX - r.left) + 'px'); spot.style.setProperty('--my', (e.clientY - r.top) + 'px'); }
    var tilt = l === 'full' && on('tilt') && t ? t.closest('.tilt') : null;
    if (lastTilt && lastTilt !== tilt) resetTilt(lastTilt);
    if (tilt) {
      var b = tilt.getBoundingClientRect(), nx = (e.clientX - b.left) / b.width - .5, ny = (e.clientY - b.top) / b.height - .5;
      var max = parseFloat(tilt.getAttribute('data-tilt-max')) || 5;
      tilt.classList.add('tilting');
      tilt.style.setProperty('--ry', (nx * max * 2).toFixed(2) + 'deg'); tilt.style.setProperty('--rx', (-ny * max * 2).toFixed(2) + 'deg');
    }
    lastTilt = tilt;
    // hero scene parallax
    var scene = l === 'full' && on('tilt') ? document.querySelector('.scene') : null;
    if (scene) {
      var sb = scene.getBoundingClientRect();
      if (e.clientY > sb.top - 140 && e.clientY < sb.bottom + 140) {
        var sx = clamp((e.clientX - (sb.left + sb.width / 2)) / (window.innerWidth / 2), -1, 1), sy = clamp((e.clientY - (sb.top + sb.height / 2)) / (window.innerHeight / 2), -1, 1);
        scene.classList.add('live'); scene.style.setProperty('--sry', (sx * 9).toFixed(2) + 'deg'); scene.style.setProperty('--srx', (-sy * 7).toFixed(2) + 'deg');
      }
    }
  }
  function resetTilt(n) { n.classList.remove('tilting'); n.style.removeProperty('--rx'); n.style.removeProperty('--ry'); }
  window.addEventListener('scroll', function () { P.hold = performance.now() + 140; }, { passive: true });
  document.addEventListener('pointermove', onMove, { passive: true });
  document.documentElement.addEventListener('mouseleave', function () {
    if (lastTilt) resetTilt(lastTilt); lastTilt = null;
    if (glow) { glow.classList.remove('on'); G.shown = false; }
    P.mx = P.my = -1e4;
    var sc = document.querySelector('.scene'); if (sc) { sc.classList.remove('live'); sc.style.removeProperty('--srx'); sc.style.removeProperty('--sry'); }
  });

  /* ---------------- Lifecycle ---------------- */
  function refresh() {
    var full = lvl() === 'full' && fine() !== false;
    if (full && on('particles') && !P.dead) { startParticles(); } else { stopParticles(); }
    if (!(full && on('glow')) && glow) { glow.classList.remove('on'); G.shown = false; }
    if (full) makeSprites();
  }
  document.addEventListener('ch:settings', function () { P.scale = 1; refresh(); });
  // Pause the particle field while the search overlay (which blurs what's behind it) is open.
  document.addEventListener('ch:overlay', function (e) { if (e.detail) stopParticles(); else refresh(); });
  document.addEventListener('visibilitychange', function () { if (document.hidden) stopParticles(); else refresh(); });
  var rt; window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(function () { if (P.running) resize(); }, 200); });

  CH.fx = { refresh: refresh };
  refresh();
})();
