/* Username Generator — original names built from word banks, invented pronounceable words and your own stems. */
CH.page('username', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, chance = CH.chance, range = CH.range;

  var G = CH.usernameGen, KINDS = G.KINDS, KIND_BY = G.KIND_BY, THEME = G.THEME, generate = G.generate, check = G.check;

  /* ---------------- UI ---------------- */
  var form = Object.assign({ kind: 'gamer', name: '', nickname: '', word: '', numbers: '', chars: '', interests: '', theme: '', min: 4, max: 14, valid: true, numMode: 'auto', caseMode: 'auto', decor: true, count: '12' }, CH.Store.get('form:username', {}));
  function persist() { CH.Store.set('form:username', form); }

  root.appendChild(ui.pageHead({ icon: 'at', title: 'Username Generator', desc: 'Original usernames made from your name, interests and theme. Names are generated on the spot — never picked from a fixed list.' }));

  var kindChips = ui.chips({ label: 'Username style', ex: true, value: form.kind, options: KINDS.map(function (k) { return { value: k.id, label: k.label, ex: k.ex }; }), onChange: function (v) { form.kind = v; persist(); } });
  function tf(key, label, ph, hint) { return ui.field({ label: label, value: form[key], placeholder: ph, hint: hint, onInput: function (v) { form[key] = v; persist(); } }); }
  var themeF = ui.field({ label: 'Theme', type: 'select', value: form.theme, options: [{ value: '', label: 'None' }].concat(Object.keys(THEME).map(function (k) { return { value: k, label: CH.cap(k) }; })), onInput: function (v) { form.theme = v; persist(); } });
  var minR = ui.range({ label: 'Shortest', min: 2, max: 20, value: form.min, onInput: function (v) { form.min = v; if (maxR && v > maxR.get()) maxR.set(v); persist(); } });
  var maxR = ui.range({ label: 'Longest', min: 3, max: 32, value: form.max, onInput: function (v) { form.max = v; if (v < minR.get()) minR.set(v); persist(); } });
  var validSw = ui.switch({ label: 'Discord-valid handle (a–z, 0–9, _ and .)', checked: form.valid, onChange: function (v) { form.valid = v; decorSw.el.style.display = v ? 'none' : ''; persist(); } });
  var decorSw = ui.switch({ label: 'Decorate display names (✦ ꒰ 「 ⛧)', checked: form.decor, onChange: function (v) { form.decor = v; persist(); } });
  decorSw.el.style.display = form.valid ? 'none' : '';
  var numF = ui.field({ label: 'Numbers', type: 'select', value: form.numMode, options: [{ value: 'auto', label: 'Auto (use mine if given)' }, { value: 'none', label: 'Never add numbers' }, { value: 'always', label: 'Always add a number' }, { value: 'leet', label: 'Leet-speak letters (4, 3, 1, 0)' }], onInput: function (v) { form.numMode = v; persist(); } });
  var caseF = ui.field({ label: 'Capitalisation', type: 'select', value: form.caseMode, options: [{ value: 'auto', label: 'Auto (best for the style)' }, { value: 'lower', label: 'lowercase' }, { value: 'pascal', label: 'PascalCase' }, { value: 'camel', label: 'camelCase' }, { value: 'snake', label: 'snake_case' }, { value: 'dot', label: 'dot.separated' }], onInput: function (v) { form.caseMode = v; persist(); } });
  var countF = ui.field({ label: 'How many', type: 'select', value: form.count, options: ['8', '12', '20', '30'], onInput: function (v) { form.count = v; persist(); } });

  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'What kind of username are you looking for?'), kindChips.el,
      el('div', { class: 'hint' }, 'The examples are only illustrations — every name is generated fresh.')),
    el('div', { class: 'form-section' }, el('h3', null, 'Make it yours'),
      el('div', { class: 'form-grid' }, tf('name', 'Name', 'Alex').el, tf('nickname', 'Nickname', 'lex').el, tf('word', 'Favorite word', 'ember').el, tf('numbers', 'Numbers', '7, 99, 2004', 'Comma-separated; optional.').el),
      tf('chars', 'Characters to use', '_ . ✦', 'Separators or decoration. Only _ and . are valid in a handle.').el,
      tf('interests', 'Interests', 'chess, synthwave, hiking').el, themeF.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Length'), minR.el, maxR.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Options'), validSw.el, decorSw.el, el('div', { class: 'form-grid' }, numF.el, caseF.el), countF.el),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate usernames', { kind: 'primary', icon: 'sparkle', onclick: run })));

  var results = ui.results({
    type: 'username', big: true, favorite: true, label: null, titleOf: function (it) { return it.text; },
    regen: function (it) { var f = Object.assign({}, form); if (it.data && it.data.kind && form.kind === 'random') f.kind = it.data.kind; return generate(Object.assign(f, { count: 1 }), 1)[0] || it; },
    metaOf: function (it) {
      var h = form.valid ? it.text : (it.data && it.data.handle) || '', m = [];
      m.push(it.text.length + ' chars');
      if (form.valid) { var e = check(it.text); m.push(el('span', { class: 'valid-pill' + (e ? ' bad' : '') , title: e || 'Meets Discord’s username rules' }, e ? '✗ ' + e : '✓ valid handle')); }
      if (it.data && it.data.display && form.valid && it.data.display !== it.text) m.push('Display: ' + it.data.display);
      return m;
    },
    extra: function (it) {
      if (!(it.data && it.data.display && form.valid && it.data.display !== it.text)) return null;
      var b = el('button', { type: 'button', class: 'act', 'aria-label': 'Copy display name' }, icon('copy'), el('span', null, 'Display'));
      b.addEventListener('click', function () { CH.copy(it.data.display); }); return b;
    }
  });
  var note = el('p', { class: 'hint', style: { marginTop: '14px' } }, 'Generated names can’t be checked against Discord, so a handle may already be taken. Discord handles are lowercase; the “Display” name keeps your capitalisation and can also be set separately in your profile.');
  var headBtns = el('div', { class: 'row' },
    ui.btn('Copy all', { icon: 'copyAll', sm: true, kind: 'ghost', onclick: function () { CH.copy(results.items().map(function (i) { return i.text; }).join('\n')); } }),
    ui.btn('Download', { icon: 'download', sm: true, kind: 'ghost', onclick: function () { CH.download('usernames.txt', results.items().map(function (i) { return i.text; }).join('\n') + '\n'); } }),
    ui.btn('Generate again', { icon: 'refresh', sm: true, onclick: run }));
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, el('div', { class: 'card card-pad' }, el('div', { class: 'results-head' }, el('h2', null, 'Your usernames'), headBtns), results.el, note)));

  function run() {
    var items = generate(form, parseInt(form.count, 10) || 12);
    results.set(items);
    if (!items.length) results.el.appendChild(ui.empty('search', 'No names fit those limits', 'Widen the length range or turn off “Discord-valid handle”.'));
  }
  run();
});
