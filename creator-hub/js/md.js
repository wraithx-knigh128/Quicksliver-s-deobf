/* Creator Hub — Discord-flavoured markdown → safe HTML.
   Everything is HTML-escaped first; only a fixed set of tags is ever produced. */
(function () {
  'use strict';
  var CH = window.CH;
  var esc = CH.esc;

  function relTime(ms) {
    var diff = (ms - Date.now()) / 1000, abs = Math.abs(diff);
    var units = [['year', 31536000], ['month', 2592000], ['day', 86400], ['hour', 3600], ['minute', 60], ['second', 1]];
    for (var i = 0; i < units.length; i++) {
      if (abs >= units[i][1] || units[i][0] === 'second') {
        var v = Math.round(diff / units[i][1]);
        if (window.Intl && Intl.RelativeTimeFormat) return new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }).format(v, units[i][0]);
        return (v < 0 ? Math.abs(v) + ' ' + units[i][0] + 's ago' : 'in ' + v + ' ' + units[i][0] + 's');
      }
    }
    return '';
  }
  function fmtTs(sec, style) {
    var d = new Date(sec * 1000);
    if (isNaN(d)) return '';
    var L = undefined;
    switch (style) {
      case 't': return d.toLocaleTimeString(L, { hour: 'numeric', minute: '2-digit' });
      case 'T': return d.toLocaleTimeString(L, { hour: 'numeric', minute: '2-digit', second: '2-digit' });
      case 'd': return d.toLocaleDateString(L, { year: 'numeric', month: '2-digit', day: '2-digit' });
      case 'D': return d.toLocaleDateString(L, { year: 'numeric', month: 'long', day: 'numeric' });
      case 'F': return d.toLocaleString(L, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit' });
      case 'R': return relTime(d.getTime());
      default: return d.toLocaleString(L, { year: 'numeric', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit' });
    }
  }

  function render(src, opts) {
    opts = opts || {};
    var tokens = [];
    function stash(html) { tokens.push(html); return '\u0001' + (tokens.length - 1) + '\u0002'; }
    function unstash(s) {
      var guard = 0;
      while (/\u0001\d+\u0002/.test(s) && guard++ < 6) s = s.replace(/\u0001(\d+)\u0002/g, function (m, n) { return tokens[+n]; });
      return s;
    }

    var s = esc(String(src == null ? '' : src).replace(/\r\n?/g, '\n'));

    // fenced + inline code
    s = s.replace(/```(?:([\w+#-]+)\n)?([\s\S]*?)```/g, function (m, lang, code) {
      return stash('<pre class="dc-pre"><code>' + code.replace(/^\n+|\n+$/g, '') + '</code></pre>');
    });
    s = s.replace(/``([\s\S]+?)``|`([^`\n]+?)`/g, function (m, a, b) { return stash('<code class="dc-code">' + (a || b) + '</code>'); });
    // backslash escapes
    s = s.replace(/\\([\\*_~|`>#\[\]()-])/g, function (m, c) { return stash(c); });

    function inline(t) {
      // masked links  [text](https://…)
      t = t.replace(/\[([^\]\n]+)\]\((https?:\/\/[^\s)]+)(?:\s+&quot;[^\n]*?&quot;)?\)/g, function (m, label, url) {
        return stash('<a class="dc-link" href="' + url + '" target="_blank" rel="noopener noreferrer nofollow">' + fmt(label) + '</a>');
      });
      // <https://suppressed-embed.link>
      t = t.replace(/&lt;(https?:\/\/[^\s&]+(?:&amp;[^\s&]*)*)&gt;/g, function (m, url) {
        return stash('<a class="dc-link" href="' + url + '" target="_blank" rel="noopener noreferrer nofollow">' + url + '</a>');
      });
      // bare links
      t = t.replace(/\bhttps?:\/\/[^\s\u0001\u0002]+/g, function (m) {
        var trail = '', mm;
        while ((mm = /(&gt;|&lt;|&quot;|&#39;|[.,;:!?)\]])$/.exec(m))) { trail = mm[1] + trail; m = m.slice(0, -mm[1].length); }
        if (!/^https?:\/\/[^\s]+\.[^\s]+|^https?:\/\/localhost/i.test(m)) return m + trail;
        return stash('<a class="dc-link" href="' + m + '" target="_blank" rel="noopener noreferrer nofollow">' + m + '</a>') + trail;
      });
      // discord entities
      t = t.replace(/&lt;t:(\d{1,13})(?::([tTdDfFR]))?&gt;/g, function (m, sec, st) { return stash('<span class="dc-ts">' + esc(fmtTs(+sec, st)) + '</span>'); });
      t = t.replace(/&lt;@&amp;(\d{5,25})&gt;/g, function () { return stash('<span class="dc-mention">@role</span>'); });
      t = t.replace(/&lt;@!?(\d{5,25})&gt;/g, function () { return stash('<span class="dc-mention">@user</span>'); });
      t = t.replace(/&lt;#(\d{5,25})&gt;/g, function () { return stash('<span class="dc-mention">#channel</span>'); });
      t = t.replace(/&lt;(a?):(\w{2,32}):(\d{15,25})&gt;/g, function (m, an, name, id) {
        return stash('<img class="dc-emoji" alt=":' + name + ':" title=":' + name + ':" loading="lazy" referrerpolicy="no-referrer" src="https://cdn.discordapp.com/emojis/' + id + '.' + (an ? 'gif' : 'webp') + '?size=48">');
      });
      t = t.replace(/@(everyone|here)\b/g, function (m) { return stash('<span class="dc-mention">' + m + '</span>'); });
      return fmt(t);
    }
    function fmt(t) {
      t = t.replace(/\|\|([\s\S]+?)\|\|/g, '<span class="dc-spoiler" tabindex="0" role="button" aria-label="Spoiler, click to reveal">$1</span>');
      t = t.replace(/\*\*\*([^\n]+?)\*\*\*/g, '<strong><em>$1</em></strong>');
      t = t.replace(/\*\*([\s\S]+?)\*\*/g, '<strong>$1</strong>');
      t = t.replace(/__([\s\S]+?)__/g, '<u>$1</u>');
      t = t.replace(/\*(?!\s)([^*\n]+?)\*/g, '<em>$1</em>');
      t = t.replace(/(^|[^\w])_(?!\s)([^_\n]+?)_(?!\w)/g, '$1<em>$2</em>');
      t = t.replace(/~~([\s\S]+?)~~/g, '<s>$1</s>');
      return t;
    }

    var lines = s.split('\n'), parts = [], i = 0, m;
    while (i < lines.length) {
      var ln = lines[i];
      if ((m = /^&gt;&gt;&gt; ?(.*)$/.exec(ln))) {
        var rest = [m[1]].concat(lines.slice(i + 1));
        parts.push({ b: true, h: '<span class="dc-quote">' + rest.map(inline).join('<br>') + '</span>' });
        break;
      }
      if (/^&gt; ?/.test(ln)) {
        var q = [];
        while (i < lines.length && /^&gt; ?/.test(lines[i])) { q.push(lines[i].replace(/^&gt; ?/, '')); i++; }
        parts.push({ b: true, h: '<span class="dc-quote">' + q.map(inline).join('<br>') + '</span>' });
        continue;
      }
      if ((m = /^(#{1,3}) (.+)$/.exec(ln))) { parts.push({ b: true, h: '<span class="dc-h' + m[1].length + '">' + inline(m[2]) + '</span>' }); i++; continue; }
      if ((m = /^-# (.+)$/.exec(ln))) { parts.push({ b: true, h: '<span class="dc-sub">' + inline(m[1]) + '</span>' }); i++; continue; }
      if (/^\s{0,3}[-*] (.+)$/.test(ln)) {
        var items = [];
        while (i < lines.length && (m = /^\s{0,3}[-*] (.+)$/.exec(lines[i]))) { items.push('<li>' + inline(m[1]) + '</li>'); i++; }
        parts.push({ b: true, h: '<ul class="dc-ul">' + items.join('') + '</ul>' });
        continue;
      }
      parts.push({ b: false, h: inline(ln) });
      i++;
    }
    var out = '';
    parts.forEach(function (p, k) {
      if (k > 0 && !p.b && !parts[k - 1].b) out += '<br>';
      out += p.h;
    });
    return unstash(out);
  }

  /** Make spoilers clickable inside a rendered container (call once per container). */
  function bindSpoilers(root) {
    if (root.__spoilers) return; root.__spoilers = true;
    root.addEventListener('click', function (e) { var s = e.target.closest && e.target.closest('.dc-spoiler'); if (s) s.classList.toggle('open'); });
    root.addEventListener('keydown', function (e) { if ((e.key === 'Enter' || e.key === ' ') && e.target.classList && e.target.classList.contains('dc-spoiler')) { e.preventDefault(); e.target.classList.toggle('open'); } });
  }

  CH.md = { render: render, bindSpoilers: bindSpoilers, fmtTs: fmtTs };
})();
