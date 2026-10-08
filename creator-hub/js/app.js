/* CordX — app core: settings, routing, navigation, global search, shared UI kit. */
(function () {
  'use strict';
  var CH = window.CH, CORDX = window.CORDX, el = CH.el, $ = CH.$, icon = CH.icon;
  var root = document.documentElement;

  /* ======================================================================
     Routes (single source of truth for nav, search and the Tools page)
     ====================================================================== */
  var ROUTES = [
    { id: 'home', title: 'Home', group: 'Discover', icon: 'home', css: 'css/home.css', deps: ['js/gen/username.js', 'js/theme-art.js'], desc: 'Your Discord creator toolkit at a glance', kw: 'start dashboard overview welcome' },
    { id: 'tools', title: 'Tools', group: 'Discover', icon: 'grid', desc: 'Every builder and generator in one place', kw: 'all tools list browse directory' },
    { id: 'embeds', title: 'Discord Embeds', group: 'Build', icon: 'embed', tool: true, desc: 'Live embed builder with webhook JSON, code export and Discord-style preview', kw: 'embed webhook json builder message rich preview button discord.js discord.py curl markdown' },
    { id: 'bio', title: 'Bio Generator', group: 'Build', icon: 'user', tool: true, desc: '15 styles, 3 lengths and Unicode fonts — bios that fit the 190-character limit', kw: 'about me profile bio description unicode font symbols anime gamer aesthetic' },
    { id: 'username', title: 'Username Generator', group: 'Build', icon: 'at', tool: true, deps: ['js/gen/username.js'], desc: 'Original usernames from your name, interests and theme, checked against Discord rules', kw: 'name nickname handle gamer og short clean tag generator random display name' },
    { id: 'rules', title: 'Server Rules Generator', group: 'Build', icon: 'shield', tool: true, desc: 'Rules, tone, strictness and a moderation policy for any kind of server', kw: 'rules guidelines moderation staff punishment policy warnings ban appeal community' },
    { id: 'announcements', title: 'Announcement Generator', group: 'Build', icon: 'megaphone', tool: true, desc: 'Events, updates, giveaways and more — with Discord timestamp tags', kw: 'announcement event update giveaway maintenance patch notes ping everyone timestamp news' },
    { id: 'description', title: 'Server Description Generator', group: 'Build', icon: 'text', tool: true, desc: 'Short, medium and long descriptions for Discovery, listings and your about page', kw: 'server description about discovery listing bio blurb pitch' },
    { id: 'roles', title: 'Role Generator', group: 'Build', icon: 'tag', tool: true, desc: 'Themed role hierarchies with colours and sensible permission suggestions', kw: 'roles hierarchy permissions colors staff moderator member level color roles ping roles' },
    { id: 'channels', title: 'Channel Generator', group: 'Build', icon: 'hash', tool: true, desc: 'Category and channel layouts with topics, voice, forums and a staff area', kw: 'channels categories layout structure server setup forum voice stage text topic' },
    { id: 'bots', title: 'Bot Directory', group: 'Explore', icon: 'bot', tool: true, desc: 'Well-known Discord bots by category, plus the built-in features that replace many of them', kw: 'bots moderation music leveling tickets logging mee6 dyno carl-bot automod' },
    { id: 'ideas', title: 'Server Ideas', group: 'Explore', icon: 'bulb', tool: true, desc: 'Concepts, channel plans and growth hooks for your next community', kw: 'ideas concepts niche start new server inspiration roulette' },
    { id: 'templates', title: 'Templates', group: 'Explore', icon: 'layout', tool: true, desc: 'Ready-made embeds: welcome, rules, giveaway, tickets, changelog and more', kw: 'templates welcome verification ticket giveaway changelog faq partnership staff application' },
    { id: 'saved', title: 'Saved Creations', group: 'Library', icon: 'bookmark', desc: 'Everything you saved, stored privately in this browser', kw: 'saved favorites library history export import backup' },
    { id: 'pro', title: 'Pricing / Pro', group: 'Account', icon: 'crown', desc: 'What is free, what Pro will add, and how we handle your data', kw: 'pricing pro plan premium upgrade free waitlist' },
    { id: 'about', title: 'About', group: 'Account', icon: 'info', desc: 'How it works, privacy, and what Discord does and does not support', kw: 'about privacy limitations faq help discord limits shortcuts' },
    { id: 'legal', title: 'Terms & Policies', group: 'Account', icon: 'file', desc: 'Terms of use, privacy, trademarks and credits', kw: 'terms policy privacy legal copyright trademark license disclaimer credits' },
    { id: 'settings', title: 'Settings', group: 'Account', icon: 'settings', desc: 'Effects, accent colour, density and your data', kw: 'settings preferences effects motion accent theme data reset performance' }
  ];
  var GROUPS = ['Discover', 'Build', 'Explore', 'Library', 'Account'];
  var byId = {}; ROUTES.forEach(function (r) { byId[r.id] = r; });

  // Extra searchable entries that live inside lazy-loaded pages.
  var EXTRAS = [
    ['Welcome message template', 'templates', 'Embed template'], ['Rules embed template', 'templates', 'Embed template'], ['Giveaway embed template', 'templates', 'Embed template'],
    ['Ticket panel template', 'templates', 'Embed template'], ['Changelog template', 'templates', 'Embed template'], ['Staff application template', 'templates', 'Embed template'],
    ['Webhook JSON export', 'embeds', 'Embed builder'], ['discord.js embed code', 'embeds', 'Embed builder'], ['discord.py embed code', 'embeds', 'Embed builder'], ['Send embed through a webhook', 'embeds', 'Embed builder'],
    ['Embed limits and Discord limitations', 'embeds', 'Embed builder'],
    ['MEE6', 'bots', 'Bot'], ['Dyno', 'bots', 'Bot'], ['Carl-bot', 'bots', 'Bot'], ['Ticket Tool', 'bots', 'Bot'], ['Wick', 'bots', 'Bot'], ['YAGPDB', 'bots', 'Bot'], ['Statbot', 'bots', 'Bot'], ['GiveawayBot', 'bots', 'Bot'], ['Dank Memer', 'bots', 'Bot'],
    ['Discord AutoMod (built in)', 'bots', 'Native feature'], ['Discord Onboarding (built in)', 'bots', 'Native feature'], ['Bot safety checklist', 'bots', 'Guide'],
    ['Gamer usernames', 'username', 'Username style'], ['OG-style short usernames', 'username', 'Username style'], ['Anime usernames', 'username', 'Username style'],
    ['Unicode bio fonts', 'bio', 'Bio feature'], ['190 character bio limit', 'bio', 'Bio feature'],
    ['Discord timestamp tags', 'announcements', 'Announcements'], ['Giveaway announcement', 'announcements', 'Announcements'], ['Maintenance notice', 'announcements', 'Announcements'],
    ['Moderation policy and punishments', 'rules', 'Rules'], ['Warning ladder', 'rules', 'Rules'],
    ['Role hierarchy and permissions', 'roles', 'Roles'], ['Gaming server channel layout', 'channels', 'Channels'], ['Study server idea', 'ideas', 'Server ideas']
  ].map(function (x) { return { title: x[0], href: '#/' + x[1], icon: byId[x[1]].icon, kind: x[2], kw: '' }; });

  CH.routes = ROUTES; CH.routeById = byId;

  /* ======================================================================
     Settings + effects level
     ====================================================================== */
  var DEF = { fx: 'auto', particles: true, glow: true, tilt: true, theme: 'wraith', themeFx: true, accent: 'violet', density: 'comfortable', previewTheme: 'dark' };
  var settings = Object.assign({}, DEF, CH.Store.get('settings', {}));
  var mqReduce = window.matchMedia ? matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };
  var mqCoarse = window.matchMedia ? matchMedia('(pointer: coarse)') : { matches: false };

  function autoLevel() {
    if (mqReduce.matches) return 'off';
    var conn = navigator.connection || {};
    var weak = (navigator.hardwareConcurrency && navigator.hardwareConcurrency <= 2) || (navigator.deviceMemory && navigator.deviceMemory <= 2) || conn.saveData;
    if (mqCoarse.matches || Math.min(window.innerWidth, screen.width || 9999) < 760 || weak) return 'lite';
    return 'full';
  }
  function level() { return settings.fx === 'auto' ? autoLevel() : settings.fx; }
  function applySettings() {
    if (!CORDX.themes[settings.theme]) settings.theme = 'wraith';
    root.setAttribute('data-theme', settings.theme);
    root.setAttribute('data-themefx', settings.themeFx ? '1' : '0');
    root.setAttribute('data-accent', settings.accent);
    root.setAttribute('data-density', settings.density);
    root.setAttribute('data-fx', level());
    root.setAttribute('data-particles', settings.particles ? '1' : '0');
    root.setAttribute('data-glow', settings.glow ? '1' : '0');
    root.setAttribute('data-tilt', settings.tilt ? '1' : '0');
    document.dispatchEvent(new CustomEvent('ch:settings'));
  }
  CH.settings = {
    get: function () { return Object.assign({}, settings); },
    set: function (patch) { Object.assign(settings, patch); CH.Store.set('settings', settings); applySettings(); },
    reset: function () { settings = Object.assign({}, DEF); CH.Store.del('settings'); applySettings(); },
    level: level, autoLevel: autoLevel, defaults: DEF
  };
  if (mqReduce.addEventListener) { mqReduce.addEventListener('change', applySettings); }
  var rz; window.addEventListener('resize', function () { clearTimeout(rz); rz = setTimeout(function () { if (settings.fx === 'auto' && root.getAttribute('data-fx') !== autoLevel()) applySettings(); }, 250); });

  /* ======================================================================
     Handoff between tools (e.g. Rules → Embed builder)
     ====================================================================== */
  CH.handoff = {
    set: function (type, data) { CH.Store.set('handoff', { type: type, data: data, ts: Date.now() }); },
    take: function (type) {
      var h = CH.Store.get('handoff', null);
      if (!h || h.type !== type || Date.now() - h.ts > 600000) return null;
      CH.Store.del('handoff'); return h.data;
    }
  };

  /* ======================================================================
     UI kit
     ====================================================================== */
  var uidc = 0;
  var ui = CH.ui = {};

  ui.pageHead = function (o) {
    return el('header', { class: 'page-head' },
      el('div', { class: 'ph-icon' }, icon(o.icon)),
      el('div', null, el('h1', null, o.title, o.badge ? el('span', { class: 'badge ' + (o.badgeKind || '') }, o.badge) : null), o.desc ? el('p', null, o.desc) : null));
  };
  ui.btn = function (label, o) {
    o = o || {};
    var b = el(o.href ? 'a' : 'button', { class: 'btn ' + (o.kind ? 'btn-' + o.kind : '') + (o.sm ? ' btn-sm' : '') + (o.lg ? ' btn-lg' : ''), type: o.href ? null : 'button', href: o.href, title: o.title, 'aria-label': o.aria },
      o.icon ? icon(o.icon) : null, label ? el('span', null, label) : null);
    if (o.onclick) b.addEventListener('click', o.onclick);
    return b;
  };
  ui.callout = function (type, content) {
    var ic = { info: 'info', warn: 'alert', bad: 'alert', ok: 'check' }[type] || 'info';
    var body = el('div', null);
    [].slice.call(arguments, 1).forEach(function (c) { if (c != null) body.appendChild(c.nodeType ? c : document.createTextNode(c)); });
    return el('div', { class: 'callout ' + type, role: type === 'bad' ? 'alert' : null }, icon(ic), body);
  };
  ui.empty = function (ic, title, text) { return el('div', { class: 'empty' }, icon(ic), el('h3', null, title), el('p', null, text)); };

  ui.field = function (o) {
    var id = 'f' + (++uidc), input;
    if (o.type === 'textarea') input = el('textarea', { class: 'textarea', rows: o.rows || 3 });
    else if (o.type === 'select') {
      input = el('select', { class: 'select' }, (o.options || []).map(function (op) {
        var v = typeof op === 'string' ? op : op.value, l = typeof op === 'string' ? op : op.label;
        return el('option', { value: v }, l);
      }));
    } else input = el('input', { class: 'input', type: o.type || 'text' });
    input.id = id;
    if (o.placeholder) input.placeholder = o.placeholder;
    if (o.hard) input.maxLength = o.hard;
    if (o.min != null) input.min = o.min; if (o.max != null && o.type === 'number') input.max = o.max;
    if (o.type !== 'color' && o.type !== 'select') { input.autocomplete = 'off'; input.spellcheck = o.spell === true; }
    if (o.inputmode) input.setAttribute('inputmode', o.inputmode);
    if (o.value != null) input.value = o.value;
    var counter = (o.max && o.type !== 'number' && o.type !== 'select') ? el('span', { class: 'counter' }) : null;
    function count() {
      if (!counter) return;
      var n = input.value.length; counter.textContent = n + '/' + o.max;
      counter.className = 'counter' + (n > o.max ? ' bad' : n > o.max * .9 ? ' warn' : '');
      input.classList.toggle('bad', n > o.max);
    }
    function upd() { count(); if (o.onInput) o.onInput(input.value, input); }
    input.addEventListener(o.type === 'select' ? 'change' : 'input', upd);
    var f = el('div', { class: 'field' + (o.cls ? ' ' + o.cls : '') },
      o.label ? el('label', { for: id }, el('span', null, o.label, o.sub ? el('span', { class: 'label-sub' }, ' ' + o.sub) : null), counter) : null,
      input, o.hint ? el('div', { class: 'hint' }, o.hint) : null);
    count();
    return { el: f, input: input, get: function () { return input.value; }, set: function (v) { input.value = v == null ? '' : v; upd(); } };
  };

  ui.chips = function (o) {
    var multi = !!o.multi, val = multi ? (o.value || []).slice() : o.value;
    var wrap = el('div', { class: 'chips' + (o.ex ? ' with-ex' : '') + (o.sm ? ' sm' : ''), role: multi ? 'group' : 'radiogroup', 'aria-label': o.label || null });
    var btns = o.options.map(function (op) {
      op = typeof op === 'string' ? { value: op, label: op } : op;
      var b = el('button', { type: 'button', class: 'chip', role: multi ? null : 'radio', dataset: { v: op.value } },
        el('span', null, op.label), op.ex ? el('span', { class: 'chip-ex' }, op.ex) : null);
      b.addEventListener('click', function () { choose(op.value, true); });
      return b;
    });
    btns.forEach(function (b) { wrap.appendChild(b); });
    function sync() {
      btns.forEach(function (b) {
        var on = multi ? val.indexOf(b.dataset.v) >= 0 : val === b.dataset.v;
        b.setAttribute(multi ? 'aria-pressed' : 'aria-checked', on ? 'true' : 'false');
        if (!multi) b.tabIndex = (on || (val == null && b === btns[0])) ? 0 : -1;
      });
    }
    function choose(v, fire) {
      if (multi) { var i = val.indexOf(v); if (i >= 0) val.splice(i, 1); else val.push(v); } else val = v;
      sync(); if (fire && o.onChange) o.onChange(multi ? val.slice() : val);
    }
    if (!multi) wrap.addEventListener('keydown', function (e) {
      var k = e.key; if (['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'].indexOf(k) < 0) return;
      e.preventDefault();
      var i = btns.indexOf(document.activeElement); if (i < 0) i = 0;
      i = (i + (k === 'ArrowRight' || k === 'ArrowDown' ? 1 : -1) + btns.length) % btns.length;
      btns[i].focus(); choose(btns[i].dataset.v, true);
    });
    sync();
    return { el: wrap, get: function () { return multi ? val.slice() : val; }, set: function (v) { val = multi ? (v || []).slice() : v; sync(); } };
  };
  ui.seg = function (o) {
    var val = o.value;
    var wrap = el('div', { class: 'seg', role: 'radiogroup', 'aria-label': o.label || null });
    var btns = o.options.map(function (op) {
      op = typeof op === 'string' ? { value: op, label: op } : op;
      var b = el('button', { type: 'button', role: 'radio', dataset: { v: op.value } }, op.label);
      b.addEventListener('click', function () { val = op.value; sync(); if (o.onChange) o.onChange(val); });
      return b;
    });
    btns.forEach(function (b) { wrap.appendChild(b); });
    function sync() { btns.forEach(function (b) { b.setAttribute('aria-checked', b.dataset.v === val ? 'true' : 'false'); }); }
    sync();
    return { el: wrap, get: function () { return val; }, set: function (v) { val = v; sync(); } };
  };
  ui.range = function (o) {
    var id = 'r' + (++uidc);
    var inp = el('input', { type: 'range', id: id, min: o.min, max: o.max, step: o.step || 1, value: o.value });
    var out = el('span', { class: 'range-val' });
    function upd() {
      var p = (inp.value - o.min) / (o.max - o.min) * 100; inp.style.setProperty('--p', p + '%');
      out.textContent = o.fmt ? o.fmt(+inp.value) : inp.value;
      if (o.onInput) o.onInput(+inp.value);
    }
    inp.addEventListener('input', upd);
    var f = el('div', { class: 'field' }, el('div', { class: 'range-top' }, el('label', { for: id, class: 'label' }, o.label), out), inp, o.hint ? el('div', { class: 'hint' }, o.hint) : null);
    upd();
    return { el: f, get: function () { return +inp.value; }, set: function (v) { inp.value = v; upd(); }, input: inp };
  };
  ui.switch = function (o) {
    var inp = el('input', { type: 'checkbox' }); inp.checked = !!o.checked;
    inp.addEventListener('change', function () { if (o.onChange) o.onChange(inp.checked); });
    var l = el('label', { class: 'switch' }, inp, el('span', { class: 'track' }), el('span', null, o.label));
    return { el: l, get: function () { return inp.checked; }, set: function (v) { inp.checked = !!v; }, input: inp };
  };
  ui.acc = function (title, body, o) {
    o = o || {};
    return el('details', { class: 'acc', open: o.open ? true : null }, el('summary', null, title, o.meta ? el('span', { class: 'acc-sum-meta' }, o.meta) : null), el('div', { class: 'acc-body' }, body));
  };
  ui.tabs = function (o) {
    var val = o.value, wrap = el('div', { class: 'tabs', role: 'tablist', 'aria-label': o.label || null });
    var btns = o.items.map(function (it) {
      var b = el('button', { type: 'button', class: 'tab', role: 'tab', dataset: { v: it.id } }, it.label);
      b.addEventListener('click', function () { val = it.id; sync(); if (o.onChange) o.onChange(val); });
      return b;
    });
    btns.forEach(function (b) { wrap.appendChild(b); });
    function sync() { btns.forEach(function (b) { var on = b.dataset.v === val; b.setAttribute('aria-selected', on); b.tabIndex = on ? 0 : -1; }); }
    wrap.addEventListener('keydown', function (e) {
      if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
      var i = btns.indexOf(document.activeElement); if (i < 0) return;
      i = (i + (e.key === 'ArrowRight' ? 1 : -1) + btns.length) % btns.length; btns[i].focus(); btns[i].click();
    });
    sync();
    return { el: wrap, get: function () { return val; }, set: function (v) { val = v; sync(); } };
  };

  /** Result cards: copy / regenerate / edit / save (/ favourite) with optional char limit. */
  ui.results = function (o) {
    var wrap = el('div', { class: 'results' });
    var items = [];
    function norm(x) { return typeof x === 'string' ? { text: x } : x; }
    function savedState(it) { return CH.Saved.find(o.type, it.text); }

    function build(it, idx) {
      var card = el('article', { class: 'result', style: { '--i': Math.min(idx, 12) } });
      var body = el('div', { class: 'result-body' + (o.big ? ' big' : '') + (o.mono ? ' mono' : '') });
      var meta = el('div', { class: 'result-meta' });
      var actions = el('div', { class: 'result-actions' });
      var editing = false, ta = null;

      function paint() {
        body.textContent = it.text;
        CH.clear(meta);
        if (o.limit) {
          var n = it.text.length;
          meta.appendChild(el('span', { class: 'counter ' + (n > o.limit ? 'bad' : n > o.limit * .92 ? 'warn' : '') }, n + '/' + o.limit));
        }
        if (o.metaOf) [].concat(o.metaOf(it) || []).forEach(function (m) { meta.appendChild(m && m.nodeType ? m : el('span', null, m)); });
        paintActions();
      }
      function act(name, label, ic, fn, cls) {
        var b = el('button', { type: 'button', class: 'act' + (cls ? ' ' + cls : ''), 'aria-label': label + (o.label ? ' ' + o.label : '') }, icon(ic), el('span', null, name));
        b.addEventListener('click', fn); return b;
      }
      function paintActions() {
        CH.clear(actions);
        var sv = savedState(it);
        actions.appendChild(act('Copy', 'Copy', 'copy', function (e) {
          var b = e.currentTarget; CH.copy(it.text).then(function (ok) { if (ok) { b.classList.add('ok'); setTimeout(function () { b.classList.remove('ok'); }, 1200); } });
        }, 'keep'));
        if (o.regen) actions.appendChild(act('Regenerate', 'Regenerate', 'refresh', function () {
          var n = norm(o.regen(it, idx)); if (!n) return;
          it = n; items[idx] = n; editing = false;
          if (ta && ta.parentNode) ta.replaceWith(body);
          paint();
          card.style.animation = 'none'; void card.offsetWidth; card.style.animation = '';
        }));
        actions.appendChild(act(editing ? 'Done' : 'Edit', 'Edit', editing ? 'check' : 'edit', function () {
          if (!editing) {
            editing = true; ta = el('textarea', { class: 'textarea result-edit', 'aria-label': 'Edit text' }); ta.value = it.text;
            if (o.limit) ta.addEventListener('input', function () { it.text = ta.value; CH.clear(meta); var n = it.text.length; meta.appendChild(el('span', { class: 'counter ' + (n > o.limit ? 'bad' : '') }, n + '/' + o.limit)); });
            body.replaceWith(ta); ta.focus(); paintActions();
          } else {
            it.text = ta.value; items[idx] = it; editing = false; ta.replaceWith(body); paint();
          }
        }, editing ? 'on' : ''));
        if (o.favorite) actions.appendChild(act(sv && sv.fav ? 'Favorited' : 'Favorite', 'Favorite', 'star', function () {
          var cur = savedState(it);
          if (cur) { CH.Saved.update(cur.id, { fav: !cur.fav }); CH.toast(cur.fav ? 'Removed from favorites' : 'Added to favorites'); }
          else { CH.Saved.add({ type: o.type, title: (o.titleOf ? o.titleOf(it) : it.text).slice(0, 60), body: it.text, data: it.data, fav: true }); CH.toast('Added to favorites'); }
          paintActions();
        }, sv && sv.fav ? 'on' : ''));
        actions.appendChild(act(sv ? 'Saved' : 'Save', 'Save', 'save', function () {
          var r = CH.Saved.add({ type: o.type, title: (o.titleOf ? o.titleOf(it) : it.text).slice(0, 60), body: it.text, data: it.data });
          CH.toast(r.dupe ? 'Already in Saved Creations' : 'Saved to your library'); paintActions();
        }, sv ? 'on' : ''));
        if (o.extra) [].concat(o.extra(it, idx) || []).forEach(function (b) { actions.appendChild(b); });
      }
      var lbl = it.label || o.label; if (lbl) card.appendChild(el('div', { class: 'result-label' }, lbl));
      card.appendChild(body);
      card.appendChild(el('div', { class: 'result-foot' }, meta, actions));
      paint();
      return card;
    }
    function render() {
      CH.clear(wrap);
      items.forEach(function (it, i) { wrap.appendChild(build(it, i)); });
    }
    return {
      el: wrap,
      set: function (arr) { items = arr.map(norm); render(); },
      items: function () { return items.map(function (i) { return i; }); },
      count: function () { return items.length; }
    };
  };

  /* ======================================================================
     Router / page loading
     ====================================================================== */
  var pages = CH.pages = {};
  CH.page = function (id, fn) { pages[id] = fn; };
  var loaded = {};
  function loadScript(src) {
    if (loaded[src]) return loaded[src];
    return (loaded[src] = new Promise(function (res, rej) {
      var s = document.createElement('script'); s.src = src; s.async = true;
      s.onload = res; s.onerror = function () { delete loaded[src]; rej(new Error('Could not load ' + src)); };
      document.head.appendChild(s);
    }));
  }
  CH.loadScript = loadScript;
  var cssLoaded = {};
  function loadCss(href) {
    if (cssLoaded[href]) return cssLoaded[href];
    return (cssLoaded[href] = new Promise(function (res) {
      var l = document.createElement('link'); l.rel = 'stylesheet'; l.href = href;
      l.onload = res; l.onerror = res; document.head.appendChild(l);   // never block the page on a stylesheet
    }));
  }
  CH.loadCss = loadCss;

  var view = $('#view'), cleanup = null, navToken = 0, first = true;

  function parseHash() {
    var h = location.hash.replace(/^#\/?/, '').split('?')[0];
    var parts = h.split('/').filter(Boolean);
    return { id: parts[0] || 'home', params: parts.slice(1) };
  }
  function route() {
    var p = parseHash(), r = byId[p.id];
    var token = ++navToken;
    if (cleanup) { try { cleanup(); } catch (e) {} cleanup = null; }
    closeNav();
    setActive(r ? r.id : null);
    if (!r) { mount(null, p, token); return; }
    var jobs = [];
    if (!pages[r.id]) jobs.push(loadScript('js/pages/' + r.id + '.js'));
    (r.deps || []).forEach(function (d) { jobs.push(loadScript(d)); });
    if (r.css) jobs.push(loadCss(r.css));
    var need = jobs.length > 0;
    var slow = setTimeout(function () { if (token === navToken && need) view.setAttribute('aria-busy', 'true'); }, 120);
    Promise.all(jobs).then(function () {
      clearTimeout(slow); if (token !== navToken) return; mount(r, p, token);
    }).catch(function (err) {
      clearTimeout(slow); if (token !== navToken) return;
      CH.clear(view); view.setAttribute('aria-busy', 'false');
      view.appendChild(ui.callout('bad', el('strong', null, 'Couldn’t load this page. '), 'Check your connection and reload. (' + err.message + ')'));
    });
  }
  function mount(r, p, token) {
    var lvl = html_fx();
    if (document.startViewTransition && lvl === 'full' && !first) { document.startViewTransition(function () { doMount(r, p, token); }); return; }
    doMount(r, p, token);
  }
  function html_fx() { return root.getAttribute('data-fx'); }
  function doMount(r, p, token) {
    CH.clear(view); view.setAttribute('aria-busy', 'false');
    view.className = 'view enter';
    document.title = (r && r.id !== 'home' ? r.title + ' — ' : '') + 'CordX by Wraith';
    try {
      if (!r) notFound(p);
      else cleanup = pages[r.id](view, { params: p.params, route: r }) || null;
    } catch (e) {
      console.error(e);
      CH.clear(view); view.appendChild(ui.callout('bad', el('strong', null, 'Something went wrong rendering this page. '), e.message));
    }
    observeReveals(view);
    window.scrollTo(0, 0);
    if (!first) { try { view.focus({ preventScroll: true }); } catch (e) {} }
    first = false;
    document.dispatchEvent(new CustomEvent('ch:route', { detail: r ? r.id : '404' }));
  }
  function notFound() {
    view.appendChild(ui.pageHead({ icon: 'search', title: 'Page not found', desc: 'That page doesn’t exist — but the tool you want probably does.' }));
    view.appendChild(el('div', { class: 'row' }, ui.btn('Search tools', { kind: 'primary', icon: 'search', onclick: openSearch }), ui.btn('Go home', { href: '#/home', icon: 'home' })));
  }

  /* Scroll-reveal: IntersectionObserver, disabled in "off" mode. */
  var io = null;
  function observeReveals(scope) {
    var els = CH.$$('.reveal', scope); if (!els.length) return;
    if (root.getAttribute('data-fx') === 'off' || !('IntersectionObserver' in window)) { els.forEach(function (e) { e.classList.add('in'); }); return; }
    if (!io) io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); } });
    }, { rootMargin: '0px 0px -6% 0px', threshold: 0.06 });
    els.forEach(function (e, i) { e.style.setProperty('--d', Math.min(i % 6, 5)); io.observe(e); });
    // Safety net: never leave content hidden if the observer stalls.
    setTimeout(function () { els.forEach(function (e) { if (!e.classList.contains('in') && e.getBoundingClientRect().top < innerHeight) e.classList.add('in'); }); }, 900);
  }
  CH.observeReveals = observeReveals;

  /* ======================================================================
     Navigation
     ====================================================================== */
  var nav = $('#nav');
  function buildNav() {
    CH.clear(nav);
    GROUPS.forEach(function (g) {
      var items = ROUTES.filter(function (r) { return r.group === g; });
      nav.appendChild(el('div', { class: 'nav-group' }, el('div', { class: 'nav-label' }, g),
        items.map(function (r) {
          var a = el('a', { class: 'nav-link', href: '#/' + r.id, dataset: { id: r.id } }, icon(r.icon), el('span', null, r.title));
          if (r.id === 'saved') { var n = CH.Saved.all().length; a.appendChild(el('span', { class: 'nav-badge', id: 'saved-count', hidden: n ? null : true }, n)); }
          if (r.id === 'pro') a.appendChild(el('span', { class: 'nav-badge' }, 'Soon'));
          return a;
        })));
    });
  }
  function setActive(id) {
    CH.$$('.nav-link', nav).forEach(function (a) { if (a.dataset.id === id) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
  }
  function updateSavedCount() {
    var b = $('#saved-count'); if (!b) return; var n = CH.Saved.all().length; b.textContent = n; b.hidden = !n;
  }
  document.addEventListener('ch:saved', updateSavedCount);

  var menuBtn = $('#menu-btn'), scrim = $('#scrim');
  function openNav() { document.body.classList.add('nav-open'); menuBtn.setAttribute('aria-expanded', 'true'); var a = $('.nav-link[aria-current]', nav) || $('.nav-link', nav); if (a) a.focus({ preventScroll: true }); }
  function closeNav() { if (!document.body.classList.contains('nav-open')) return; document.body.classList.remove('nav-open'); menuBtn.setAttribute('aria-expanded', 'false'); }
  menuBtn.addEventListener('click', function () { document.body.classList.contains('nav-open') ? (closeNav(), menuBtn.focus()) : openNav(); });
  scrim.addEventListener('click', closeNav);

  /* ======================================================================
     Global search (palette)
     ====================================================================== */
  var pal = $('#palette'), palInput = $('#pal-input'), palList = $('#pal-list'), prevFocus = null, results = [], sel = 0;
  var isMac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
  $('#kbd-hint').textContent = isMac ? '⌘ K' : 'Ctrl K';

  function index() {
    var out = ROUTES.map(function (r) { return { title: r.title, desc: r.desc, href: '#/' + r.id, icon: r.icon, kind: r.tool ? 'Tool' : 'Page', kw: r.kw || '' }; });
    out = out.concat(EXTRAS.map(function (e) { return Object.assign({ desc: e.kind }, e); }));
    CH.Saved.all().slice(0, 40).forEach(function (s) {
      out.push({ title: s.title || s.body.slice(0, 40), desc: 'Saved ' + s.type + ' · ' + s.body.slice(0, 60).replace(/\n/g, ' '), href: '#/saved', icon: 'bookmark', kind: 'Saved', kw: s.body });
    });
    return out;
  }
  function score(e, toks) {
    var t = e.title.toLowerCase(), d = (e.desc || '').toLowerCase(), k = (e.kw || '').toLowerCase(), total = 0;
    for (var i = 0; i < toks.length; i++) {
      var q = toks[i], s = 0;
      if (t.indexOf(q) === 0) s = 8; else if (t.indexOf(' ' + q) >= 0) s = 6; else if (t.indexOf(q) >= 0) s = 4;
      else if (k.indexOf(q) >= 0) s = 2.5; else if (d.indexOf(q) >= 0) s = 1.5;
      else if (q.length > 2 && subseq(q, t)) s = 1;
      if (!s) return 0; total += s;
    }
    return total + (e.kind === 'Tool' ? .4 : 0);
  }
  function subseq(q, t) { var i = 0; for (var j = 0; j < t.length && i < q.length; j++) if (t[j] === q[i]) i++; return i === q.length; }
  function highlight(text, toks) {
    var low = text.toLowerCase(), best = -1, len = 0;
    toks.forEach(function (q) { var i = low.indexOf(q); if (i >= 0 && (best < 0 || i < best)) { best = i; len = q.length; } });
    if (best < 0) return [text];
    return [text.slice(0, best), el('mark', null, text.slice(best, best + len)), text.slice(best + len)];
  }
  function runSearch() {
    var q = palInput.value.trim().toLowerCase(), toks = q.split(/\s+/).filter(Boolean), all = index();
    if (!toks.length) {
      results = all.filter(function (e) { return e.kind === 'Tool' || e.kind === 'Page'; }).concat(all.filter(function (e) { return e.kind === 'Saved'; }).slice(0, 4));
    } else {
      results = all.map(function (e) { return { e: e, s: score(e, toks) }; }).filter(function (x) { return x.s > 0; }).sort(function (a, b) { return b.s - a.s; }).slice(0, 30).map(function (x) { return x.e; });
    }
    sel = 0; paintResults(toks);
  }
  function paintResults(toks) {
    CH.clear(palList);
    if (!results.length) { palList.appendChild(el('li', { class: 'pal-empty' }, 'No matches for “' + palInput.value + '”. Try “embed”, “bio”, “rules”…')); return; }
    var lastKind = null;
    results.forEach(function (e, i) {
      if (e.kind !== lastKind) { lastKind = e.kind; palList.appendChild(el('li', { class: 'pal-group', role: 'presentation' }, e.kind === 'Tool' ? 'Tools' : e.kind === 'Page' ? 'Pages' : e.kind)); }
      var li = el('li', { class: 'pal-item', role: 'option', id: 'pal-' + i, 'aria-selected': i === sel ? 'true' : 'false', dataset: { i: i } },
        el('span', { class: 'pi-ic' }, icon(e.icon)), el('span', { class: 'pi-w' }, el('div', { class: 'pi-t' }, highlight(e.title, toks || [])), el('div', { class: 'pi-d' }, e.desc || '')));
      li.addEventListener('mousemove', function () { if (sel !== i) select(i, false); });
      li.addEventListener('click', function () { go(i); });
      palList.appendChild(li);
    });
    palInput.setAttribute('aria-activedescendant', 'pal-' + sel);
  }
  function select(i, scroll) {
    var items = CH.$$('.pal-item', palList); if (!items.length) return;
    sel = (i + items.length) % items.length;
    items.forEach(function (n, k) { n.setAttribute('aria-selected', k === sel ? 'true' : 'false'); });
    palInput.setAttribute('aria-activedescendant', 'pal-' + sel);
    if (scroll !== false) items[sel].scrollIntoView({ block: 'nearest' });
  }
  function go(i) {
    var e = results[i]; if (!e) return; closeSearch(true);
    if (location.hash === e.href) route(); else location.hash = e.href;
  }
  function openSearch() {
    if (!pal.hidden) return;
    prevFocus = document.activeElement; pal.hidden = false; document.body.style.overflow = 'hidden'; document.dispatchEvent(new CustomEvent('ch:overlay', { detail: true }));
    palInput.value = ''; runSearch(); palInput.focus();
  }
  function closeSearch(skipFocus) {
    if (pal.hidden) return; pal.hidden = true; document.dispatchEvent(new CustomEvent('ch:overlay', { detail: false })); document.body.style.overflow = document.body.classList.contains('nav-open') ? 'hidden' : '';
    if (!skipFocus && prevFocus && prevFocus.focus) prevFocus.focus();
  }
  CH.openSearch = openSearch;
  $('#search-open').addEventListener('click', openSearch);
  palInput.addEventListener('input', runSearch);
  pal.addEventListener('click', function (e) { if (e.target.hasAttribute('data-close')) closeSearch(); });
  palInput.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown') { e.preventDefault(); select(sel + 1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); select(sel - 1); }
    else if (e.key === 'Home') { e.preventDefault(); select(0); }
    else if (e.key === 'End') { e.preventDefault(); select(results.length - 1); }
    else if (e.key === 'Enter') { e.preventDefault(); go(sel); }
  });
  pal.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { e.preventDefault(); closeSearch(); }
    if (e.key === 'Tab') { var f = [palInput, $('.pal-top [data-close]', pal)]; var i = f.indexOf(document.activeElement); e.preventDefault(); f[(i + (e.shiftKey ? -1 : 1) + f.length) % f.length].focus(); }
  });
  document.addEventListener('keydown', function (e) {
    var t = e.target, typing = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT' || t.isContentEditable);
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); pal.hidden ? openSearch() : closeSearch(); }
    else if (e.key === '/' && !typing && pal.hidden && !e.ctrlKey && !e.metaKey) { e.preventDefault(); openSearch(); }
    else if (e.key === 'Escape') closeNav();
  });

  /* Scroll progress bar — a single transform, updated at most once per frame. */
  var spEl = $('#scroll-progress'), spTick = CH.raf(function () {
    var d = document.documentElement, max = d.scrollHeight - innerHeight;
    spEl.style.setProperty('--sp', max > 0 ? Math.min(1, scrollY / max).toFixed(4) : 0);
  });
  window.addEventListener('scroll', spTick, { passive: true }); window.addEventListener('resize', spTick);
  document.addEventListener('ch:route', spTick);

  /* ======================================================================
     Boot
     ====================================================================== */
  $('#year').textContent = new Date().getFullYear();
  applySettings();
  buildNav();
  window.addEventListener('hashchange', route);
  if (!location.hash) history.replaceState(null, '', '#/home');
  route();

  // Heavy visual effects are loaded after first paint, only when the level allows.
  function loadFx() { loadScript('js/fx.js').then(function () { return loadScript('js/theme-fx.js'); }).catch(function () {}); }
  if ('requestIdleCallback' in window) requestIdleCallback(loadFx, { timeout: 1800 }); else setTimeout(loadFx, 600);
})();
