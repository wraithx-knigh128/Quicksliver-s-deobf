/* Saved Creations — everything lives in this browser's localStorage. */
CH.page('saved', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var LABEL = { bio: 'Bio', username: 'Username', rules: 'Rules', announcement: 'Announcement', description: 'Description', roles: 'Roles', channels: 'Channels', embed: 'Embed', template: 'Template', idea: 'Idea', bot: 'Bot' };
  var filter = 'all', q = '';

  root.appendChild(ui.pageHead({ icon: 'bookmark', title: 'Saved Creations', desc: 'Your library, stored privately in this browser. Nothing is uploaded — export a backup if you want to move devices.' }));

  var search = ui.field({ type: 'search', placeholder: 'Search saved items…', onInput: function (v) { q = v.toLowerCase().trim(); paint(); } }); search.input.setAttribute('aria-label', 'Search saved items');
  var tabsHost = el('div');
  var fileIn = el('input', { type: 'file', accept: 'application/json,.json', hidden: true, 'aria-label': 'Import backup file' });
  fileIn.addEventListener('change', function () {
    var f = fileIn.files[0]; if (!f) return;
    var rd = new FileReader();
    rd.onload = function () {
      try {
        var j = JSON.parse(rd.result), items = Array.isArray(j) ? j : j.saved;
        if (!Array.isArray(items)) throw new Error('No saved items found');
        var cur = CH.Saved.all(), ids = {}; cur.forEach(function (x) { ids[x.id] = 1; });
        var add = items.filter(function (x) { return x && typeof x.body === 'string' && x.type && !ids[x.id]; }).map(function (x) { return { id: String(x.id || CH.uid()), type: String(x.type), title: String(x.title || '').slice(0, 120), body: x.body, data: x.data, fav: !!x.fav, ts: +x.ts || Date.now() }; });
        CH.Saved.replaceAll(cur.concat(add).sort(function (a, b) { return b.ts - a.ts; }).slice(0, 500)); CH.toast('Imported ' + add.length + ' item' + (add.length === 1 ? '' : 's')); paint();
      } catch (e) { CH.toast('That file isn’t a CordX backup', 'bad'); }
      fileIn.value = '';
    };
    rd.readAsText(f);
  });
  var tools = el('div', { class: 'row' },
    ui.btn('Export', { icon: 'download', sm: true, onclick: function () { CH.download('cordx-backup.json', JSON.stringify({ app: 'creator-hub', version: 1, exported: new Date().toISOString(), saved: CH.Saved.all() }, null, 2), 'application/json'); } }),
    ui.btn('Import', { icon: 'upload', sm: true, onclick: function () { fileIn.click(); } }),
    ui.btn('Clear all', { icon: 'trash', sm: true, kind: 'danger', onclick: function () { if (CH.Saved.all().length && confirm('Delete every saved item? This can’t be undone — export a backup first if you might want them.')) { CH.Saved.replaceAll([]); paint(); } } }), fileIn);
  root.appendChild(el('div', { class: 'row-between', style: { marginBottom: '14px' } }, el('div', { style: { minWidth: '240px', flex: '1', maxWidth: '360px' } }, search.el), tools));
  root.appendChild(tabsHost);
  var grid = el('div', { class: 'saved-grid', style: { marginTop: '18px' } });
  root.appendChild(grid);
  var onSaved = function () { if (document.body.contains(grid)) paint(); };
  document.addEventListener('ch:saved', onSaved);

  function when(ts) { return new Date(ts).toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' }); }
  function card(s) {
    var payload = s.data && s.data.payload;
    var acts = el('div', { class: 'result-actions' });
    function act(label, ic, fn, cls) { var b = el('button', { type: 'button', class: 'act' + (cls ? ' ' + cls : ''), 'aria-label': label + ' ' + (s.title || s.type) }, icon(ic), el('span', null, label)); b.addEventListener('click', fn); acts.appendChild(b); return b; }
    act('Copy', 'copy', function () { CH.copy(s.body); });
    if (payload) act('Open', 'embed', function () { CH.handoff.set('embed', payload); location.hash = '#/embeds'; });
    act(s.fav ? 'Favorited' : 'Favorite', 'star', function () { CH.Saved.update(s.id, { fav: !s.fav }); }, s.fav ? 'on' : '');
    act('Delete', 'trash', function () { CH.Saved.remove(s.id); CH.toast('Deleted'); });
    return el('article', { class: 'card card-pad item-card' },
      el('div', { class: 'row-between' }, el('span', { class: 'tag' }, LABEL[s.type] || s.type), el('span', { class: 'meta-line' }, when(s.ts))),
      s.title ? el('h3', { style: { fontSize: '15px' } }, s.title) : null,
      el('div', { class: 'result-body' + (s.type === 'username' ? ' big' : (s.type === 'embed' || s.type === 'template' ? ' mono' : '')), style: { display: '-webkit-box', WebkitLineClamp: s.type === 'username' ? '2' : '6', WebkitBoxOrient: 'vertical', overflow: 'hidden', fontSize: s.type === 'username' ? '' : '14px' } }, s.body),
      el('div', { class: 'foot' }, acts));
  }
  function paint() {
    var all = CH.Saved.all();
    var types = Array.from(new Set(all.map(function (s) { return s.type; })));
    CH.clear(tabsHost);
    var items = [{ id: 'all', label: 'All (' + all.length + ')' }, { id: 'fav', label: '★ Favorites (' + all.filter(function (s) { return s.fav; }).length + ')' }].concat(types.map(function (t) { return { id: t, label: (LABEL[t] || t) + ' (' + all.filter(function (s) { return s.type === t; }).length + ')' }; }));
    if (filter !== 'all' && filter !== 'fav' && types.indexOf(filter) < 0) filter = 'all';
    tabsHost.appendChild(ui.tabs({ label: 'Filter saved items', value: filter, items: items, onChange: function (v) { filter = v; paint(); } }).el);
    CH.clear(grid);
    var list = all.filter(function (s) { return (filter === 'all' || (filter === 'fav' ? s.fav : s.type === filter)) && (!q || (s.title + ' ' + s.body).toLowerCase().indexOf(q) >= 0); });
    list.forEach(function (s) { grid.appendChild(card(s)); });
    if (!list.length) {
      grid.style.display = 'block';
      grid.appendChild(all.length ? ui.empty('search', 'Nothing matches', 'Try a different filter or search.') : el('div', null, ui.empty('bookmark', 'Your library is empty', 'Use Save on any generated result, template or embed and it will appear here.'), el('div', { class: 'row', style: { justifyContent: 'center', marginTop: '14px' } }, ui.btn('Open Bio Generator', { href: '#/bio', icon: 'user' }), ui.btn('Open Embed Builder', { href: '#/embeds', icon: 'embed' }))));
    } else grid.style.display = '';
  }
  paint();
  return function () { document.removeEventListener('ch:saved', onSaved); };
});
