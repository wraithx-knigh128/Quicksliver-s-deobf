/* Creator Hub — renders a Discord-style message from a webhook-shaped payload.
   payload = { username, avatar_url, content, embeds:[Discord embed objects], components:[action rows] } */
(function () {
  'use strict';
  var CH = window.CH, el = CH.el;

  function img(cls, url, alt) {
    var u = CH.safeUrl(url); if (!u) return null;
    var i = el('img', { class: cls, src: u, alt: alt || '', loading: 'lazy', referrerpolicy: 'no-referrer', decoding: 'async' });
    i.addEventListener('error', function () { i.remove(); });
    return i;
  }
  function mdSpan(cls, text) { var d = el('div', { class: cls }); d.innerHTML = CH.md.render(text); return d; }
  function toHex(n) { return '#' + ('000000' + (n >>> 0).toString(16)).slice(-6); }

  function embed(e) {
    var color = typeof e.color === 'number' ? toHex(e.color) : '#202225';
    var node = el('div', { class: 'dc-embed', style: { '--ec': color } });
    var inner = el('div', { class: 'dc-embed-in' + (e.thumbnail && CH.safeUrl(e.thumbnail.url) ? ' has-thumb' : '') });
    node.appendChild(inner);
    if (e.author && e.author.name) {
      var au = el('div', { class: 'dc-ea' }, img('', e.author.icon_url, ''));
      var link = CH.safeUrl(e.author.url);
      au.appendChild(link ? el('a', { href: link, target: '_blank', rel: 'noopener noreferrer nofollow' }, e.author.name) : el('span', null, e.author.name));
      inner.appendChild(au);
    }
    if (e.title) {
      var tl = CH.safeUrl(e.url);
      inner.appendChild(el('div', { class: 'dc-et' }, tl ? el('a', { href: tl, target: '_blank', rel: 'noopener noreferrer nofollow' }, e.title) : e.title));
    }
    if (e.description) inner.appendChild(mdSpan('dc-ed', e.description));
    if (e.fields && e.fields.length) {
      var grid = el('div', { class: 'dc-fields' }), run = [];
      var flush = function () { run.forEach(function (f, k) { grid.appendChild(fieldNode(f, 'i' + (k + 1))); }); run = []; };
      e.fields.forEach(function (f) {
        if (f.inline) { run.push(f); if (run.length === 3) flush(); } else { flush(); grid.appendChild(fieldNode(f, '')); }
      });
      flush();
      inner.appendChild(grid);
    }
    if (e.thumbnail) { var th = img('dc-thumb', e.thumbnail.url, ''); if (th) inner.appendChild(th); }
    if (e.image) { var im = img('dc-img', e.image.url, ''); if (im) inner.appendChild(im); }
    var hasFooter = (e.footer && e.footer.text) || e.timestamp;
    if (hasFooter) {
      var ft = el('div', { class: 'dc-ef' });
      if (e.footer && e.footer.text) {
        var fi = img('', e.footer.icon_url, ''); if (fi) ft.appendChild(fi);
        ft.appendChild(el('span', null, e.footer.text));
      }
      if (e.timestamp) {
        var d = new Date(e.timestamp);
        if (!isNaN(d)) {
          if (e.footer && e.footer.text) ft.appendChild(el('span', { class: 'sep' }, '•'));
          ft.appendChild(el('span', null, CH.formatDiscordTime(d)));
        }
      }
      inner.appendChild(ft);
    }
    return node;
  }
  function fieldNode(f, cls) {
    var n = el('div', { class: 'dc-field ' + cls }, el('div', { class: 'dc-fn' }, f.name || '​'));
    var v = el('div', { class: 'dc-fv' }); v.innerHTML = CH.md.render(f.value || '​'); n.appendChild(v);
    return n;
  }
  function components(rows) {
    var wrap = [];
    (rows || []).forEach(function (row) {
      var r = el('div', { class: 'dc-comps' });
      (row.components || []).forEach(function (c) {
        if (c.type !== 2) return;
        var b = el('button', { type: 'button', tabindex: '-1', class: 'dc-btn s' + (c.style || 1), disabled: c.disabled ? true : null, 'aria-label': (c.label || 'Button') + (c.style === 5 ? ' (link)' : '') });
        if (c.emoji && c.emoji.name) b.appendChild(el('span', null, c.emoji.name));
        if (c.label) b.appendChild(el('span', null, c.label));
        if (c.style === 5) b.appendChild(CH.icon('external'));
        r.appendChild(b);
      });
      if (r.children.length) wrap.push(r);
    });
    return wrap;
  }

  /** @returns {HTMLElement} .dc root */
  function message(payload, opts) {
    opts = opts || {};
    payload = payload || {};
    var root = el('div', { class: 'dc' + (opts.theme === 'light' ? ' light' : '') + (opts.compact ? ' compact-card' : '') });
    var name = payload.username || opts.defaultName || 'Your Bot';
    var av = el('div', { class: 'dc-avatar', 'aria-hidden': 'true' });
    var ai = img('', payload.avatar_url, '');
    if (ai) { av.appendChild(ai); ai.addEventListener('error', function () { av.textContent = name.charAt(0).toUpperCase(); }); } else av.textContent = name.charAt(0).toUpperCase();
    var body = el('div', { class: 'dc-body' });
    body.appendChild(el('div', { class: 'dc-head' },
      el('span', { class: 'dc-name' }, name),
      el('span', { class: 'dc-app' }, 'App'),
      el('span', { class: 'dc-time' }, CH.formatDiscordTime(new Date()))));
    var content = mdSpan('dc-content', payload.content || ''); body.appendChild(content);
    var embeds = (payload.embeds || []).filter(Boolean);
    if (embeds.length) body.appendChild(el('div', { class: 'dc-embeds' }, embeds.map(embed)));
    components(payload.components).forEach(function (c) { body.appendChild(c); });
    if (!payload.content && !embeds.length) body.appendChild(el('div', { class: 'dc-ph' }, 'Nothing to preview yet — start typing on the left.'));
    root.appendChild(el('div', { class: 'dc-msg' }, av, body));
    CH.md.bindSpoilers(root);
    return root;
  }

  CH.preview = { message: message, embed: embed };
})();
