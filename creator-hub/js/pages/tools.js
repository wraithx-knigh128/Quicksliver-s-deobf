/* Tools index */
CH.page('tools', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var CAT = { embeds: 'Builder', bio: 'Generator', username: 'Generator', rules: 'Generator', announcements: 'Generator', description: 'Generator', roles: 'Generator', channels: 'Generator', bots: 'Explore', ideas: 'Explore', templates: 'Explore' };
  var tools = CH.routes.filter(function (r) { return r.tool; });
  var cat = 'All', q = '';

  root.appendChild(ui.pageHead({ icon: 'grid', title: 'Tools', desc: 'Everything in Creator Hub. Press ' + (/Mac/.test(navigator.platform) ? '⌘K' : 'Ctrl K') + ' anywhere to jump straight to a tool.' }));

  var search = ui.field({ placeholder: 'Filter tools…', type: 'search', onInput: function (v) { q = v.toLowerCase().trim(); paint(); } });
  search.input.setAttribute('aria-label', 'Filter tools');
  var chips = ui.chips({ options: ['All', 'Builder', 'Generator', 'Explore'], value: 'All', sm: true, label: 'Category', onChange: function (v) { cat = v; paint(); } });
  root.appendChild(el('div', { class: 'filter-bar' }, search.el, chips.el));

  var grid = el('div', { class: 'grid g3' });
  root.appendChild(grid);
  var count = el('p', { class: 'hint', style: { marginTop: '14px' }, 'aria-live': 'polite' });
  root.appendChild(count);

  function paint() {
    CH.clear(grid);
    var list = tools.filter(function (r) {
      if (cat !== 'All' && CAT[r.id] !== cat) return false;
      if (!q) return true;
      return (r.title + ' ' + r.desc + ' ' + r.kw).toLowerCase().indexOf(q) >= 0;
    });
    list.forEach(function (r) {
      grid.appendChild(el('a', { class: 'card tool-card tilt spot', href: '#/' + r.id },
        el('div', { class: 'row-between' }, el('div', { class: 'tc-ic' }, icon(r.icon)), el('span', { class: 'tag' }, CAT[r.id])),
        el('div', null, el('h3', null, r.title), el('p', null, r.desc)),
        el('span', { class: 'tc-go' }, 'Open', icon('arrowRight'))));
    });
    if (!list.length) grid.appendChild(el('div', { style: { gridColumn: '1/-1' } }, ui.empty('search', 'No tools match', 'Try a different word, like “embed”, “bio” or “roles”.')));
    count.textContent = list.length + ' of ' + tools.length + ' tools';
  }
  paint();
});
