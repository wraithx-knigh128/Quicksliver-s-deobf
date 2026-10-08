/* Creator Hub — shared utilities. Exposes window.CH. No dependencies. */
(function () {
  'use strict';
  var CH = window.CH = window.CH || {};

  /* ---------- DOM ---------- */
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  /** el('div', {class:'x', onclick:fn, dataset:{a:1}}, 'text', childEl, [..]) — never uses innerHTML for user data. */
  function el(tag, attrs) {
    var n = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        var v = attrs[k];
        if (v == null || v === false) continue;
        if (k === 'class') n.className = v;
        else if (k === 'dataset') { for (var d in v) n.dataset[d] = v[d]; }
        else if (k === 'style' && typeof v === 'object') { for (var s in v) { if (s.indexOf('-') >= 0) n.style.setProperty(s, String(v[s])); else n.style[s] = v[s]; } }
        else if (k === 'html') n.innerHTML = v; // only ever called with trusted/escaped strings
        else if (k === 'text') n.textContent = v;
        else if (k.slice(0, 2) === 'on' && typeof v === 'function') n.addEventListener(k.slice(2), v);
        else if (v === true) n.setAttribute(k, '');
        else n.setAttribute(k, v);
      }
    }
    for (var i = 2; i < arguments.length; i++) append(n, arguments[i]);
    return n;
  }
  function append(n, c) {
    if (c == null || c === false) return;
    if (Array.isArray(c)) { c.forEach(function (x) { append(n, x); }); return; }
    n.appendChild(c.nodeType ? c : document.createTextNode(String(c)));
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function clear(n) { while (n.firstChild) n.removeChild(n.firstChild); return n; }

  /* ---------- Random (crypto-backed, so repeated clicks never feel patterned) ---------- */
  var buf = new Uint32Array(1);
  function rnd() {
    if (window.crypto && crypto.getRandomValues) { crypto.getRandomValues(buf); return buf[0] / 4294967296; }
    return Math.random();
  }
  function int(n) { return Math.floor(rnd() * n); }
  function range(a, b) { return a + int(b - a + 1); }
  function pick(arr) { return arr[int(arr.length)]; }
  function chance(p) { return rnd() < p; }
  function shuffle(arr) {
    var a = arr.slice();
    for (var i = a.length - 1; i > 0; i--) { var j = int(i + 1); var t = a[i]; a[i] = a[j]; a[j] = t; }
    return a;
  }
  /** Picks from pools without repeating until the pool is exhausted (keeps output from feeling samey). */
  var freshState = {};
  function fresh(key, arr) {
    var st = freshState[key] || (freshState[key] = []);
    var pool = arr.filter(function (_, i) { return st.indexOf(i) < 0; });
    if (!pool.length) { st.length = 0; pool = arr.slice(); }
    var item = pick(pool);
    st.push(arr.indexOf(item));
    if (st.length > Math.max(1, arr.length - 1)) st.shift();
    return item;
  }
  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
  function debounce(fn, ms) { var t; return function () { var a = arguments, c = this; clearTimeout(t); t = setTimeout(function () { fn.apply(c, a); }, ms); }; }
  function raf(fn) { var q = false; return function () { if (q) return; q = true; var a = arguments; requestAnimationFrame(function () { q = false; fn.apply(null, a); }); }; }
  function uid() { return Date.now().toString(36) + Math.floor(rnd() * 1e6).toString(36); }
  function list(items, max, and) {
    items = items.filter(Boolean); if (max) items = items.slice(0, max);
    if (items.length < 2) return items.join('');
    return items.slice(0, -1).join(', ') + (and || ' & ') + items[items.length - 1];
  }
  function csv(s) { return String(s || '').split(/[,\n;|]+/).map(function (x) { return x.trim(); }).filter(Boolean); }
  function fmt(tpl, vars) { return String(tpl).replace(/\{(\w+)\}/g, function (m, k) { return vars[k] != null ? vars[k] : ''; }); }

  /* ---------- Storage (localStorage with in-memory fallback) ---------- */
  var mem = {};
  var Store = {
    get: function (k, d) {
      if (k in mem) return mem[k];
      try { var v = localStorage.getItem('ch:' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; }
    },
    set: function (k, v) {
      try { localStorage.setItem('ch:' + k, JSON.stringify(v)); delete mem[k]; } catch (e) { mem[k] = v; }
    },
    del: function (k) { delete mem[k]; try { localStorage.removeItem('ch:' + k); } catch (e) {} }
  };
  var Saved = {
    all: function () { var a = Store.get('saved', []); return Array.isArray(a) ? a : []; },
    add: function (item) {
      var all = Saved.all();
      var dupe = all.filter(function (x) { return x.type === item.type && x.body === item.body; })[0];
      if (dupe) return { item: dupe, dupe: true };
      item = Object.assign({ id: uid(), ts: Date.now(), fav: false }, item);
      all.unshift(item);
      Store.set('saved', all.slice(0, 500));
      document.dispatchEvent(new CustomEvent('ch:saved'));
      return { item: item, dupe: false };
    },
    update: function (id, patch) {
      var all = Saved.all().map(function (x) { return x.id === id ? Object.assign({}, x, patch) : x; });
      Store.set('saved', all); document.dispatchEvent(new CustomEvent('ch:saved'));
    },
    remove: function (id) {
      Store.set('saved', Saved.all().filter(function (x) { return x.id !== id; })); document.dispatchEvent(new CustomEvent('ch:saved'));
    },
    find: function (type, body) { return Saved.all().filter(function (x) { return x.type === type && x.body === body; })[0]; },
    replaceAll: function (arr) { Store.set('saved', arr); document.dispatchEvent(new CustomEvent('ch:saved')); }
  };

  /* ---------- Clipboard / files / toast ---------- */
  function copy(text) {
    text = String(text);
    function fallback() {
      return new Promise(function (res, rej) {
        var ta = el('textarea', { 'aria-hidden': 'true', style: { position: 'fixed', top: '-1000px', opacity: '0' } });
        ta.value = text; document.body.appendChild(ta); ta.focus(); ta.select();
        try { document.execCommand('copy') ? res() : rej(new Error('copy failed')); } catch (e) { rej(e); }
        document.body.removeChild(ta);
      });
    }
    var p = (navigator.clipboard && window.isSecureContext) ? navigator.clipboard.writeText(text).catch(fallback) : fallback();
    return p.then(function () { toast('Copied to clipboard'); return true; }, function () { toast('Copy failed — select the text and copy manually', 'bad'); return false; });
  }
  function download(name, text, mime) {
    var blob = new Blob([text], { type: mime || 'text/plain;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = el('a', { href: url, download: name });
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
  }
  function toast(msg, kind) {
    var host = $('#toasts'); if (!host) return;
    while (host.children.length > 3) host.removeChild(host.firstChild);
    var t = el('div', { class: 'toast ' + (kind || '') }, kind === 'bad' ? icon('x') : icon('check'), el('span', null, msg));
    host.appendChild(t);
    setTimeout(function () { t.classList.add('out'); setTimeout(function () { t.remove(); }, 260); }, 2200);
  }

  /* ---------- Icons (inline SVG, 24px grid, stroke-based) ---------- */
  var P = {
    home: '<path d="m3 11 9-8 9 8"/><path d="M5 10v10h5v-6h4v6h5V10"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    embed: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M7 9h6M7 13h10M7 16h4"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4.5-6 8-6s7 2 8 6"/>',
    at: '<circle cx="12" cy="12" r="4"/><path d="M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8"/>',
    shield: '<path d="M12 3 4 6v6c0 5 3.4 8.2 8 9 4.6-.8 8-4 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
    megaphone: '<path d="M3 11v3a1 1 0 0 0 1 1h2l5 4V6L6 10H4a1 1 0 0 0-1 1z"/><path d="M15 9a4 4 0 0 1 0 6M18 6.5a8 8 0 0 1 0 11"/>',
    text: '<path d="M4 6h16M4 11h16M4 16h10"/>',
    tag: '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.3"/>',
    hash: '<path d="M5 9h15M4 15h15M10 3 8 21M16 3l-2 18"/>',
    bot: '<rect x="4" y="8" width="16" height="12" rx="3"/><path d="M12 8V4M9 14v1M15 14v1"/><circle cx="12" cy="3.5" r="1"/>',
    bulb: '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.7.6 1 1.2 1 2.1h5c0-.9.3-1.5 1-2.1A6 6 0 0 0 12 3z"/>',
    layout: '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M3 9h18M9 21V9"/>',
    bookmark: '<path d="M6 3h12v18l-6-4-6 4z"/>',
    crown: '<path d="m3 8 4.5 4L12 5l4.5 7L21 8l-2 11H5z"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    copy: '<rect x="9" y="9" width="12" height="12" rx="2.5"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>',
    refresh: '<path d="M20 11a8 8 0 0 0-14.5-4M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.5 4M20 20v-4h-4"/>',
    edit: '<path d="M4 20h4L19 9a2.1 2.1 0 0 0-3-3L5 17z"/><path d="m14 7 3 3"/>',
    save: '<path d="M5 3h11l3 3v15H5z"/><path d="M8 3v5h7V3M8 21v-7h8v7"/>',
    star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    download: '<path d="M12 4v11M7 11l5 5 5-5M5 20h14"/>',
    upload: '<path d="M12 16V5M7 9l5-5 5 5M5 20h14"/>',
    check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
    x: '<path d="M6 6l12 12M18 6 6 18"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    arrowUp: '<path d="M12 19V5M6 11l6-6 6 6"/>',
    arrowDown: '<path d="M12 5v14M6 13l6 6 6-6"/>',
    arrowRight: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    external: '<path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
    sparkle: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    code: '<path d="m8 8-4 4 4 4M16 8l4 4-4 4M14 5l-4 14"/>',
    send: '<path d="M21 3 10 14M21 3l-7 18-4-7-7-4z"/>',
    alert: '<path d="M12 3 2 20h20z"/><path d="M12 10v4M12 17.5h.01"/>',
    copyAll: '<rect x="8" y="8" width="13" height="13" rx="2.5"/><path d="M4 16V5a2 2 0 0 1 2-2h11"/>',
    heart: '<path d="M12 20s-8-4.6-8-11a4.6 4.6 0 0 1 8-3 4.6 4.6 0 0 1 8 3c0 6.4-8 11-8 11z"/>',
    dice: '<rect x="4" y="4" width="16" height="16" rx="3.5"/><circle cx="9" cy="9" r="1" fill="currentColor"/><circle cx="15" cy="15" r="1" fill="currentColor"/><circle cx="15" cy="9" r="1" fill="currentColor"/><circle cx="9" cy="15" r="1" fill="currentColor"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    chevronDown: '<path d="m6 9 6 6 6-6"/>',
    sliders: '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
    bell: '<path d="M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
    volume: '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M16 9a4 4 0 0 1 0 6"/>',
    file: '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5"/>',
    link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>'
  };
  function icon(name, cls) {
    var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('aria-hidden', 'true'); s.setAttribute('focusable', 'false');
    s.setAttribute('class', 'i' + (cls ? ' ' + cls : ''));
    s.innerHTML = P[name] || P.sparkle;
    return s;
  }
  function iconHTML(name) { return '<svg class="i" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' + (P[name] || P.sparkle) + '</svg>'; }

  /* ---------- Misc helpers ---------- */
  function safeUrl(u) {
    u = String(u || '').trim();
    if (!/^https?:\/\//i.test(u)) return '';
    try { var x = new URL(u); return (x.protocol === 'http:' || x.protocol === 'https:') ? x.href : ''; } catch (e) { return ''; }
  }
  function formatDiscordTime(d) {
    var now = new Date(), t = d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
    var same = d.toDateString() === now.toDateString();
    if (same) return 'Today at ' + t;
    var y = new Date(now); y.setDate(now.getDate() - 1);
    if (d.toDateString() === y.toDateString()) return 'Yesterday at ' + t;
    return d.toLocaleDateString([], { month: '2-digit', day: '2-digit', year: 'numeric' });
  }

  Object.assign(CH, {
    $: $, $$: $$, el: el, esc: esc, clear: clear, rnd: rnd, int: int, range: range, pick: pick, chance: chance, shuffle: shuffle, fresh: fresh,
    cap: cap, clamp: clamp, debounce: debounce, raf: raf, uid: uid, list: list, csv: csv, fmt: fmt,
    Store: Store, Saved: Saved, copy: copy, download: download, toast: toast, icon: icon, iconHTML: iconHTML, ICONS: P,
    safeUrl: safeUrl, formatDiscordTime: formatDiscordTime
  });
})();
