/* Home — CordX by Wraith.
   Hero: extruded 3D lettering that becomes whatever you type · pick an "interface" (Wraith / Optic / Speed / Claw) ·
   paper-style stickers and phrases that teleport every moment · the username prompt.
   Then: ribbons → pinned 3D orbit of the tools → sticker board → live name wall → tool index → numbers → bento → swirl-eye CTA. */
CH.page('home', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, G = CH.usernameGen, A = CH.art, clamp = CH.clamp, CORDX = window.CORDX;
  var html = document.documentElement, cleanups = [], timers = [];
  function full() { return html.getAttribute('data-fx') === 'full'; }
  function fxOn() { return html.getAttribute('data-fx') !== 'off'; }
  function fine() { return window.matchMedia && matchMedia('(pointer: fine)').matches; }
  function theme() { return html.getAttribute('data-theme') || 'wraith'; }
  function on(target, ev, fn, opt) { target.addEventListener(ev, fn, opt); cleanups.push(function () { target.removeEventListener(ev, fn, opt); }); }
  function later(fn, ms) { var t = setTimeout(fn, ms); timers.push(t); return t; }
  function rnd(a, b) { return a + Math.random() * (b - a); }

  root.classList.add('home-wide');
  var home = el('div', { class: 'home' }); root.appendChild(home);
  var tools = CH.routes.filter(function (r) { return r.tool; });
  var heroVisible = true, hovering = false;

  /* =====================================================================
     HERO — 3D lettering
     ===================================================================== */
  var ROT = [-5, 4, -3, 6, -5, 3, -4, 5, -3, 4, -5, 3, -4, 6, -3, 4], Z = [34, -8, 46, 6, 28, -18, 40, 0, 30, -12, 44, 8, 26, -16, 36, 2];
  var word = el('div', { class: 'word3d', 'aria-hidden': 'true' }), cur3d = '', base3d = 'CORDX', holdTimer = 0;
  function setWord(text) {
    var t = String(text || '').toUpperCase().replace(/\s+/g, ' ').trim().slice(0, 16) || 'CORDX';
    if (t === cur3d) return; cur3d = t;
    word.style.setProperty('--n', Math.max(t.length, 4));
    CH.clear(word);
    Array.from(t).forEach(function (c, i) {
      word.appendChild(el('span', { class: 'ch' + (c === ' ' ? ' sp' : ''), 'data-c': c, 'data-m': String(i % 6), style: { '--i': i, '--r': ROT[i % 16] + 'deg', '--z': Z[i % 16] + 'px', '--bd': (5 + (i % 3)) + 's' } }, el('span', { class: 'face' }, c)));
    });
  }
  function showTemp(t, ms) { setWord(t); clearTimeout(holdTimer); if (ms) holdTimer = setTimeout(function () { setWord(base3d); }, ms); }
  cleanups.push(function () { clearTimeout(holdTimer); });
  setWord('CORDX');

  function spark(cls) { var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); s.setAttribute('viewBox', '0 0 40 40'); s.setAttribute('class', 'h-spark ' + cls); s.setAttribute('aria-hidden', 'true'); s.innerHTML = '<path d="M20 0c1.2 10.8 8.2 18.8 20 20-11.8 1.2-18.8 9.2-20 20C18.8 29.2 11.8 21.2 0 20 11.8 18.8 18.8 10.8 20 0z"/>'; return s; }

  /* ---- paper stickers that teleport between angles ---- */
  var stage = el('div', { class: 'stk-stage', 'aria-hidden': 'true' });
  var stkIdx = Math.floor(Math.random() * 4), curStk = null;
  function newSticker() {
    var d = el('div', { class: 'stk' }, A.character(theme(), stkIdx));
    d.style.setProperty('--sr', rnd(-9, 9).toFixed(1) + 'deg'); d.style.setProperty('--sx', rnd(-26, 0).toFixed(0) + 'px'); d.style.setProperty('--sy', rnd(-8, 12).toFixed(0) + 'px');
    return d;
  }
  function swapSticker(instant) {
    var nx = newSticker(), old = curStk; stkIdx++;
    if (!instant && fxOn()) nx.classList.add('in');
    stage.appendChild(nx); nx.classList.add('cur'); curStk = nx;
    if (old) { old.classList.remove('cur'); if (instant || !fxOn()) old.remove(); else { old.classList.add('out'); later(function () { old.remove(); }, 620); } }
    if (!instant && CH.themeFx && fxOn()) { var r = stage.getBoundingClientRect(); if (r.bottom > 0 && r.top < innerHeight) CH.themeFx.sparkBurst(r.left + r.width * (.3 + Math.random() * .4), r.top + r.height * (.2 + Math.random() * .5), 7, 3.4, -.005, true); }
  }
  var badgeA = el('div', { class: 'h-badge b1', 'aria-hidden': 'true' }), badgeB = el('div', { class: 'h-badge b2', 'aria-hidden': 'true' });
  var cycle = 0;
  function cycleStickers() { cycle = setTimeout(function () { if (heroVisible && !document.hidden && !hovering) swapSticker(false); cycleStickers(); }, 1500); }
  stage.addEventListener('pointerenter', function () { hovering = true; }); stage.addEventListener('pointerleave', function () { hovering = false; });
  cleanups.push(function () { clearTimeout(cycle); timers.forEach(clearTimeout); });

  /* ---- tape labels that teleport (new phrase, new spot, new tilt) ---- */
  var TOOLS_TXT = ['Embed builder', 'Bio lab', 'Usernames', 'Roles & rules', 'Channel layouts', 'Templates', 'Announcements', 'Server ideas'];
  var ZONES = [{ l: [0, 7], t: [14, 38] }, { l: [3, 13], t: [66, 88] }, { l: [66, 72], t: [-2, 8] }, { l: [20, 30], t: [100, 112] }];
  function pool() { return TOOLS_TXT.concat((CORDX.themes[theme()] || CORDX.themes.wraith).phrases).map(function (s) { return s.toUpperCase(); }); }
  function tapeText(n) {
    var p = pool(), shown = CH.$$('.tape', hero).map(function (x) { return x.textContent; }), choices = p.filter(function (x) { return shown.indexOf(x) < 0; });
    n.textContent = choices[Math.floor(Math.random() * choices.length)] || p[0];
    var z = ZONES[+n.dataset.z]; n.style.left = n.style.right = '';
    n.style.left = rnd(z.l[0], z.l[1]).toFixed(1) + '%';
    n.style.top = rnd(z.t[0], z.t[1]).toFixed(1) + '%'; n.style.setProperty('--tr', rnd(-12, 12).toFixed(1) + 'deg');
    n.classList.toggle('accent', Math.random() < .35);
  }
  function teleport(n) {
    if (!fxOn()) return;
    later(function () {
      if (heroVisible && !document.hidden) {
        n.classList.add('tp-out');
        later(function () { tapeText(n); n.classList.remove('tp-out'); n.classList.add('tp-in'); later(function () { n.classList.remove('tp-in'); }, 360); }, 200);
      }
      teleport(n);
    }, rnd(1300, 2100));
  }

  /* ---- interface picker ---- */
  var themeRow = el('div', { class: 'th-row', role: 'radiogroup', 'aria-label': 'Choose your interface' }, CORDX.themeOrder.map(function (id) {
    var T = CORDX.themes[id], b = el('button', { type: 'button', class: 'th-card', role: 'radio', 'data-t': id, 'aria-checked': 'false' },
      el('span', { class: 'th-ic' }, A.badge(id, A.badgeFor[id][0])), el('span', { class: 'th-tx' }, el('b', null, T.label), el('small', null, T.alias || 'Default'), el('em', null, T.tag)));
    b.addEventListener('click', function () { CH.settings.set({ theme: id }); if (CH.themeFx) CH.themeFx.hitEl(b); });
    return b;
  }));
  on(themeRow, 'keydown', function (e) {
    var k = e.key; if (['ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp'].indexOf(k) < 0) return; e.preventDefault();
    var i = CORDX.themeOrder.indexOf(theme()); i = (i + (k === 'ArrowRight' || k === 'ArrowDown' ? 1 : -1) + CORDX.themeOrder.length) % CORDX.themeOrder.length;
    CH.settings.set({ theme: CORDX.themeOrder[i] }); var c = themeRow.querySelector('[data-t="' + CORDX.themeOrder[i] + '"]'); if (c) c.focus();
  });

  /* ---- the username prompt ---- */
  var input = el('input', { id: 'hp-in', type: 'text', placeholder: 'Type a name, a word, a vibe…', maxlength: '40', autocomplete: 'off', spellcheck: 'false', enterkeyhint: 'go' });
  var KIND_OPTS = [['random', 'Surprise me'], ['gamer', 'Gamer'], ['clean', 'Clean'], ['og', 'OG'], ['dark', 'Dark'], ['anime', 'Anime'], ['funny', 'Funny'], ['developer', 'Dev'], ['aesthetic', 'Aesthetic']];
  var kind = 'random';
  var kindChips = ui.chips({ label: 'Username style', sm: true, value: 'random', options: KIND_OPTS.map(function (k) { return { value: k[0], label: k[1] }; }), onChange: function (v) { kind = v; if (results.children.length) run(); } });
  var results = el('div', { class: 'h-results', 'aria-live': 'polite' }), lastForm = null, typeT = 0;

  function formFromInput() {
    var words = input.value.trim().split(/[\s,]+/).filter(Boolean);
    return { kind: kind, name: words[0] || '', nickname: words[1] || '', word: words[2] || '', numbers: '', chars: '', interests: words.slice(3).join(','), theme: '', min: 3, max: 16, valid: true, numMode: 'auto', caseMode: 'auto', decor: true };
  }
  function run() {
    clearTimeout(typeT); lastForm = formFromInput();
    var items = G.generate(lastForm, 8);
    CH.clear(results);
    items.forEach(function (it, i) {
      var name = it.text, disp = (it.data && it.data.display) || name, saved = CH.Saved.find('username', name);
      var tile = el('div', { class: 'h-tile', style: { '--i': i }, tabindex: '0', role: 'button', 'aria-label': 'Preview ' + name + ' in 3D' },
        el('span', { class: 'nm' }, name), el('span', { class: 'meta' }, disp !== name ? 'Display: ' + disp : name.length + ' characters · valid handle'));
      var acts = el('div', { class: 'acts' });
      var cp = el('button', { type: 'button', class: 'act', 'aria-label': 'Copy ' + name }, icon('copy'), el('span', null, 'Copy'));
      cp.addEventListener('click', function (e) { e.stopPropagation(); CH.copy(name); });
      var sv = el('button', { type: 'button', class: 'act' + (saved ? ' on' : ''), 'aria-label': 'Save ' + name }, icon('star'), el('span', null, saved ? 'Saved' : 'Save'));
      sv.addEventListener('click', function (e) { e.stopPropagation(); CH.Saved.add({ type: 'username', title: name, body: name }); CH.toast('Saved ' + name); sv.classList.add('on'); sv.lastChild.textContent = 'Saved'; });
      acts.appendChild(cp); acts.appendChild(sv); tile.appendChild(acts);
      var show = function () { base3d = disp.replace(/[^A-Za-z0-9._-]/g, ''); showTemp(base3d, 0); };
      tile.addEventListener('mouseenter', function () { if (fine()) show(); }); tile.addEventListener('click', show);
      tile.addEventListener('keydown', function (e) { if (e.key === 'Enter') show(); });
      results.appendChild(tile);
      if (i === 0) { base3d = disp.replace(/[^A-Za-z0-9._-]/g, ''); setWord(base3d); }
    });
    var more = el('div', { class: 'h-more' },
      ui.btn('More like these', { icon: 'refresh', sm: true, onclick: run }),
      ui.btn('Fine-tune in the generator', { icon: 'arrowRight', sm: true, kind: 'ghost', onclick: function () {
        var f = lastForm, prev = CH.Store.get('form:username', {});
        CH.Store.set('form:username', Object.assign({}, prev, { kind: f.kind, name: f.name, nickname: f.nickname, word: f.word, interests: f.interests }));
        location.hash = '#/username';
      } }));
    results.appendChild(more);
    if (!items.length) results.insertBefore(el('p', { class: 'hint', style: { gridColumn: '1/-1', textAlign: 'center' } }, 'Nothing fit those limits — try a shorter word.'), more);
  }
  var goBtn = el('button', { type: 'submit', class: 'btn btn-primary h-go' }, icon('sparkle'), el('span', null, 'Generate'));
  var form = el('form', { class: 'h-prompt', role: 'search', 'aria-label': 'Username generator', novalidate: true, onsubmit: function (e) { e.preventDefault(); run(); if (CH.themeFx && !e.submitter) CH.themeFx.hitEl(goBtn); } },
    el('label', { class: 'h-prompt-label', for: 'hp-in' }, 'What ', el('span', { class: 'serif grad-serif' }, 'username'), ' do you want to make?'),
    el('div', { class: 'h-field' }, input, goBtn),
    el('div', { class: 'h-kinds' }, kindChips.el),
    el('div', { class: 'h-try' }, 'Try ', ['luna', 'night owl', 'fox mage', 'kai 7'].map(function (t, i) { var b = el('button', { type: 'button' }, t); b.addEventListener('click', function () { input.value = t; base3d = t; setWord(t); run(); }); return [i ? ' · ' : '', b]; }), ' — or just press Generate.'));
  on(input, 'input', function () { clearTimeout(typeT); typeT = setTimeout(function () { var v = input.value.replace(/[^\p{L}\p{N}\s._-]/gu, ''); base3d = v.trim() ? v.trim() : 'CORDX'; setWord(base3d); }, 90); });
  cleanups.push(function () { clearTimeout(typeT); });

  var tapes = [0, 1, 2, 3].map(function (z) { return el('div', { class: 'tape', 'data-z': z, 'aria-hidden': 'true' }); });
  var hero = el('section', { class: 'h-hero', 'aria-labelledby': 'h-title' },
    el('div', { class: 'h-grid', 'aria-hidden': 'true' }),
    el('div', { class: 'h-top' }, el('span', { class: 'pill pill-lime' }, el('i'), 'CordX'), el('span', { class: 'pill' }, 'by Wraith · for Discord creators')),
    spark('s1'), spark('s2'), spark('s3'), spark('s4'),
    el('h1', { class: 'h-title', id: 'h-title', 'aria-label': 'CordX — your Discord identity' },
      el('div', { class: 'h-title-wrap' }, tapes, badgeA, badgeB, el('div', { class: 'word-stage' }, word), stage),
      el('span', { class: 'h-sub', 'aria-hidden': 'true' }, 'your ', el('span', { class: 'serif grad-serif' }, 'Discord'), ' identity')),
    el('p', { class: 'h-lede' }, 'A live embed builder, bios, usernames, rules, roles and channel layouts — wrapped in an interface you pick. Type below and watch the letters become your name.'),
    el('div', { class: 'th-wrap' }, el('div', { class: 'label th-label' }, 'Pick your interface'), themeRow),
    form, results,
    el('a', { class: 'h-scroll', href: '#orbit', onclick: function (e) { e.preventDefault(); var t = document.getElementById('orbit'); if (t) t.scrollIntoView({ behavior: full() ? 'smooth' : 'auto' }); } }, el('i'), 'Scroll'));
  home.appendChild(hero);

  function paintTheme() {
    var t = theme();
    CH.clear(stage); curStk = null; stkIdx = Math.floor(Math.random() * 4); swapSticker(true);
    var bf = A.badgeFor[t]; CH.clear(badgeA); CH.clear(badgeB); badgeA.appendChild(A.badge(t, bf[0])); badgeB.appendChild(A.badge(t, bf[1]));
    CH.$$('.th-card', themeRow).forEach(function (c) { var is = c.dataset.t === t; c.setAttribute('aria-checked', String(is)); c.tabIndex = is ? 0 : -1; });
    tapes.forEach(function (n) { tapeText(n); });
  }
  var lastTheme = theme();
  on(document, 'ch:settings', function () { if (theme() !== lastTheme) { lastTheme = theme(); paintTheme(); } });
  paintTheme(); tapes.forEach(function (n, i) { later(function () { teleport(n); }, i * 350); }); cycleStickers();
  if ('IntersectionObserver' in window) { var hio = new IntersectionObserver(function (en) { heroVisible = en[0].isIntersecting; }); hio.observe(hero); cleanups.push(function () { hio.disconnect(); }); }

  /* =====================================================================
     RIBBONS
     ===================================================================== */
  function band(items, cls, speed) {
    var mk = function (hide) { return items.map(function (t) { return el('span', hide ? { 'aria-hidden': 'true' } : null, t.indexOf('*') === 0 ? el('span', { class: 'serif' }, t.slice(1)) : t); }); };
    return el('div', { class: 'band ' + cls, role: 'presentation' }, el('div', { class: 'track', style: { '--sp': speed + 's' } }, mk(false), mk(true)));
  }
  home.appendChild(el('div', { class: 'ribbons', 'aria-hidden': 'true' },
    band(['Embeds', '*webhooks', 'Bios', '*unicode', 'Usernames', '*og', 'Rules', '*tone', 'Roles', '*hierarchy', 'Channels'], 'a', 46),
    band(['CordX', '*by Wraith', 'Templates', '*ready-made', 'Announcements', '*timestamps', 'Bot directory', '*safe', 'Server ideas'], 'b', 52)));

  /* =====================================================================
     ORBIT — pinned 3D carousel (full mode, ≥ 900px); a plain grid everywhere else
     ===================================================================== */
  function embedDemo() { return [CH.preview.message({ username: 'CordX Bot', embeds: [{ title: 'Welcome to Nebula', description: 'Read the **rules**, grab your roles and say hi.', color: 0x7c6cff, fields: [{ name: 'Online', value: '312', inline: true }, { name: 'Voice', value: '18', inline: true }], footer: { text: 'Nebula Lounge' } }], components: [{ type: 1, components: [{ type: 2, style: 5, label: 'Rules', url: 'https://example.com' }] }] }, { compact: true })]; }
  function nameDemo() { return G.generate({ kind: 'random', name: '', nickname: '', word: '', numbers: '', chars: '', interests: '', theme: '', min: 4, max: 12, valid: true, numMode: 'auto', caseMode: 'auto', decor: true }, 4).slice(0, 4).map(function (x) { return el('div', { class: 'pn-name' }, x.text); }); }
  function bioDemo() { return [el('div', { class: 'pn-bio' }, 'night shift energy · lo-fi on loop\nrhythm games, ramen, 3am ideas'), el('div', { class: 'pn-count' }, '74/190')]; }
  function rulesDemo() { return [['🤝', 'Be respectful', 'No harassment or hate.'], ['🔞', 'Keep it safe for work', 'No NSFW or gore.'], ['📢', 'No unsolicited ads', 'Ask staff first.'], ['🛡️', 'Listen to staff', 'Appeal in a ticket.']].map(function (r) { return el('div', { class: 'pn-rule' }, el('span', null, r[0]), el('div', null, el('b', null, r[1]), el('div', null, r[2]))); }); }
  function rolesDemo() { return [['Owner', '#ef4444'], ['Admin', '#f97316'], ['Moderator', '#eab308'], ['Supporter', '#a855f7'], ['Regular', '#3b82f6'], ['Member', '#99aab5']].map(function (r) { return el('div', { class: 'pn-role', style: { color: r[1] } }, el('i', { style: { background: r[1] } }), r[0]); }); }
  function chanDemo() { return [el('div', { class: 'pn-tree' }, el('b', null, 'START HERE'), '# 👋┃welcome', el('br'), '# 📜┃rules', el('br'), '# 📢┃announcements', el('b', null, 'COMMUNITY'), '# 💬┃general', el('br'), '# 🎮┃looking-for-group', el('b', null, 'VOICE'), '🔊 Lounge · Hangout 1')]; }
  var PANELS = [
    { id: 'embeds', t: 'Embed Builder', d: 'Design rich embeds with a live Discord-style preview and export webhook JSON, discord.js, discord.py or cURL.', ic: 'embed', build: embedDemo },
    { id: 'username', t: 'Username Generator', d: 'Original names from your words, interests and theme — checked against Discord’s handle rules.', ic: 'at', build: nameDemo },
    { id: 'bio', t: 'Bio Generator', d: 'Fifteen styles, three lengths and Unicode fonts. Always within the 190-character limit.', ic: 'user', build: bioDemo },
    { id: 'rules', t: 'Server Rules', d: 'Pick a server type, strictness and tone. Get rules plus a staff and moderation policy.', ic: 'shield', build: rulesDemo },
    { id: 'roles', t: 'Role Generator', d: 'Themed role hierarchies with colours and least-privilege permission suggestions.', ic: 'tag', build: rolesDemo },
    { id: 'channels', t: 'Channel Layouts', d: 'Categories and channels for any server type, with topics, read-only hints and a setup guide.', ic: 'hash', build: chanDemo }
  ];
  var ring = el('div', { class: 'ring' });
  PANELS.forEach(function (p, i) {
    ring.appendChild(el('article', { class: 'panel' + (i === 0 ? ' on' : ''), style: { '--i': i }, 'aria-label': p.t },
      el('div', { class: 'panel-top' }, el('span', { class: 'ic' }, icon(p.ic)), el('b', null, p.t)),
      el('div', { class: 'panel-body' }, p.build()),
      el('div', { class: 'panel-link' }, ui.btn('Open ' + p.t, { href: '#/' + p.id, sm: true, kind: 'primary', icon: 'arrowRight' }))));
  });
  var oiT = el('h3', null, PANELS[0].t), oiD = el('p', null, PANELS[0].d), oiL = ui.btn('Open ' + PANELS[0].t, { href: '#/' + PANELS[0].id, kind: 'primary', icon: 'arrowRight' });
  var dots = el('div', { class: 'orbit-dots', 'aria-hidden': 'true' }, PANELS.map(function (_, i) { return el('i', { class: i === 0 ? 'on' : '' }); }));
  var orbit = el('section', { class: 'orbit h-sec', id: 'orbit' },
    el('div', { class: 'orbit-pin' },
      el('div', { class: 'orbit-head' },
        el('div', { class: 'sec-eyebrow' }, el('span', { class: 'pill' }, 'The toolkit')),
        el('h2', { class: 'sec-title' }, 'Six tools, ', el('span', { class: 'serif grad-serif' }, 'one orbit')),
        el('p', { class: 'sec-sub' }, 'Scroll to spin through what’s inside — every tool runs in your browser.'),
        el('div', { class: 'orbit-info', 'aria-live': 'polite' }, oiT, oiD, oiL, dots)),
      el('div', { class: 'orbit-stage' }, ring)));
  home.appendChild(orbit);

  var oCur = 0, oTarget = 0, oRaf = 0, oIdx = 0, oVisible = false;
  function orbitActive() { return full() && window.innerWidth >= 900; }
  function orbitMetrics() {
    var tb = parseFloat(getComputedStyle(html).getPropertyValue('--topbar-h')) || 60, r = orbit.getBoundingClientRect(), pin = innerHeight - tb;
    var span = Math.max(1, orbit.offsetHeight - pin), p = clamp((tb - r.top) / span, 0, 1), f = p * (PANELS.length - 1), s = Math.floor(f), t = f - s;
    t = clamp((t - .22) / .56, 0, 1); t = t * t * (3 - 2 * t);
    return Math.min(PANELS.length - 1, s + t);
  }
  function orbitFrame() {
    oRaf = 0;
    if (!orbitActive()) { ring.style.removeProperty('--ang'); return; }
    oCur += (oTarget - oCur) * .14;
    ring.style.setProperty('--ang', (-oCur * 60).toFixed(2) + 'deg');
    var idx = Math.round(oCur);
    if (idx !== oIdx) {
      oIdx = idx; var p = PANELS[idx];
      CH.$$('.panel', ring).forEach(function (n, i) { n.classList.toggle('on', i === idx); });
      CH.$$('i', dots).forEach(function (n, i) { n.classList.toggle('on', i === idx); });
      oiT.textContent = p.t; oiD.textContent = p.d; oiL.href = '#/' + p.id; oiL.lastChild.textContent = 'Open ' + p.t;
    }
    if (Math.abs(oTarget - oCur) > .002) oRaf = requestAnimationFrame(orbitFrame);
  }
  function orbitScroll() { if (!oVisible || !orbitActive()) return; oTarget = orbitMetrics(); if (!oRaf) oRaf = requestAnimationFrame(orbitFrame); }
  if ('IntersectionObserver' in window) { var oio = new IntersectionObserver(function (en) { oVisible = en[0].isIntersecting; if (oVisible) orbitScroll(); }, { rootMargin: '10% 0px' }); oio.observe(orbit); cleanups.push(function () { oio.disconnect(); }); } else oVisible = true;
  on(window, 'scroll', orbitScroll, { passive: true }); on(window, 'resize', orbitScroll);
  cleanups.push(function () { cancelAnimationFrame(oRaf); });

  /* =====================================================================
     STICKER BOARD — a portfolio of stickers for the active interface
     ===================================================================== */
  var board = el('div', { class: 'board', role: 'group', 'aria-label': 'Sticker board — drag the stickers around' }), zTop = 10;
  function phraseSticker(txt, i) { return el('div', { class: 'stk-art phrase p' + (i % 3) }, el('span', null, txt)); }
  function toolSticker(r) { return el('div', { class: 'stk-art toolstk' }, el('span', { class: 'ic' }, icon(r.icon)), el('b', null, r.title.replace(' Generator', '').replace('Discord ', ''))); }
  function buildBoard() {
    var t = theme(), T = CORDX.themes[t], items = [];
    for (var i = 0; i < A.count(t); i++) items.push({ n: A.character(t, i), w: 'lg' });
    A.badgeFor[t].forEach(function (k) { items.push({ n: A.badge(t, k), w: 'sm' }); });
    T.phrases.forEach(function (p, i) { items.push({ n: phraseSticker(p, i), w: 'ph' }); });
    ['embeds', 'username', 'bio', 'roles'].forEach(function (id) { items.push({ n: toolSticker(CH.routeById[id]), w: 'tool' }); });
    CH.clear(board);
    items.forEach(function (it, i) {
      var cols = 6, col = i % cols, row = Math.floor(i / cols), s = el('div', { class: 'sticker ' + it.w, tabindex: '0', role: 'img', 'aria-label': 'Sticker' }, it.n);
      s._x = 0; s._y = 0; s._r = rnd(-10, 10);
      s.style.left = (col * (100 / cols) + rnd(0, 4)).toFixed(1) + '%'; s.style.top = (row * 24 + rnd(0, 6)).toFixed(1) + '%';
      s.style.setProperty('--rot', s._r.toFixed(1) + 'deg'); s.style.animationDelay = (i * 40) + 'ms';
      drag(s); board.appendChild(s);
    });
  }
  function drag(s) {
    var sx = 0, sy = 0, ox = 0, oy = 0, active = false;
    s.addEventListener('pointerdown', function (e) { active = true; s.setPointerCapture(e.pointerId); sx = e.clientX; sy = e.clientY; ox = s._x; oy = s._y; s.classList.add('held'); s.style.zIndex = ++zTop; });
    s.addEventListener('pointermove', function (e) { if (!active) return; s._x = ox + e.clientX - sx; s._y = oy + e.clientY - sy; s.style.transform = 'translate(' + s._x + 'px,' + s._y + 'px) rotate(' + s._r + 'deg) scale(1.06)'; });
    function up(e) { if (!active) return; active = false; s.classList.remove('held'); s.style.transform = 'translate(' + s._x + 'px,' + s._y + 'px) rotate(' + s._r + 'deg)'; }
    s.addEventListener('pointerup', up); s.addEventListener('pointercancel', up);
  }
  on(document, 'ch:settings', function () { if (board.dataset.t !== theme()) { board.dataset.t = theme(); buildBoard(); } });
  board.dataset.t = theme(); buildBoard();
  home.appendChild(el('section', { class: 'h-sec' },
    el('div', { class: 'sec-eyebrow' }, el('span', { class: 'pill pill-lime' }, el('i'), 'Sticker pack')),
    el('h2', { class: 'sec-title' }, 'Your interface, ', el('span', { class: 'serif grad-serif' }, 'in stickers')),
    el('p', { class: 'sec-sub' }, 'Every interface comes with its own sticker set. Drag them around, or switch interface up top to swap the pack.'),
    el('div', { class: 'row', style: { justifyContent: 'center', marginTop: '18px' } }, ui.btn('Shuffle', { icon: 'refresh', sm: true, onclick: buildBoard }), ui.btn('Change interface', { icon: 'sparkle', sm: true, kind: 'ghost', onclick: function () { window.scrollTo({ top: 0, behavior: full() ? 'smooth' : 'auto' }); } })),
    board));

  /* =====================================================================
     NAME WALL
     ===================================================================== */
  function wallNames(n) { return G.generate({ kind: 'random', name: '', nickname: '', word: '', numbers: '', chars: '', interests: '', theme: '', min: 4, max: 13, valid: true, numMode: 'auto', caseMode: 'auto', decor: true }, n).map(function (x) { return x.text; }); }
  function wallRow(names) {
    var mk = function (hidden) { return names.map(function (n) { var b = el('button', { type: 'button', class: 'nchip', tabindex: hidden ? '-1' : null, 'aria-hidden': hidden ? 'true' : null, title: 'Click to copy' }, n); b.addEventListener('click', function () { CH.copy(n); }); return b; }); };
    return el('div', { class: 'row-t' }, el('div', { class: 'track' }, mk(false), mk(true)));
  }
  home.appendChild(el('section', { class: 'h-sec' },
    el('div', { class: 'sec-eyebrow' }, el('span', { class: 'pill' }, 'Live from the generator')),
    el('h2', { class: 'sec-title' }, 'Names that ', el('span', { class: 'serif grad-serif' }, 'don’t exist yet')),
    el('p', { class: 'sec-sub' }, 'Every chip was invented a moment ago. Click one to copy it — or type your own above.'),
    el('div', { class: 'wall' }, wallRow(wallNames(22)), wallRow(wallNames(22)))));

  /* =====================================================================
     TOOL INDEX
     ===================================================================== */
  home.appendChild(el('section', { class: 'h-sec' },
    el('div', { class: 'sec-eyebrow' }, el('span', { class: 'pill pill-lime' }, el('i'), 'Everything inside')),
    el('h2', { class: 'sec-title' }, 'Pick a ', el('span', { class: 'serif grad-serif' }, 'tool')),
    el('div', { class: 'h-tools' }, tools.map(function (r, i) {
      return el('a', { class: 'card tool-card h-tool tilt spot reveal', href: '#/' + r.id },
        el('span', { class: 'no', 'aria-hidden': 'true' }, ('0' + (i + 1)).slice(-2)), el('div', { class: 'tc-ic' }, icon(r.icon)),
        el('div', null, el('h3', null, r.title), el('p', null, r.desc)), el('span', { class: 'tc-go' }, 'Open', icon('arrowRight')));
    }))));

  /* =====================================================================
     NUMBERS
     ===================================================================== */
  var NUMS = [[tools.length, 'tools & generators'], [G.KINDS.length, 'username styles'], [15, 'bio styles'], [4, 'interfaces'], [10, 'server types'], [0, 'accounts needed']];
  var numsBox = el('div', { class: 'nums' }, NUMS.map(function (n) { return el('div', { class: 'num reveal' }, el('b', { 'data-to': n[0] }, String(n[0])), el('span', null, n[1])); }));
  home.appendChild(el('section', { class: 'h-sec' }, el('h2', { class: 'sec-title' }, 'By the ', el('span', { class: 'serif grad-serif' }, 'numbers')), numsBox));
  if ('IntersectionObserver' in window && fxOn()) {
    CH.$$('b', numsBox).forEach(function (b) { b.textContent = '0'; });
    var nio = new IntersectionObserver(function (en) {
      if (!en[0].isIntersecting) return; nio.disconnect(); var t0 = performance.now();
      (function tick(now) { var k = clamp((now - t0) / 1100, 0, 1), e = 1 - Math.pow(1 - k, 3); CH.$$('b', numsBox).forEach(function (b) { b.textContent = Math.round(+b.dataset.to * e); }); if (k < 1) requestAnimationFrame(tick); })(t0);
    }, { threshold: .4 });
    nio.observe(numsBox); cleanups.push(function () { nio.disconnect(); });
  }

  /* =====================================================================
     BENTO
     ===================================================================== */
  function code() { return el('pre', { class: 'code-mini viz' }, '{ ', el('span', { class: 'k' }, '"embeds"'), ': [{\n  ', el('span', { class: 'k' }, '"title"'), ': ', el('span', { class: 's' }, '"Welcome!"'), ',\n  ', el('span', { class: 'k' }, '"color"'), ': 5793266\n}] }'); }
  home.appendChild(el('section', { class: 'h-sec' },
    el('div', { class: 'sec-eyebrow' }, el('span', { class: 'pill' }, 'Built with care')),
    el('h2', { class: 'sec-title' }, 'Accurate, ', el('span', { class: 'serif grad-serif' }, 'private'), ' & fast'),
    el('div', { class: 'bento' },
      el('div', { class: 'card bt w3 spot reveal' }, el('h3', null, 'Honest about ', el('span', { class: 'serif grad-serif' }, 'Discord')), el('p', null, 'Every limit — 6,000 characters across embeds, 25 fields, who can send embeds, what buttons need a bot — is checked live and explained.'), el('div', { class: 'viz' }, el('div', { class: 'row-between', style: { marginBottom: '8px' } }, el('span', { class: 'label' }, 'Embed text budget'), el('span', { class: 'counter' }, '5,214 / 6,000')), el('div', { class: 'meter-big' }, el('i')))),
      el('div', { class: 'card bt w3 spot reveal' }, el('h3', null, 'Export ', el('span', { class: 'serif grad-serif' }, 'anything')), el('p', null, 'Webhook JSON, discord.js, discord.py and cURL — copy it or send it straight to a webhook.'), code()),
      el('div', { class: 'card bt w2 spot reveal' }, el('div', { class: 'lockviz' }, icon('lock')), el('h3', null, 'Private by default'), el('p', null, 'No accounts, no analytics. Your library lives in your browser.')),
      el('div', { class: 'card bt w2 spot reveal' }, el('h3', null, 'Fast ', el('span', { class: 'serif grad-serif' }, 'everywhere')), el('p', null, 'Tools load on demand. Phones get a lighter version automatically, and reduced-motion is respected.'), el('div', { class: 'tags viz' }, ['Lite mode', 'Reduced motion', 'Lazy tools'].map(function (t) { return el('span', { class: 'tag' }, t); }))),
      el('div', { class: 'card bt w2 spot reveal' }, el('h3', null, 'Yours to ', el('span', { class: 'serif grad-serif' }, 'keep')), el('p', null, 'Save anything, favourite it, export a backup, import it anywhere.'), el('div', { class: 'viz' }, ui.btn('Open library', { href: '#/saved', sm: true, icon: 'bookmark' }))))));
  var meters = CH.$$('.meter-big', home);
  if ('IntersectionObserver' in window) { var mio = new IntersectionObserver(function (en) { en.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('go'); mio.unobserve(e.target); } }); }); meters.forEach(function (m) { mio.observe(m); }); cleanups.push(function () { mio.disconnect(); }); } else meters.forEach(function (m) { m.classList.add('go'); });

  /* recent */
  var recent = CH.Saved.all().slice(0, 3);
  if (recent.length) home.appendChild(el('section', { class: 'h-sec' },
    el('div', { class: 'section-head' }, el('h2', null, 'Pick up where you left off'), ui.btn('Open library', { href: '#/saved', sm: true, kind: 'ghost', icon: 'arrowRight' })),
    el('div', { class: 'grid g3' }, recent.map(function (s) { return el('a', { class: 'card card-pad reveal spot', href: '#/saved' }, el('span', { class: 'tag' }, s.type), el('p', { style: { marginTop: '10px', color: 'var(--text-2)', fontSize: '14px', display: '-webkit-box', WebkitLineClamp: '3', WebkitBoxOrient: 'vertical', overflow: 'hidden', whiteSpace: 'pre-wrap' } }, s.body.slice(0, 160))); }))));

  /* =====================================================================
     EYE CTA + wordmark
     ===================================================================== */
  var eye = el('section', { class: 'eye' },
    el('h2', null, 'Ready to ', el('em', null, 'ascend'), ' your server?'),
    el('p', null, 'Open the builder, drop in a template and post your first embed in minutes.'),
    el('div', { class: 'eye-art' }, el('div', { class: 'eye-swirl' }), el('div', { class: 'eye-swirl b' }),
      el('div', { class: 'eye-lens' }, el('a', { class: 'eye-cta', href: '#/embeds' }, 'Open the Embed Builder', el('i', null, icon('arrowRight'))))));
  home.appendChild(eye);
  home.appendChild(el('div', { class: 'h-wordmark', 'aria-hidden': 'true' }, 'CORDX'));
  home.appendChild(el('p', { class: 'h-by' }, 'by ', el('span', { class: 'serif grad-serif' }, 'Wraith'), ' · © ' + new Date().getFullYear() + ' · ', el('a', { href: '#/legal' }, 'Terms & Policies')));

  /* =====================================================================
     Pointer: hero parallax + swirl eye (rAF-throttled; 3D only in full mode)
     ===================================================================== */
  var pend = null, pRaf = 0;
  function pointerFrame() {
    pRaf = 0; var e = pend; if (!e || !full() || e.pointerType === 'touch') return;
    var hr = hero.getBoundingClientRect();
    if (e.clientY > hr.top - 100 && e.clientY < hr.bottom + 100) {
      var nx = clamp((e.clientX - (hr.left + hr.width / 2)) / (hr.width / 2), -1, 1), ny = clamp((e.clientY - (hr.top + hr.height * .3)) / (hr.height * .5), -1, 1);
      hero.style.setProperty('--px', nx.toFixed(3)); hero.style.setProperty('--py', ny.toFixed(3));
      word.classList.add('live'); word.style.setProperty('--ry', (nx * 11).toFixed(2) + 'deg'); word.style.setProperty('--rx', (-ny * 7).toFixed(2) + 'deg');
    }
    var er = eye.getBoundingClientRect();
    if (er.bottom > 0 && er.top < innerHeight) { eye.style.setProperty('--ex', clamp((e.clientX - (er.left + er.width / 2)) / (er.width / 2), -1, 1).toFixed(3)); eye.style.setProperty('--ey', clamp((e.clientY - (er.top + er.height / 2)) / (er.height / 2), -1, 1).toFixed(3)); }
  }
  on(document, 'pointermove', function (e) { pend = e; if (!pRaf) pRaf = requestAnimationFrame(pointerFrame); }, { passive: true });
  on(document.documentElement, 'mouseleave', function () { word.classList.remove('live'); word.style.removeProperty('--rx'); word.style.removeProperty('--ry'); hero.style.setProperty('--px', 0); hero.style.setProperty('--py', 0); });
  cleanups.push(function () { cancelAnimationFrame(pRaf); });

  return function () { cleanups.forEach(function (fn) { try { fn(); } catch (e) {} }); };
});
