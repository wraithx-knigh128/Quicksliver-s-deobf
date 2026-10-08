/* Discord Embed Builder
   State is edited in a friendly shape and converted to the real Discord webhook payload for preview/export. */
CH.page('embeds', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;

  var LIM = { title: 256, desc: 4096, fields: 25, fname: 256, fvalue: 1024, footer: 2048, author: 256, total: 6000, embeds: 10, content: 2000, username: 80, buttons: 5 };
  var COLORS = [['#5865F2', 'Blurple'], ['#57F287', 'Green'], ['#FEE75C', 'Yellow'], ['#EB459E', 'Fuchsia'], ['#ED4245', 'Red'], ['#7c6cff', 'Violet'], ['#35d4ff', 'Cyan'], ['#F2F3F5', 'White'], ['#23272A', 'Dark']];
  var BTN_STYLES = [{ value: '5', label: 'Link (grey, opens a URL)' }, { value: '1', label: 'Primary (blurple) — needs a bot' }, { value: '2', label: 'Secondary (grey) — needs a bot' }, { value: '3', label: 'Success (green) — needs a bot' }, { value: '4', label: 'Danger (red) — needs a bot' }];
  var HEX = /^#[0-9a-f]{6}$/i;

  /* ---------------- state ---------------- */
  function blankEmbed() {
    return { title: '', url: '', description: '', color: '#5865F2', author: { name: '', url: '', icon: '' }, thumbnail: '', image: '', footer: { text: '', icon: '' }, ts: 'none', tsValue: '', fields: [] };
  }
  function blankState() { return { content: '', username: '', avatar: '', embeds: [blankEmbed()], active: 0, buttons: [] }; }

  function localInput(iso) { var d = new Date(iso); if (isNaN(d)) return ''; var p = function (n) { return ('0' + n).slice(-2); }; return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + 'T' + p(d.getHours()) + ':' + p(d.getMinutes()); }
  function fromPayload(p) {
    var st = blankState(); st.embeds = [];
    st.content = String(p.content || ''); st.username = String(p.username || ''); st.avatar = String(p.avatar_url || '');
    (p.embeds || []).slice(0, LIM.embeds).forEach(function (e) {
      var b = blankEmbed(); e = e || {};
      b.title = String(e.title || ''); b.url = String(e.url || ''); b.description = String(e.description || '');
      if (typeof e.color === 'number') b.color = '#' + ('000000' + (e.color >>> 0).toString(16)).slice(-6);
      else if (typeof e.color === 'string' && HEX.test(e.color)) b.color = e.color; else b.color = e.color == null ? '' : b.color;
      var a = e.author || {}; b.author = { name: String(a.name || ''), url: String(a.url || ''), icon: String(a.icon_url || a.icon || '') };
      b.thumbnail = String((e.thumbnail && e.thumbnail.url) || ''); b.image = String((e.image && e.image.url) || '');
      var f = e.footer || {}; b.footer = { text: String(f.text || ''), icon: String(f.icon_url || f.icon || '') };
      if (e.timestamp) { b.ts = 'custom'; b.tsValue = localInput(e.timestamp); }
      b.fields = (e.fields || []).slice(0, LIM.fields).map(function (x) { return { name: String(x.name || ''), value: String(x.value || ''), inline: !!x.inline }; });
      st.embeds.push(b);
    });
    if (!st.embeds.length) st.embeds.push(blankEmbed());
    (p.components || []).forEach(function (row) {
      (row.components || []).forEach(function (c) {
        if (c.type === 2 && st.buttons.length < LIM.buttons) st.buttons.push({ label: String(c.label || ''), style: String(c.style || 1), url: String(c.url || ''), customId: String(c.custom_id || ''), disabled: !!c.disabled });
      });
    });
    return st;
  }
  var EXAMPLE = {
    username: 'Nebula Bot',
    embeds: [{
      title: 'Welcome to Nebula Lounge', url: '', color: 0x5865F2,
      description: 'Glad you’re here! A few quick things to get started:\n\n**1.** Read the rules in <#1100000000000000001>\n**2.** Grab your roles in <#1100000000000000002>\n**3.** Say hi — we don’t bite.\n\n> Tip: use `/help` if you get lost.',
      fields: [{ name: 'Members', value: '1,204', inline: true }, { name: 'Events', value: 'Fridays · 8 PM', inline: true }, { name: 'Need help?', value: 'Ping a [moderator](https://example.com) or open a ticket.', inline: false }],
      footer: { text: 'Nebula Lounge' }
    }],
    components: [{ type: 1, components: [{ type: 2, style: 5, label: 'Read the rules', url: 'https://example.com/rules' }] }]
  };

  var state = (function () {
    var h = CH.handoff.take('embed');
    if (h) { try { return h.embeds || h.content != null || h.username != null ? fromPayload(h) : fromPayload(EXAMPLE); } catch (e) {} }
    var d = CH.Store.get('draft:embed', null);
    if (d && d.embeds && d.embeds.length) { d.active = Math.min(d.active || 0, d.embeds.length - 1); return d; }
    return fromPayload(EXAMPLE);
  })();
  var theme = CH.settings.get().previewTheme || 'dark';
  var openSecs = { msg: true, basics: true, author: false, images: false, footer: false, fields: true, buttons: false };
  var exportKind = 'json';

  function cur() { return state.embeds[state.active]; }

  /* ---------------- payload conversion ---------------- */
  function embedObj(e, preview) {
    var o = {};
    if (e.title) o.title = e.title;
    if (e.description) o.description = e.description;
    var u = preview ? CH.safeUrl(e.url) : e.url.trim(); if (u) o.url = u;
    if (e.color && HEX.test(e.color)) o.color = parseInt(e.color.slice(1), 16);
    if (e.ts === 'now') { o.timestamp = new Date().toISOString(); Object.defineProperty(o, '__now', { value: true }); }
    else if (e.ts === 'custom' && e.tsValue) { var d = new Date(e.tsValue); if (!isNaN(d)) o.timestamp = d.toISOString(); }
    if (e.footer.text) { o.footer = { text: e.footer.text }; var fi = e.footer.icon.trim(); if (fi) o.footer.icon_url = fi; }
    if (e.image.trim()) o.image = { url: e.image.trim() };
    if (e.thumbnail.trim()) o.thumbnail = { url: e.thumbnail.trim() };
    if (e.author.name) { o.author = { name: e.author.name }; if (e.author.url.trim()) o.author.url = e.author.url.trim(); if (e.author.icon.trim()) o.author.icon_url = e.author.icon.trim(); }
    var fs = e.fields.filter(function (f) { return f.name || f.value; });
    if (fs.length) o.fields = fs.map(function (f) { var x = { name: f.name, value: f.value }; if (f.inline) x.inline = true; return x; });
    return o;
  }
  function buttonObjs(preview) {
    return state.buttons.map(function (b, i) {
      var st = parseInt(b.style, 10) || 1, o = { type: 2, style: st };
      if (b.label) o.label = b.label;
      if (st === 5) o.url = preview ? CH.safeUrl(b.url) || b.url.trim() : b.url.trim(); else o.custom_id = b.customId.trim() || ('button_' + (i + 1));
      if (b.disabled) o.disabled = true;
      return o;
    });
  }
  function payload(preview) {
    var p = {};
    if (state.content) p.content = state.content;
    if (state.username.trim()) p.username = state.username.trim();
    if (state.avatar.trim()) p.avatar_url = state.avatar.trim();
    var embeds = state.embeds.map(function (e) { return embedObj(e, preview); }).filter(function (o) { return Object.keys(o).length && !(Object.keys(o).length === 1 && o.color != null); });
    if (embeds.length) p.embeds = embeds;
    if (state.buttons.length) p.components = [{ type: 1, components: buttonObjs(preview) }];
    return p;
  }

  /* ---------------- validation ---------------- */
  function validate() {
    var issues = [], total = 0;
    function url(label, v) { if (v && v.trim() && !/^https?:\/\/\S+\.\S+/i.test(v.trim())) issues.push({ l: 'error', m: label + ' must be a full http(s) URL.' }); }
    if (state.content.length > LIM.content) issues.push({ l: 'error', m: 'Message content is ' + state.content.length + '/' + LIM.content + ' characters.' });
    url('Webhook avatar', state.avatar);
    if (state.username.length > LIM.username) issues.push({ l: 'error', m: 'Webhook username is over ' + LIM.username + ' characters.' });
    if (/discord|clyde/i.test(state.username)) issues.push({ l: 'warn', m: 'Discord rejects webhook usernames that contain “discord” or “clyde”.' });
    state.embeds.forEach(function (e, i) {
      var n = state.embeds.length > 1 ? 'Embed ' + (i + 1) + ': ' : '';
      var has = e.title || e.description || e.fields.some(function (f) { return f.name || f.value; }) || e.image.trim() || e.thumbnail.trim() || e.author.name || e.footer.text;
      if (!has && state.embeds.length > 1) issues.push({ l: 'warn', m: n + 'is empty and will be left out.' });
      if (e.title.length > LIM.title) issues.push({ l: 'error', m: n + 'title is over ' + LIM.title + ' characters (' + e.title.length + ').' });
      if (e.description.length > LIM.desc) issues.push({ l: 'error', m: n + 'description is over ' + LIM.desc + ' characters (' + e.description.length + ').' });
      if (e.author.name.length > LIM.author) issues.push({ l: 'error', m: n + 'author name is over ' + LIM.author + ' characters.' });
      if (e.footer.text.length > LIM.footer) issues.push({ l: 'error', m: n + 'footer text is over ' + LIM.footer + ' characters.' });
      if (!e.footer.text && e.footer.icon.trim()) issues.push({ l: 'error', m: n + 'a footer icon needs footer text — Discord ignores or rejects it otherwise.' });
      if (!e.author.name && (e.author.url.trim() || e.author.icon.trim())) issues.push({ l: 'warn', m: n + 'author URL/icon are ignored without an author name.' });
      if (e.url.trim() && !e.title) issues.push({ l: 'warn', m: n + 'the embed URL only works when there is a title to link.' });
      url(n + 'Embed URL', e.url); url(n + 'Author URL', e.author.url); url(n + 'Author icon', e.author.icon); url(n + 'Thumbnail', e.thumbnail); url(n + 'Image', e.image); url(n + 'Footer icon', e.footer.icon);
      if (e.color && !HEX.test(e.color)) issues.push({ l: 'error', m: n + 'colour must be a 6-digit hex like #5865F2.' });
      if (e.ts === 'custom' && (!e.tsValue || isNaN(new Date(e.tsValue)))) issues.push({ l: 'error', m: n + 'choose a valid timestamp date, or set the timestamp to Off.' });
      e.fields.forEach(function (f, k) {
        var fn = n + 'field ' + (k + 1) + ' ';
        if ((f.name || f.value) && (!f.name.trim() || !f.value.trim())) issues.push({ l: 'error', m: fn + 'needs both a name and a value — Discord rejects empty halves.' });
        if (f.name.length > LIM.fname) issues.push({ l: 'error', m: fn + 'name is over ' + LIM.fname + ' characters.' });
        if (f.value.length > LIM.fvalue) issues.push({ l: 'error', m: fn + 'value is over ' + LIM.fvalue + ' characters (' + f.value.length + ').' });
      });
      total += e.title.length + e.description.length + e.author.name.length + e.footer.text.length + e.fields.reduce(function (a, f) { return a + f.name.length + f.value.length; }, 0);
    });
    if (total > LIM.total) issues.push({ l: 'error', m: 'Combined embed text is ' + total + ' characters; Discord’s limit is ' + LIM.total + ' per message.' });
    state.buttons.forEach(function (b, i) {
      var n = 'Button ' + (i + 1) + ': ';
      if (!b.label.trim()) issues.push({ l: 'error', m: n + 'needs a label.' });
      if (b.label.length > 80) issues.push({ l: 'error', m: n + 'label is over 80 characters.' });
      if (b.style === '5') { if (!/^https?:\/\/\S+\.\S+/i.test(b.url.trim())) issues.push({ l: 'error', m: n + 'a link button needs a full http(s) URL.' }); }
    });
    if (state.buttons.some(function (b) { return b.style !== '5'; })) issues.push({ l: 'warn', m: 'Non-link buttons only work when an application (bot) receives the click. A plain channel webhook can’t respond to them.' });
    if (state.buttons.length && !Object.keys(payload()).some(function (k) { return k === 'embeds' || k === 'content'; })) issues.push({ l: 'warn', m: 'Buttons need a message to sit under — add content or an embed.' });
    var p = payload();
    if (!p.content && !p.embeds) issues.push({ l: 'error', m: 'The message is empty. Discord needs content, an embed with text/image, or both.' });
    return { issues: issues, total: total };
  }

  /* ---------------- code export ---------------- */
  function J(s) { return JSON.stringify(s); }
  function exportCode(kind) {
    var p = payload(false);
    if (kind === 'json') return JSON.stringify(p, null, 2);
    if (kind === 'embeds') return JSON.stringify(p.embeds || [], null, 2);
    if (kind === 'curl') {
      var q = (p.components ? '?with_components=true' : '');
      return 'curl -X POST "https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN' + q + '" \\\n  -H "Content-Type: application/json" \\\n  -d \'' + JSON.stringify(p).replace(/'/g, "'\\''") + '\'';
    }
    var embeds = p.embeds || [], hexs = function (n) { return '0x' + ('000000' + n.toString(16)).slice(-6).toUpperCase(); };
    var comps = p.components ? p.components[0].components : [];
    if (kind === 'djs') {
      var out = [], imports = ['EmbedBuilder'];
      if (comps.length) imports.push('ActionRowBuilder', 'ButtonBuilder', 'ButtonStyle');
      out.push("const { " + imports.join(', ') + " } = require('discord.js');", '');
      embeds.forEach(function (e, i) {
        var v = 'embed' + (embeds.length > 1 ? i + 1 : ''), l = ['const ' + v + ' = new EmbedBuilder()'];
        if (e.title) l.push('  .setTitle(' + J(e.title) + ')');
        if (e.url) l.push('  .setURL(' + J(e.url) + ')');
        if (e.description) l.push('  .setDescription(' + J(e.description) + ')');
        if (e.color != null) l.push('  .setColor(' + hexs(e.color) + ')');
        if (e.author) l.push('  .setAuthor({ name: ' + J(e.author.name) + (e.author.icon_url ? ', iconURL: ' + J(e.author.icon_url) : '') + (e.author.url ? ', url: ' + J(e.author.url) : '') + ' })');
        if (e.thumbnail) l.push('  .setThumbnail(' + J(e.thumbnail.url) + ')');
        if (e.image) l.push('  .setImage(' + J(e.image.url) + ')');
        if (e.fields) l.push('  .addFields(\n' + e.fields.map(function (f) { return '    { name: ' + J(f.name) + ', value: ' + J(f.value) + (f.inline ? ', inline: true' : '') + ' }'; }).join(',\n') + '\n  )');
        if (e.footer) l.push('  .setFooter({ text: ' + J(e.footer.text) + (e.footer.icon_url ? ', iconURL: ' + J(e.footer.icon_url) : '') + ' })');
        if (e.timestamp) l.push(e.__now ? '  .setTimestamp()' : '  .setTimestamp(new Date(' + J(e.timestamp) + '))');
        l[l.length - 1] += ';'; out.push(l.join('\n'), '');
      });
      if (comps.length) {
        out.push('const row = new ActionRowBuilder().addComponents(');
        out.push(comps.map(function (c) {
          var names = { 1: 'Primary', 2: 'Secondary', 3: 'Success', 4: 'Danger', 5: 'Link' };
          return '  new ButtonBuilder()' + (c.url ? '.setURL(' + J(c.url) + ')' : '.setCustomId(' + J(c.custom_id) + ')') + (c.label ? '.setLabel(' + J(c.label) + ')' : '') + '.setStyle(ButtonStyle.' + names[c.style] + ')' + (c.disabled ? '.setDisabled(true)' : '');
        }).join(',\n'));
        out.push(');', '');
      }
      var opts = [];
      if (p.content) opts.push('  content: ' + J(p.content));
      if (embeds.length) opts.push('  embeds: [' + embeds.map(function (_, i) { return 'embed' + (embeds.length > 1 ? i + 1 : ''); }).join(', ') + ']');
      if (comps.length) opts.push('  components: [row]');
      out.push('// Bot:      await channel.send({\n// Webhook:  await new WebhookClient({ url: process.env.WEBHOOK_URL }).send({');
      out.push('await channel.send({\n' + opts.join(',\n') + '\n});');
      return out.join('\n');
    }
    if (kind === 'dpy') {
      var o = ['import discord', ''];
      embeds.forEach(function (e, i) {
        var v = 'embed' + (embeds.length > 1 ? i + 1 : ''), args = [];
        if (e.title) args.push('title=' + J(e.title)); if (e.description) args.push('description=' + J(e.description)); if (e.url) args.push('url=' + J(e.url)); if (e.color != null) args.push('color=' + hexs(e.color));
        if (e.timestamp) args.push(e.__now ? 'timestamp=discord.utils.utcnow()' : 'timestamp=datetime.datetime.fromisoformat(' + J(e.timestamp.replace('Z', '+00:00')) + ')');
        o.push(v + ' = discord.Embed(' + args.join(', ') + ')');
        if (e.author) o.push(v + '.set_author(name=' + J(e.author.name) + (e.author.url ? ', url=' + J(e.author.url) : '') + (e.author.icon_url ? ', icon_url=' + J(e.author.icon_url) : '') + ')');
        if (e.thumbnail) o.push(v + '.set_thumbnail(url=' + J(e.thumbnail.url) + ')');
        if (e.image) o.push(v + '.set_image(url=' + J(e.image.url) + ')');
        (e.fields || []).forEach(function (f) { o.push(v + '.add_field(name=' + J(f.name) + ', value=' + J(f.value) + ', inline=' + (f.inline ? 'True' : 'False') + ')'); });
        if (e.footer) o.push(v + '.set_footer(text=' + J(e.footer.text) + (e.footer.icon_url ? ', icon_url=' + J(e.footer.icon_url) : '') + ')');
        o.push('');
      });
      if (embeds.some(function (e) { return e.timestamp && !e.__now; })) o[0] = 'import datetime\nimport discord';
      if (comps.length) {
        o.push('view = discord.ui.View()');
        var sn = { 1: 'primary', 2: 'secondary', 3: 'success', 4: 'danger', 5: 'link' };
        comps.forEach(function (c) { o.push('view.add_item(discord.ui.Button(' + (c.label ? 'label=' + J(c.label) + ', ' : '') + 'style=discord.ButtonStyle.' + sn[c.style] + (c.url ? ', url=' + J(c.url) : ', custom_id=' + J(c.custom_id)) + (c.disabled ? ', disabled=True' : '') + '))' + (c.style !== 5 ? '  # set button.callback to handle clicks' : '')); });
        o.push('');
      }
      var a = [];
      if (p.content) a.push('content=' + J(p.content));
      if (embeds.length === 1) a.push('embed=embed'); else if (embeds.length > 1) a.push('embeds=[' + embeds.map(function (_, i) { return 'embed' + (i + 1); }).join(', ') + ']');
      if (comps.length) a.push('view=view');
      o.push('await channel.send(' + a.join(', ') + ')');
      return o.join('\n');
    }
    return '';
  }

  /* ---------------- UI scaffolding ---------------- */
  root.appendChild(ui.pageHead({ icon: 'embed', title: 'Discord Embed Builder', badge: 'Live preview', desc: 'Design rich embeds with a Discord-style preview, then export webhook JSON, discord.js, discord.py or cURL — or post straight to a webhook.' }));

  var paneState = 'edit';
  var builder = el('div', { class: 'builder', 'data-pane': 'edit' });
  var editCol = el('div', { class: 'b-edit stack' });
  var side = el('div', { class: 'b-side' });
  builder.appendChild(editCol); builder.appendChild(side);

  var paneSeg = ui.seg({ label: 'Panel', value: 'edit', options: [{ value: 'edit', label: 'Edit' }, { value: 'preview', label: 'Preview & export' }], onChange: function (v) { paneState = v; builder.setAttribute('data-pane', v); window.scrollTo({ top: 0 }); } });
  root.appendChild(el('div', { class: 'pane-switch' }, paneSeg.el));
  root.appendChild(builder);

  var changeRaf = CH.raf(function () { updateSide(); });
  var save = CH.debounce(function () { CH.Store.set('draft:embed', state); }, 500);
  function changed() { changeRaf(); save(); }

  function sec(id, ic, title, meta, body) {
    var d = el('details', { class: 'b-sec', open: openSecs[id] ? true : null }, el('summary', null, icon(ic), title, meta ? el('span', { class: 'sum-meta' }, meta) : null), el('div', { class: 'b-body' }, body));
    d.addEventListener('toggle', function () { openSecs[id] = d.open; });
    return d;
  }
  function inp(label, get, set, o) {
    o = o || {};
    var f = ui.field({ label: label, type: o.type || 'text', max: o.max, value: get(), placeholder: o.placeholder, hint: o.hint, rows: o.rows, onInput: function (v) { set(v); changed(); } });
    if (o.cls) f.el.classList.add(o.cls);
    return f;
  }
  function mdBar(ta) {
    function wrap(before, after, line) {
      var s = ta.selectionStart, e = ta.selectionEnd, v = ta.value, sel = v.slice(s, e), out;
      if (line) {
        var ls = v.lastIndexOf('\n', s - 1) + 1, block = v.slice(ls, e || s) || '';
        out = block.split('\n').map(function (l) { return before + l; }).join('\n');
        ta.value = v.slice(0, ls) + out + v.slice(e || s); ta.selectionStart = ls; ta.selectionEnd = ls + out.length;
      } else {
        ta.value = v.slice(0, s) + before + (sel || 'text') + after + v.slice(e);
        ta.selectionStart = s + before.length; ta.selectionEnd = s + before.length + (sel || 'text').length;
      }
      ta.focus(); ta.dispatchEvent(new Event('input', { bubbles: true }));
    }
    var defs = [['B', '**', '**', 'Bold'], ['I', '*', '*', 'Italic'], ['U', '__', '__', 'Underline'], ['S', '~~', '~~', 'Strikethrough'], ['`', '`', '`', 'Inline code'], ['{ }', '```\n', '\n```', 'Code block'], ['||', '||', '||', 'Spoiler'], ['❝', '> ', '', 'Quote', 1], ['•', '- ', '', 'Bullet list', 1], ['H', '## ', '', 'Heading', 1], ['Link', '[', '](https://)', 'Masked link']];
    var bar = el('div', { class: 'md-bar', role: 'toolbar', 'aria-label': 'Markdown formatting' }, defs.map(function (d) {
      var b = el('button', { type: 'button', title: d[3], 'aria-label': d[3] }, d[0]);
      if (d[0] === 'B') b.style.fontWeight = '800'; if (d[0] === 'I') b.style.fontStyle = 'italic'; if (d[0] === 'U') b.style.textDecoration = 'underline'; if (d[0] === 'S') b.style.textDecoration = 'line-through';
      b.addEventListener('click', function () { wrap(d[1], d[2], d[4]); }); return b;
    }));
    var tsb = el('button', { type: 'button', title: 'Insert a Discord timestamp that shows in every viewer’s own timezone', 'aria-label': 'Insert Discord timestamp' }, '🕒');
    tsb.addEventListener('click', function () {
      var t = '<t:' + (Math.floor(Date.now() / 1000) + 3600) + ':F>'; var s = ta.selectionStart; ta.value = ta.value.slice(0, s) + t + ta.value.slice(ta.selectionEnd); ta.selectionStart = ta.selectionEnd = s + t.length; ta.focus(); ta.dispatchEvent(new Event('input', { bubbles: true }));
    });
    bar.appendChild(tsb);
    return bar;
  }

  /* ---------------- editor ---------------- */
  function renderEditor() {
    var e = cur(), scrollY = window.scrollY;
    CH.clear(editCol);

    // toolbar
    var tb = el('div', { class: 'row' },
      ui.btn('Save template', { icon: 'save', sm: true, kind: 'primary', onclick: saveTemplate }),
      ui.btn('Example', { icon: 'sparkle', sm: true, onclick: function () { state = fromPayload(EXAMPLE); renderEditor(); changed(); CH.toast('Loaded example'); } }),
      ui.btn('Import JSON', { icon: 'upload', sm: true, onclick: function () { importBox.hidden = !importBox.hidden; if (!importBox.hidden) importTa.focus(); } }),
      ui.btn('Reset', { icon: 'trash', sm: true, kind: 'danger', onclick: function () { if (confirm('Clear everything and start from a blank embed?')) { state = blankState(); renderEditor(); changed(); } } }));
    editCol.appendChild(tb);

    var importTa = el('textarea', { class: 'textarea mono', rows: 6, placeholder: 'Paste a webhook payload ({"embeds":[…]}), an embeds array, or a single embed object', spellcheck: 'false', 'aria-label': 'JSON to import' });
    var importMsg = el('div', { class: 'hint' });
    var importBox = el('div', { class: 'card card-pad stack-sm', hidden: true }, importTa, el('div', { class: 'row' }, ui.btn('Load into builder', { kind: 'primary', sm: true, onclick: function () {
      try {
        var j = JSON.parse(importTa.value); if (Array.isArray(j)) j = { embeds: j }; else if (j && !j.embeds && !j.content && (j.title || j.description || j.fields || j.author || j.footer || j.image)) j = { embeds: [j] };
        if (!j || typeof j !== 'object') throw new Error('Expected a JSON object');
        state = fromPayload(j); renderEditor(); changed(); importBox.hidden = true; CH.toast('Imported');
      } catch (err) { importMsg.textContent = 'Couldn’t read that JSON: ' + err.message; importMsg.style.color = 'var(--bad)'; }
    } }), importMsg));
    editCol.appendChild(importBox);

    // 1) message
    var contentF = inp('Message content', function () { return state.content; }, function (v) { state.content = v; }, { type: 'textarea', max: LIM.content, rows: 3, hint: 'Optional text above the embeds. This is the only place @mentions actually ping.' });
    var wh = el('div', { class: 'form-grid' },
      inp('Webhook username', function () { return state.username; }, function (v) { state.username = v; }, { max: LIM.username, placeholder: 'Your Bot' }).el,
      inp('Webhook avatar URL', function () { return state.avatar; }, function (v) { state.avatar = v; }, { placeholder: 'https://…/avatar.png' }).el);
    editCol.appendChild(sec('msg', 'send', 'Message', 'content · webhook identity', [mdBar(contentF.input), contentF.el, wh, el('div', { class: 'hint' }, 'Username and avatar only apply when sending through a webhook; a bot uses its own profile.')]));

    // embed tabs
    var tabs = el('div', { class: 'embed-tabs', role: 'tablist', 'aria-label': 'Embeds' }, state.embeds.map(function (em, i) {
      var b = el('button', { type: 'button', class: 'embed-tab', role: 'tab', 'aria-selected': i === state.active ? 'true' : 'false' }, el('span', { class: 'dot', style: { background: em.color || '#4e5058' } }), 'Embed ' + (i + 1));
      b.addEventListener('click', function () { state.active = i; renderEditor(); changed(); }); return b;
    }));
    if (state.embeds.length < LIM.embeds) tabs.appendChild(ui.btn('Add embed', { icon: 'plus', sm: true, kind: 'ghost', onclick: function () { state.embeds.push(blankEmbed()); state.active = state.embeds.length - 1; renderEditor(); changed(); } }));
    if (state.embeds.length > 1) tabs.appendChild(ui.btn('Remove', { icon: 'trash', sm: true, kind: 'ghost', onclick: function () { state.embeds.splice(state.active, 1); state.active = Math.max(0, state.active - 1); renderEditor(); changed(); } }));
    editCol.appendChild(tabs);

    // 2) basics
    var descF = inp('Description', function () { return e.description; }, function (v) { e.description = v; }, { type: 'textarea', max: LIM.desc, rows: 6, hint: 'Supports Discord markdown, masked links and <t:UNIX:R> timestamps.' });
    var colorHex = ui.field({ label: 'Colour', value: e.color, placeholder: '#5865F2', onInput: function (v) { var t = v.trim(); if (t && t[0] !== '#') t = '#' + t; e.color = t; if (HEX.test(t)) colorPick.value = t; refreshSw(); changed(); } });
    var colorPick = el('input', { type: 'color', 'aria-label': 'Pick colour', value: HEX.test(e.color) ? e.color : '#5865f2' });
    colorPick.addEventListener('input', function () { e.color = colorPick.value.toUpperCase(); colorHex.input.value = e.color; refreshSw(); changed(); });
    var sws = COLORS.map(function (c) { var b = el('button', { type: 'button', class: 'swatch', style: { background: c[0] }, title: c[1], 'aria-label': c[1], 'aria-pressed': 'false', dataset: { c: c[0] } }); b.addEventListener('click', function () { e.color = c[0]; colorHex.input.value = c[0]; colorPick.value = c[0]; refreshSw(); changed(); }); return b; });
    var none = el('button', { type: 'button', class: 'swatch', title: 'No colour (grey bar)', 'aria-label': 'No colour', 'aria-pressed': 'false', style: { background: 'repeating-linear-gradient(45deg,#2b2d31,#2b2d31 4px,#4e5058 4px,#4e5058 8px)' } });
    none.addEventListener('click', function () { e.color = ''; colorHex.input.value = ''; refreshSw(); changed(); });
    function refreshSw() { sws.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.c.toLowerCase() === (e.color || '').toLowerCase())); }); none.setAttribute('aria-pressed', String(!e.color)); }
    refreshSw();
    var basics = [
      inp('Title', function () { return e.title; }, function (v) { e.title = v; }, { max: LIM.title, placeholder: 'Plain text — no markdown' }).el,
      inp('Title URL', function () { return e.url; }, function (v) { e.url = v; }, { placeholder: 'https://… (makes the title a link)' }).el,
      mdBar(descF.input), descF.el,
      el('div', { class: 'field' }, el('div', { class: 'label' }, 'Colour'), el('div', { class: 'row' }, colorPick, el('div', { style: { width: '120px' } }, colorHex.input), el('div', { class: 'swatches' }, sws, none)))
    ];
    editCol.appendChild(sec('basics', 'embed', 'Title, description & colour', null, basics));

    // 3) author
    editCol.appendChild(sec('author', 'user', 'Author', e.author.name ? '· ' + e.author.name.slice(0, 24) : null, [
      el('div', { class: 'form-grid' },
        inp('Author name', function () { return e.author.name; }, function (v) { e.author.name = v; }, { max: LIM.author }).el,
        inp('Author URL', function () { return e.author.url; }, function (v) { e.author.url = v; }, { placeholder: 'https://…' }).el,
        inp('Author icon URL', function () { return e.author.icon; }, function (v) { e.author.icon = v; }, { placeholder: 'https://…/icon.png', cls: 'full' }).el)]));

    // 4) images
    editCol.appendChild(sec('images', 'eye', 'Thumbnail & image', null, [
      el('div', { class: 'form-grid' },
        inp('Thumbnail URL', function () { return e.thumbnail; }, function (v) { e.thumbnail = v; }, { placeholder: 'Small image, top right' }).el,
        inp('Main image URL', function () { return e.image; }, function (v) { e.image = v; }, { placeholder: 'Large image, bottom' }).el),
      el('div', { class: 'hint' }, 'Images must be publicly reachable http(s) links (PNG, JPG, GIF, WebP). Uploading files with the message isn’t supported here.')]));

    // 5) footer + timestamp
    var tsInput = el('input', { class: 'input', type: 'datetime-local', value: e.tsValue || localInput(new Date().toISOString()), 'aria-label': 'Custom timestamp', hidden: e.ts !== 'custom' });
    tsInput.addEventListener('input', function () { e.tsValue = tsInput.value; changed(); });
    var tsSeg = ui.seg({ label: 'Timestamp', value: e.ts, options: [{ value: 'none', label: 'Off' }, { value: 'now', label: 'Now (when sent)' }, { value: 'custom', label: 'Custom' }], onChange: function (v) { e.ts = v; tsInput.hidden = v !== 'custom'; if (v === 'custom' && !e.tsValue) e.tsValue = tsInput.value; changed(); } });
    editCol.appendChild(sec('footer', 'text', 'Footer & timestamp', null, [
      el('div', { class: 'form-grid' },
        inp('Footer text', function () { return e.footer.text; }, function (v) { e.footer.text = v; }, { max: LIM.footer }).el,
        inp('Footer icon URL', function () { return e.footer.icon; }, function (v) { e.footer.icon = v; }, { placeholder: 'https://…' }).el),
      el('div', { class: 'field' }, el('div', { class: 'label' }, 'Timestamp'), tsSeg.el, tsInput,
        el('div', { class: 'hint' }, '“Now” stamps the moment Discord receives the message. Timestamps display in each viewer’s local timezone.'))]));

    // 6) fields
    var fl = el('div', { class: 'stack-sm' });
    e.fields.forEach(function (f, i) {
      var nm = inp('Name', function () { return f.name; }, function (v) { f.name = v; }, { max: LIM.fname });
      var vl = inp('Value', function () { return f.value; }, function (v) { f.value = v; }, { type: 'textarea', max: LIM.fvalue, rows: 2 });
      var sw = ui.switch({ label: 'Inline (up to 3 side by side)', checked: f.inline, onChange: function (v) { f.inline = v; changed(); } });
      function mv(d) { var j = i + d; if (j < 0 || j >= e.fields.length) return; var t = e.fields[i]; e.fields[i] = e.fields[j]; e.fields[j] = t; renderEditor(); changed(); }
      function mini(ic, label, fn, dis) { var b = el('button', { type: 'button', class: 'mini-btn', 'aria-label': label, title: label, disabled: dis ? true : null }, icon(ic)); b.addEventListener('click', fn); return b; }
      fl.appendChild(el('div', { class: 'field-item' },
        el('div', { class: 'fi-top' }, el('strong', null, 'Field ' + (i + 1)),
          mini('arrowUp', 'Move up', function () { mv(-1); }, i === 0), mini('arrowDown', 'Move down', function () { mv(1); }, i === e.fields.length - 1),
          mini('copy', 'Duplicate', function () { if (e.fields.length < LIM.fields) { e.fields.splice(i + 1, 0, { name: f.name, value: f.value, inline: f.inline }); renderEditor(); changed(); } }, e.fields.length >= LIM.fields),
          mini('trash', 'Delete field', function () { e.fields.splice(i, 1); renderEditor(); changed(); })),
        nm.el, vl.el, sw.el));
    });
    var addF = ui.btn('Add field', { icon: 'plus', sm: true, onclick: function () { if (e.fields.length >= LIM.fields) return; e.fields.push({ name: '', value: '', inline: false }); renderEditor(); changed(); } });
    if (e.fields.length >= LIM.fields) addF.disabled = true;
    editCol.appendChild(sec('fields', 'layout', 'Fields', e.fields.length + '/' + LIM.fields, [fl, el('div', { class: 'row' }, addF, el('span', { class: 'hint' }, 'Field names are plain text; values support markdown.'))]));

    // 7) buttons
    var bl = el('div', { class: 'stack-sm' });
    state.buttons.forEach(function (b, i) {
      var lab = inp('Label', function () { return b.label; }, function (v) { b.label = v; }, { max: 80 });
      var sty = ui.field({ label: 'Style', type: 'select', options: BTN_STYLES, value: b.style, onInput: function (v) { b.style = v; renderEditor(); changed(); } });
      var tgt = b.style === '5' ? inp('URL', function () { return b.url; }, function (v) { b.url = v; }, { placeholder: 'https://…' }) : inp('Custom ID', function () { return b.customId; }, function (v) { b.customId = v; }, { placeholder: 'button_' + (i + 1), hint: 'Your bot matches this ID when the button is clicked.' });
      var dis = ui.switch({ label: 'Disabled', checked: b.disabled, onChange: function (v) { b.disabled = v; changed(); } });
      var rm = el('button', { type: 'button', class: 'mini-btn', 'aria-label': 'Remove button', title: 'Remove button' }, icon('trash')); rm.addEventListener('click', function () { state.buttons.splice(i, 1); renderEditor(); changed(); });
      bl.appendChild(el('div', { class: 'field-item' }, el('div', { class: 'fi-top' }, el('strong', null, 'Button ' + (i + 1)), rm), el('div', { class: 'form-grid' }, lab.el, sty.el, tgt.el), dis.el));
    });
    var addB = ui.btn('Add button', { icon: 'plus', sm: true, onclick: function () { if (state.buttons.length < LIM.buttons) { state.buttons.push({ label: '', style: '5', url: '', customId: '', disabled: false }); openSecs.buttons = true; renderEditor(); changed(); } } });
    if (state.buttons.length >= LIM.buttons) addB.disabled = true;
    editCol.appendChild(sec('buttons', 'link', 'Buttons', state.buttons.length + '/' + LIM.buttons, [
      ui.callout('warn', el('strong', null, 'Buttons sit under the message, not inside the embed. '), 'Link buttons just open a URL. Every other style needs an application (bot) to receive the click — a plain channel webhook can’t do that.'),
      bl, el('div', { class: 'row' }, addB)]));

    window.scrollTo(0, scrollY);
  }

  /* ---------------- preview + export side ---------------- */
  var previewStage = el('div', { class: 'preview-stage' });
  var themeSeg = ui.seg({ label: 'Preview theme', value: theme, options: [{ value: 'dark', label: 'Dark' }, { value: 'light', label: 'Light' }], onChange: function (v) { theme = v; updateSide(); } });
  var issuesBox = el('div', { class: 'issues', 'aria-live': 'polite' });
  var meter = el('div', { class: 'meter' }, el('i')), meterTxt = el('span', { class: 'counter' });
  var codePre = el('pre', { class: 'out-box export-pre', tabindex: '0', 'aria-label': 'Exported code' });
  var exportTabs = ui.tabs({ label: 'Export format', value: exportKind, items: [{ id: 'json', label: 'Webhook JSON' }, { id: 'embeds', label: 'Embeds array' }, { id: 'djs', label: 'discord.js' }, { id: 'dpy', label: 'discord.py' }, { id: 'curl', label: 'cURL' }], onChange: function (v) { exportKind = v; updateSide(); } });
  var exportNote = el('div', { class: 'hint' });
  var NOTES = {
    json: 'The body Discord’s “Execute Webhook” endpoint expects. Also valid for bots via the REST API (omit username/avatar_url).',
    embeds: 'Just the embeds array — handy when your bot builds the message itself.',
    djs: 'discord.js v14. “Now” timestamps use .setTimestamp(). Button handlers are up to you.',
    dpy: 'discord.py 2.x. Link buttons work as-is; other styles need a callback.',
    curl: 'Replace WEBHOOK_ID/WEBHOOK_TOKEN with your own webhook. Keep that URL private.'
  };

  var previewCard = el('div', { class: 'card preview-card' },
    el('div', { class: 'preview-top' }, el('strong', { class: 'card-title' }, 'Preview'), themeSeg.el),
    previewStage,
    el('div', { class: 'card-pad', style: { paddingTop: '12px', paddingBottom: '14px', borderTop: '1px solid var(--line)' } },
      el('div', { class: 'row-between', style: { marginBottom: '6px' } }, el('span', { class: 'label' }, 'Embed text budget'), meterTxt), meter,
      el('div', { style: { marginTop: '12px' } }, issuesBox)));

  var exportCard = el('div', { class: 'card' },
    el('div', { class: 'card-pad stack-sm' },
      el('div', { class: 'row-between' }, el('strong', { class: 'card-title' }, 'Export'),
        el('div', { class: 'row' }, ui.btn('Copy', { icon: 'copy', sm: true, kind: 'primary', onclick: function () { CH.copy(exportCode(exportKind)); } }),
          ui.btn('Download', { icon: 'download', sm: true, onclick: function () { var ext = { json: 'json', embeds: 'json', djs: 'js', dpy: 'py', curl: 'sh' }[exportKind]; CH.download('embed.' + ext, exportCode(exportKind), 'text/plain'); } }))),
      exportTabs.el, codePre, exportNote));

  // webhook sender
  var whUrl = el('input', { class: 'input', type: 'password', placeholder: 'https://discord.com/api/webhooks/…', autocomplete: 'off', spellcheck: 'false', 'aria-label': 'Webhook URL' });
  var whStatus = el('div', { class: 'hint', 'aria-live': 'polite' });
  var sendBtn = ui.btn('Send message', { icon: 'send', sm: true, onclick: sendWebhook });
  var whCard = el('details', { class: 'acc' }, el('summary', null, icon('send'), 'Send through a webhook', el('span', { class: 'acc-sum-meta' }, 'optional')),
    el('div', { class: 'acc-body' },
      ui.callout('warn', el('strong', null, 'Treat the webhook URL like a password. '), 'Anyone who has it can post to your channel. It’s sent only to Discord, never stored by this site, and cleared when you leave the page.'),
      el('div', { class: 'field' }, el('label', { class: 'label' }, 'Webhook URL'), whUrl, el('div', { class: 'hint' }, 'Create one in Server Settings → Integrations → Webhooks.')),
      el('div', { class: 'row' }, sendBtn, whStatus)));

  side.appendChild(previewCard); side.appendChild(exportCard); side.appendChild(whCard);

  function sendWebhook() {
    var u = whUrl.value.trim();
    if (!/^https:\/\/(?:(?:ptb|canary)\.)?discord(?:app)?\.com\/api(?:\/v\d+)?\/webhooks\/\d+\/[\w-]+\/?$/.test(u)) { whStatus.textContent = 'That doesn’t look like a Discord webhook URL.'; whStatus.style.color = 'var(--bad)'; return; }
    var v = validate(), errs = v.issues.filter(function (i) { return i.l === 'error'; });
    if (errs.length) { whStatus.textContent = 'Fix the errors in the preview panel first (' + errs.length + ').'; whStatus.style.color = 'var(--bad)'; return; }
    if (!confirm('Post this message to the channel your webhook points at? It will be visible to everyone who can read that channel.')) return;
    var p = payload(false), q = '?wait=true' + (p.components ? '&with_components=true' : '');
    sendBtn.disabled = true; whStatus.style.color = ''; whStatus.textContent = 'Sending…';
    fetch(u.replace(/\/$/, '') + q, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(p) })
      .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { return { ok: r.ok, status: r.status, j: j }; }); })
      .then(function (r) {
        if (r.ok) { whStatus.style.color = 'var(--ok)'; whStatus.textContent = 'Sent ✓ — check your channel.'; CH.toast('Message sent'); }
        else { whStatus.style.color = 'var(--bad)'; whStatus.textContent = 'Discord said ' + r.status + (r.j && r.j.message ? ': ' + r.j.message : '') + (r.status === 429 ? ' — you’re being rate limited, wait a moment.' : ''); }
      })
      .catch(function () { whStatus.style.color = 'var(--bad)'; whStatus.textContent = 'The request was blocked (offline, network filter, or browser extension).'; })
      .then(function () { sendBtn.disabled = false; });
  }

  function updateSide() {
    // preview
    CH.clear(previewStage); previewStage.classList.toggle('light', theme === 'light');
    previewStage.appendChild(CH.preview.message(payload(true), { theme: theme, defaultName: 'Your Bot' }));
    // validation + meter
    var v = validate();
    var pct = Math.min(100, v.total / LIM.total * 100);
    meter.firstChild.style.width = pct + '%'; meter.className = 'meter' + (v.total > LIM.total ? ' bad' : v.total > LIM.total * .85 ? ' warn' : '');
    meterTxt.textContent = v.total + ' / ' + LIM.total; meterTxt.className = 'counter' + (v.total > LIM.total ? ' bad' : v.total > LIM.total * .85 ? ' warn' : '');
    CH.clear(issuesBox);
    if (!v.issues.length) issuesBox.appendChild(el('div', { class: 'issue ok' }, icon('check'), 'Looks valid — within every Discord limit this tool checks.'));
    v.issues.forEach(function (i) { issuesBox.appendChild(el('div', { class: 'issue ' + i.l }, icon(i.l === 'error' ? 'x' : 'alert'), i.m)); });
    // export
    codePre.textContent = exportCode(exportKind); exportNote.textContent = NOTES[exportKind];
    // tab dots
    CH.$$('.embed-tab .dot', editCol).forEach(function (d, i) { d.style.background = state.embeds[i].color || '#4e5058'; });
  }

  function saveTemplate() {
    var def = (cur().title || 'Embed template').slice(0, 40);
    var name = prompt('Name this template', def); if (name == null) return; name = name.trim() || def;
    var p = payload(false);
    if (!Object.keys(p).length) { CH.toast('Nothing to save yet', 'bad'); return; }
    var r = CH.Saved.add({ type: 'embed', title: name, body: JSON.stringify(p, null, 2), data: { payload: p } });
    CH.toast(r.dupe ? 'That exact template is already saved' : 'Template saved');
  }

  /* ---------------- limitations ---------------- */
  var lim = el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('div', null, el('h2', null, 'What Discord supports — and what it doesn’t'), el('p', null, 'This tool never promises more than Discord allows. Verify anything critical against Discord’s developer documentation, which changes over time.'))),
    ui.acc('Who can send embeds?', [
      el('p', null, 'Only applications (bots) and webhooks can send rich embeds. A normal user account cannot, and automating a user account to do it (a “self-bot”) violates Discord’s Terms of Service.'),
      el('p', null, 'The simplest no-code route is a channel webhook: Server Settings → Integrations → Webhooks → New Webhook → Copy URL. Paste it into “Send through a webhook” above, or use the cURL export.')], { open: true }),
    ui.acc('Hard limits (checked live)', el('ul', null,
      el('li', null, 'Up to ', el('strong', null, '10 embeds'), ' per message; message content up to 2,000 characters.'),
      el('li', null, 'Title 256 · description 4,096 · author name 256 · footer text 2,048.'),
      el('li', null, 'Up to 25 fields; field name 256 · field value 1,024; both must be non-empty.'),
      el('li', null, el('strong', null, '6,000 characters combined'), ' across title, description, field names/values, footer and author of every embed in a message.'))),
    ui.acc('Formatting rules', el('ul', null,
      el('li', null, 'Description and field values support Discord markdown, including masked links ', el('code', null, '[text](https://…)'), ', code blocks, quotes, spoilers and headings.'),
      el('li', null, 'Title, author name, footer text and field names are plain text. A title becomes a link through the Title URL.'),
      el('li', null, 'Mentions inside embeds render but never notify anyone. Pings only work from the message content.'),
      el('li', null, 'Timestamp tags like ', el('code', null, '<t:1735689600:R>'), ' are shown in each viewer’s own timezone.'))),
    ui.acc('Images', el('ul', null,
      el('li', null, 'One thumbnail and one main image per embed, as public http(s) URLs. Discord fetches and caches them, so private or expiring links will break.'),
      el('li', null, 'Attaching files (the ', el('code', null, 'attachment://'), ' syntax) needs a multipart upload, which this tool doesn’t do.'))),
    ui.acc('Buttons and interactivity', el('ul', null,
      el('li', null, 'Buttons are message components that appear under the message, not part of the embed.'),
      el('li', null, 'Link buttons open a URL and need no bot code. Primary, secondary, success and danger buttons need an application to receive the interaction and respond.'),
      el('li', null, 'Webhooks created by hand in a channel have limited component support and must opt in with ', el('code', null, '?with_components=true'), '. Check Discord’s current docs before depending on buttons from a plain webhook — a bot is the reliable route.'),
      el('li', null, 'Select menus, modals and the newer layout components aren’t covered by this builder.'))),
    ui.acc('Preview accuracy', el('p', null, 'The preview closely mimics Discord’s desktop look, but fonts, spacing and mobile layout differ slightly and Discord updates its client regularly. Always send a test message to a private channel before announcing.')));
  root.appendChild(lim);

  renderEditor(); updateSide();
  return function () { whUrl.value = ''; CH.Store.set('draft:embed', state); };
});
