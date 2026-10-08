/* Settings */
CH.page('settings', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var S = CH.settings;

  root.appendChild(ui.pageHead({ icon: 'settings', title: 'Settings', desc: 'Everything is stored in this browser only.' }));

  function row(title, desc, control) { return el('div', { class: 'setting-row' }, el('div', null, el('div', { class: 's-t' }, title), desc ? el('div', { class: 's-d' }, desc) : null), control); }
  var s = S.get();

  var fxInfo = el('div', { class: 'hint', 'aria-live': 'polite' });
  function showFx() {
    var lvl = S.level(), auto = S.get().fx === 'auto';
    fxInfo.textContent = 'Currently running: ' + lvl.toUpperCase() + (auto ? ' (chosen automatically for this device)' : ' (set manually)') + '. ' + ({ full: 'Particles, cursor light and 3D tilt are available.', lite: 'No particles or 3D tilt; light transitions only.', off: 'No animation at all.' }[lvl]);
  }
  var fxSeg = ui.seg({ label: 'Visual effects', value: s.fx, options: [{ value: 'auto', label: 'Auto' }, { value: 'full', label: 'Full' }, { value: 'lite', label: 'Lite' }, { value: 'off', label: 'Off' }], onChange: function (v) { S.set({ fx: v }); showFx(); syncEnabled(); } });
  var part = ui.switch({ label: 'Particles', checked: s.particles, onChange: function (v) { S.set({ particles: v }); } });
  var glow = ui.switch({ label: 'Cursor light', checked: s.glow, onChange: function (v) { S.set({ glow: v }); } });
  var tilt = ui.switch({ label: '3D card tilt', checked: s.tilt, onChange: function (v) { S.set({ tilt: v }); } });
  function syncEnabled() { var full = S.level() === 'full'; [part, glow, tilt].forEach(function (x) { x.input.disabled = !full; x.el.style.opacity = full ? '' : '.5'; }); }

  var ACC = [['violet', '#7c6cff'], ['cyan', '#22c7f2'], ['emerald', '#2fd39a'], ['rose', '#fb6f92'], ['amber', '#f5b84b']];
  var accWrap = el('div', { class: 'accent-pick', role: 'radiogroup', 'aria-label': 'Accent colour' }, ACC.map(function (a) {
    var b = el('button', { type: 'button', class: 'accent-dot', role: 'radio', 'aria-label': CH.cap(a[0]), 'aria-checked': String(s.accent === a[0]), title: CH.cap(a[0]), style: { background: a[1] }, dataset: { v: a[0] } });
    b.addEventListener('click', function () { S.set({ accent: a[0] }); CH.$$('.accent-dot', accWrap).forEach(function (x) { x.setAttribute('aria-checked', String(x.dataset.v === a[0])); }); });
    return b;
  }));
  var dens = ui.seg({ label: 'Density', value: s.density, options: [{ value: 'comfortable', label: 'Comfortable' }, { value: 'compact', label: 'Compact' }], onChange: function (v) { S.set({ density: v }); } });
  var prev = ui.seg({ label: 'Default embed preview', value: s.previewTheme, options: [{ value: 'dark', label: 'Dark' }, { value: 'light', label: 'Light' }], onChange: function (v) { S.set({ previewTheme: v }); } });

  root.appendChild(el('div', { class: 'card card-pad' },
    el('h2', { class: 'card-title', style: { marginBottom: '4px' } }, 'Appearance & performance'),
    row('Visual effects', 'Auto uses the lite version on phones, low-power devices, data-saver mode and when reduced motion is on.', el('div', { class: 'stack-sm' }, fxSeg.el)),
    el('div', { style: { padding: '0 0 10px' } }, fxInfo),
    row('Effect details', 'Only available at the Full level.', el('div', { class: 'switches' }, part.el, glow.el, tilt.el)),
    row('Accent colour', null, accWrap),
    row('Density', 'Compact tightens spacing and control height.', dens.el),
    row('Embed preview', 'Starting theme for the Discord-style preview.', prev.el)));
  showFx(); syncEnabled();
  var onSet = function () { showFx(); syncEnabled(); };
  document.addEventListener('ch:settings', onSet);

  /* data */
  var count = el('span', { class: 'muted' });
  function refresh() { count.textContent = CH.Saved.all().length + ' saved items'; }
  refresh(); document.addEventListener('ch:saved', refresh);
  function allKeys() { var k = []; try { for (var i = 0; i < localStorage.length; i++) { var n = localStorage.key(i); if (n && n.indexOf('ch:') === 0) k.push(n); } } catch (e) {} return k; }
  root.appendChild(el('div', { class: 'card card-pad', style: { marginTop: '16px' } },
    el('h2', { class: 'card-title', style: { marginBottom: '4px' } }, 'Your data'),
    row('Backup', 'Download your saved items as a file, or restore from one on the Saved page.', el('div', { class: 'row' }, count, ui.btn('Export', { icon: 'download', sm: true, onclick: function () { CH.download('creator-hub-backup.json', JSON.stringify({ app: 'creator-hub', version: 1, exported: new Date().toISOString(), saved: CH.Saved.all(), settings: S.get() }, null, 2), 'application/json'); } }))),
    row('Reset settings', 'Restores defaults for effects, accent and density. Your saved items stay.', ui.btn('Reset', { icon: 'refresh', sm: true, onclick: function () { S.reset(); CH.toast('Settings reset'); location.reload(); } })),
    row('Clear saved items', 'Permanently deletes your library from this browser.', ui.btn('Clear saved', { icon: 'trash', sm: true, kind: 'danger', onclick: function () { if (confirm('Delete all saved items? Export a backup first if you might need them.')) { CH.Saved.replaceAll([]); CH.toast('Saved items cleared'); } } })),
    row('Erase everything', 'Removes settings, drafts, saved items and form memory stored by this site.', ui.btn('Erase all', { icon: 'trash', sm: true, kind: 'danger', onclick: function () { if (confirm('Erase ALL Creator Hub data in this browser? This can’t be undone.')) { allKeys().forEach(function (k) { try { localStorage.removeItem(k); } catch (e) {} }); CH.toast('Everything erased'); setTimeout(function () { location.reload(); }, 600); } } }))));

  /* system */
  var cn = navigator.connection || {};
  var info = [['Reduced motion preference', matchMedia('(prefers-reduced-motion: reduce)').matches ? 'On — effects are off in Auto' : 'Off'], ['Pointer', matchMedia('(pointer: coarse)').matches ? 'Touch (coarse)' : 'Mouse (fine)'], ['Screen', screen.width + '×' + screen.height + ' @ ' + (window.devicePixelRatio || 1) + 'x'], ['CPU cores', navigator.hardwareConcurrency || 'unknown'], ['Memory hint', navigator.deviceMemory ? navigator.deviceMemory + ' GB' : 'unknown'], ['Data saver', cn.saveData ? 'On' : 'Off or unknown']];
  root.appendChild(ui.acc('What your device reports', el('div', { class: 'stack-sm' }, info.map(function (r) { return el('div', { class: 'row-between' }, el('span', { class: 'muted' }, r[0]), el('span', null, String(r[1]))); })), { meta: 'used for the Auto effects level' }));

  return function () { document.removeEventListener('ch:settings', onSet); document.removeEventListener('ch:saved', refresh); };
});
