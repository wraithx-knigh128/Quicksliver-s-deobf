/* Announcement Generator — structured composer with Discord timestamp tags. */
CH.page('announcements', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, fresh = CH.fresh, chance = CH.chance;

  var T = {
    event: { label: 'Event', e: '🎉', noun: 'event', def: 'our next event', when: 'When', link: 'Where', heads: ['What to expect', 'The plan', 'Details', 'What’s on'], extra: ['Bring friends — the more, the better.', 'Everyone’s welcome, newcomers especially.', 'Hop into voice early if you can.'], color: 0x7c6cff },
    update: { label: 'Update / patch notes', e: '🛠️', noun: 'update', def: 'a new update', when: 'Live', link: 'Read more', heads: ['What’s new', 'Changes', 'Highlights', 'Patch notes'], extra: ['Thanks to everyone whose feedback shaped this.', 'Found a bug? Tell us in the feedback channel.'], color: 0x35d4ff },
    giveaway: { label: 'Giveaway', e: '🎁', noun: 'giveaway', def: 'a giveaway', when: 'Ends', link: 'Enter here', heads: ['How to enter', 'How it works', 'What you could win'], extra: ['Winners are picked at random and announced here.', 'Keep your DMs open so we can reach you.', 'You need to be a member of the server to win.'], color: 0xEB459E },
    maintenance: { label: 'Maintenance', e: '🔧', noun: 'maintenance window', def: 'scheduled maintenance', when: 'Starts', link: 'Status', heads: ['What to expect', 'What’s affected', 'Details'], extra: ['Some features may be unavailable while we work.', 'We’ll post here as soon as we’re done.', 'Thanks for your patience.'], color: 0xFEE75C },
    welcome: { label: 'Welcome', e: '👋', noun: 'welcome', def: 'our community', when: 'When', link: 'Start here', heads: ['Start here', 'Quick start', 'Your first steps'], extra: ['New here? Say hi and tell us what you’re into.', 'Check the rules and grab your roles.', 'Don’t be shy — we’re friendly.'], color: 0x57F287 },
    partnership: { label: 'Partnership', e: '🤝', noun: 'partnership', def: 'a new partnership', when: 'When', link: 'Check them out', heads: ['About them', 'Why we’re excited', 'What they offer'], extra: ['Go say hi and tell them we sent you.', 'We only partner with communities we’d join ourselves.'], color: 0x5865F2 },
    recruitment: { label: 'Staff recruitment', e: '🛡️', noun: 'application', def: 'staff applications', when: 'Applications close', link: 'Apply here', heads: ['What we’re looking for', 'Requirements', 'The role'], extra: ['Active, kind and fair beats experienced.', 'No experience? We’ll train the right people.'], color: 0x5865F2 },
    poll: { label: 'Poll / vote', e: '🗳️', noun: 'vote', def: 'a community vote', when: 'Voting closes', link: 'Vote here', heads: ['The options', 'Choices', 'On the ballot'], extra: ['Every vote counts — make yours.', 'Results will be posted once voting closes.'], color: 0x35d4ff },
    milestone: { label: 'Milestone', e: '🏆', noun: 'milestone', def: 'a big milestone', when: 'When', link: 'Link', heads: ['Highlights', 'By the numbers', 'What we’re proud of'], extra: ['We couldn’t have done it without you.', 'Here’s to the next chapter.'], color: 0xFEE75C },
    rulechange: { label: 'Rule change', e: '📜', noun: 'rule change', def: 'a rules update', when: 'Effective', link: 'Read the rules', heads: ['What changed', 'The changes', 'Updates to the rules'], extra: ['Please re-read the updated rules.', 'Questions? Ask a staff member.'], color: 0xED4245 }
  };
  var TYPE_ORDER = ['event', 'update', 'giveaway', 'maintenance', 'welcome', 'partnership', 'recruitment', 'poll', 'milestone', 'rulechange'];

  var HEAD = {
    hype: ['{e} {title} is HAPPENING', '{e} It’s time — {title}!', '{e} {title} is almost here', '{e} Get ready for {title}', '{e} {title}. You won’t want to miss it.'],
    friendly: ['{e} {title}', '{e} Heads up — {title}', '{e} We’ve got something for you: {title}', '{e} Quick note about {title}'],
    professional: ['{title}', 'Announcement: {title}', 'Notice — {title}', '{title} — details inside'],
    minimal: ['{title}', '{e} {title}', '{title}.'],
    serious: ['Important: {title}', 'Please read: {title}', 'Notice: {title}']
  };
  var HEAD_TYPE = {
    giveaway: { hype: ['{e} GIVEAWAY — {title}', '{e} Win big: {title}', '{e} Giveaway time: {title}'], friendly: ['{e} Giveaway: {title}', '{e} We’re giving something away — {title}'], professional: ['Giveaway: {title}', 'Giveaway announcement — {title}'] },
    maintenance: { hype: ['{e} Quick pit stop: {title}'], friendly: ['{e} Heads up — {title}', '{e} {title} incoming'], professional: ['Scheduled maintenance: {title}', 'Maintenance notice — {title}'], serious: ['Scheduled maintenance: {title}', 'Service notice: {title}'] },
    update: { hype: ['{e} NEW: {title}', '{e} {title} just dropped'], friendly: ['{e} What’s new: {title}', '{e} {title} is here'], professional: ['Update: {title}', 'Release notes — {title}'] },
    welcome: { hype: ['{e} Welcome to {server}!', '{e} You made it! Welcome to {server}'], friendly: ['{e} Welcome to {server}', '{e} Hey, welcome to {server}!'], professional: ['Welcome to {server}', 'Welcome — {server}'] },
    recruitment: { hype: ['{e} {server} wants YOU: {title}', '{e} Join the team: {title}'], friendly: ['{e} We’re hiring: {title}', '{e} Join our team — {title}'], professional: ['Open applications: {title}', 'Recruitment — {title}'] },
    milestone: { hype: ['{e} WE DID IT — {title}', '{e} {title}!!'], friendly: ['{e} We hit a milestone: {title}', '{e} {title} — thank you!'], professional: ['Milestone: {title}', 'Community milestone — {title}'] },
    rulechange: { friendly: ['{e} Updates to the rules', '{e} Small rule update'], professional: ['Rule update: {title}', 'Updated server rules'], serious: ['Rule change: {title}', 'Important: updated rules'] }
  };
  var INTRO = {
    hype: ['We’ve got a {noun} coming up and it’s going to be good.', '{server} is about to get louder — here’s the rundown.', 'Clear your schedule. Here’s what’s coming to {server}.'],
    friendly: ['Hey {server}! Here’s what’s going on.', 'Quick update for everyone in {server}:', 'Hi everyone — a few details you’ll want to know.'],
    professional: ['We’d like to share an update regarding {title}.', 'Please see the details below regarding {title}.', 'The {server} team is announcing the following.'],
    minimal: ['Details below.', 'Quick notice.', ''],
    serious: ['Please read this announcement carefully.', 'This affects all members of {server}.', 'Important information for {server} follows.']
  };
  var CTA = {
    hype: ['Don’t miss it!', 'See you there!', 'Be there. It’ll be worth it.'], friendly: ['Hope to see you there!', 'Join us — it’ll be fun.', 'Can’t wait to see you all.'],
    professional: ['Please reach out with any questions.', 'Thank you for your attention.', 'Questions are welcome in the support channel.'], minimal: [''], serious: ['Thank you for your understanding.', 'Contact staff with any questions.']
  };
  var COLORS = { hype: null, friendly: 0x57F287, professional: 0x5865F2, minimal: 0x4e5058, serious: 0xED4245 };

  function unixOf(v) { var t = Date.parse(v); return isNaN(t) ? 0 : Math.floor(t / 1000); }
  function fill(s, v) { return s.replace(/\{(\w+)\}/g, function (m, k) { return v[k] != null ? v[k] : ''; }).replace(/\s+/g, ' ').replace(/\s+([!?.,—:])/g, '$1').trim(); }
  function plainWhen(v) { var d = new Date(v); if (isNaN(d)) return ''; var tz = ''; try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone; } catch (e) {} return d.toLocaleString([], { weekday: 'long', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit' }) + (tz ? ' (' + tz + ')' : ''); }

  function build(f) {
    var ty = T[f.type], tone = f.tone, md = f.format === 'markdown', lvl = f.emoji;
    var title = f.title.trim() || ty.def, server = f.server.trim() || 'the server';
    var v = { title: title, server: server, noun: ty.noun, e: lvl === 'none' ? '' : ty.e };
    var heads = (HEAD_TYPE[f.type] && HEAD_TYPE[f.type][tone]) || HEAD[tone];
    var head = fill(fresh('ann:head:' + f.type + tone, heads), v);
    if (lvl === 'lots' && chance(.7)) head += ' ' + ty.e;
    var intro = fill(fresh('ann:intro:' + tone, INTRO[tone]), v);
    var extra = fill(fresh('ann:extra:' + f.type, ty.extra), v);
    var bullets = f.details.split('\n').map(function (x) { return x.trim().replace(/^[-*•]\s*/, ''); }).filter(Boolean);
    var label = fresh('ann:label:' + f.type, ty.heads);
    var cta = f.cta.trim() || fill(fresh('ann:cta:' + tone, CTA[tone]), v);
    var unix = f.when ? unixOf(f.when) : 0;
    var bulletMark = lvl === 'lots' ? pick(['✨', '▫️', '🔹']) : '•';
    var short = f.length === 'short', long = f.length === 'long';

    var lines = [];
    var ping = f.ping === 'everyone' ? '@everyone' : f.ping === 'here' ? '@here' : (f.ping === 'role' && f.role.trim() ? '@' + f.role.trim().replace(/^@/, '') : '');
    var hl = tone === 'minimal' ? (md ? '**' + head + '**' : head) : (tone === 'professional' || tone === 'serious') ? (md ? '## ' + head : head.toUpperCase()) : (md ? '# ' + head : head.toUpperCase());
    lines.push(hl);
    if (!short && intro) lines.push('', intro);
    if (long && extra && chance(.8) && f.type !== 'maintenance') lines.push(extra);
    if (bullets.length) {
      var shown = short ? bullets.slice(0, 2) : (f.length === 'medium' ? bullets.slice(0, 5) : bullets);
      lines.push('');
      if (!short) lines.push(md ? '**' + (lvl === 'lots' ? '📌 ' : '') + label + '**' : label.toUpperCase());
      shown.forEach(function (b) { lines.push((md ? '- ' : bulletMark + ' ') + b); });
    }
    var meta = [];
    if (unix && ty.when) {
      var wl = ty.when, w = md ? '<t:' + unix + ':F>' + (short ? '' : ' (<t:' + unix + ':R>)') : plainWhen(f.when);
      meta.push((lvl !== 'none' ? '🗓️ ' : '') + (md ? '**' + wl + ':** ' : wl + ': ') + w);
    }
    if (f.link.trim()) meta.push((lvl !== 'none' ? '📍 ' : '') + (md ? '**' + ty.link + ':** ' : ty.link + ': ') + f.link.trim());
    if (meta.length) lines.push('', meta.join('\n'));
    if (!short && cta) lines.push('', cta);
    if (f.signoff.trim()) lines.push(md ? '-# — ' + f.signoff.trim() : '— ' + f.signoff.trim());
    var body = lines.join('\n').replace(/\n{3,}/g, '\n\n');
    var text = (ping ? ping + '\n' : '') + body;

    // embed version of the same content
    var d = [];
    if (!short && intro) d.push(intro);
    if (long && extra && f.type !== 'maintenance') d.push(extra);
    if (bullets.length) d.push((short ? '' : '**' + label + '**\n') + bullets.slice(0, short ? 2 : 12).map(function (b) { return '• ' + b; }).join('\n'));
    if (unix && ty.when) d.push('**' + ty.when + ':** <t:' + unix + ':F> (<t:' + unix + ':R>)');
    if (f.link.trim()) d.push('**' + ty.link + ':** ' + f.link.trim());
    if (!short && cta) d.push(cta);
    var emb = { title: head.slice(0, 256), description: d.join('\n\n').slice(0, 4096), color: COLORS[tone] == null ? ty.color : COLORS[tone] };
    if (f.signoff.trim()) emb.footer = { text: f.signoff.trim().slice(0, 2048) };
    var payload = { embeds: [emb] }; if (ping) payload.content = ping;
    return { text: text, label: ty.label + ' · ' + CH.cap(tone), data: { payload: payload } };
  }

  /* ---------------- UI ---------------- */
  var form = Object.assign({ type: 'event', server: '', title: '', details: '', when: '', link: '', cta: '', signoff: '', ping: 'none', role: '', tone: 'friendly', emoji: 'some', length: 'medium', format: 'markdown' }, CH.Store.get('form:announce', {}));
  function persist() { CH.Store.set('form:announce', form); }

  root.appendChild(ui.pageHead({ icon: 'megaphone', title: 'Announcement Generator', desc: 'Pick a type, add the facts, and get several ready-to-post variations. Dates become Discord timestamp tags that show in every member’s own timezone.' }));

  var typeChips = ui.chips({ label: 'Announcement type', value: form.type, options: TYPE_ORDER.map(function (k) { return { value: k, label: T[k].label }; }), onChange: function (v) { form.type = v; persist(); syncLabels(); } });
  function tf(key, label, ph, o) { o = o || {}; return ui.field({ label: label, type: o.type || 'text', rows: o.rows, value: form[key], placeholder: ph, hint: o.hint, onInput: function (v) { form[key] = v; persist(); if (key === 'when') syncLabels(); } }); }
  var titleF = tf('title', 'Title / subject', 'Friday Game Night');
  var detailsF = tf('details', 'Key points', 'One per line:\nCustom lobbies from 8 PM\nPrizes for the top 3\nVoice stays open all night', { type: 'textarea', rows: 5, hint: 'Each line becomes a bullet.' });
  var whenF = tf('when', 'Date & time', '', { type: 'datetime-local', hint: 'Uses your device’s timezone to create a universal timestamp.' });
  function syncLabels() { var w = T[form.type].when; whenF.el.querySelector('label span').textContent = 'Date & time — ' + w.toLowerCase(); }
  var pingF = ui.field({ label: 'Ping', type: 'select', value: form.ping, options: [{ value: 'none', label: 'No ping' }, { value: 'here', label: '@here (online members)' }, { value: 'everyone', label: '@everyone' }, { value: 'role', label: 'A role…' }], onInput: function (v) { form.ping = v; persist(); roleF.el.style.display = v === 'role' ? '' : 'none'; warn.hidden = v !== 'everyone' && v !== 'here'; } });
  var roleF = tf('role', 'Role name', 'Events', { hint: 'Swap it for a real mention (<@&ROLE_ID>) before posting if you want it to ping.' }); roleF.el.style.display = form.ping === 'role' ? '' : 'none';
  var warn = ui.callout('warn', 'Only members with the Mention Everyone permission can use @everyone / @here, and members can mute them. Keep them for things that really matter.'); warn.hidden = form.ping !== 'everyone' && form.ping !== 'here';
  var toneChips = ui.chips({ label: 'Tone', sm: true, value: form.tone, options: [{ value: 'hype', label: 'Hype' }, { value: 'friendly', label: 'Friendly' }, { value: 'professional', label: 'Professional' }, { value: 'minimal', label: 'Minimal' }, { value: 'serious', label: 'Serious' }], onChange: function (v) { form.tone = v; persist(); } });
  var emojiSeg = ui.seg({ label: 'Emoji', value: form.emoji, options: [{ value: 'none', label: 'None' }, { value: 'some', label: 'Some' }, { value: 'lots', label: 'Lots' }], onChange: function (v) { form.emoji = v; persist(); } });
  var lenSeg = ui.seg({ label: 'Length', value: form.length, options: [{ value: 'short', label: 'Short' }, { value: 'medium', label: 'Medium' }, { value: 'long', label: 'Long' }], onChange: function (v) { form.length = v; persist(); } });
  var fmtSeg = ui.seg({ label: 'Format', value: form.format, options: [{ value: 'markdown', label: 'Discord markdown' }, { value: 'plain', label: 'Plain text' }], onChange: function (v) { form.format = v; persist(); } });

  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'What are you announcing?'), typeChips.el),
    el('div', { class: 'form-section' }, el('h3', null, 'The facts'), el('div', { class: 'form-grid' }, tf('server', 'Server name', 'Nebula Lounge').el, titleF.el), detailsF.el, whenF.el,
      el('div', { class: 'form-grid' }, tf('link', 'Link', 'https://… or #channel').el, tf('signoff', 'Sign-off', 'The Nebula Team').el), tf('cta', 'Call to action', 'Optional — overrides the generated one').el),
    el('div', { class: 'form-section' }, el('h3', null, 'Ping'), pingF.el, roleF.el, warn),
    el('div', { class: 'form-section' }, el('h3', null, 'Voice'), el('div', { class: 'field' }, el('div', { class: 'label' }, 'Tone'), toneChips.el), el('div', { class: 'row' }, emojiSeg.el, lenSeg.el), fmtSeg.el),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate announcements', { kind: 'primary', icon: 'sparkle', onclick: run })));
  syncLabels();

  var results = ui.results({
    type: 'announcement', limit: 2000, label: 'Announcement', mono: false, titleOf: function (it) { return (it.text.split('\n').filter(function (l) { return l && !/^@/.test(l); })[0] || 'Announcement').replace(/^[#*\s]+|\*+$/g, ''); },
    regen: function () { return build(form); },
    extra: function (it) {
      var b = el('button', { type: 'button', class: 'act', 'aria-label': 'Open in embed builder' }, icon('embed'), el('span', null, 'Embed'));
      b.addEventListener('click', function () { CH.handoff.set('embed', it.data.payload); location.hash = '#/embeds'; }); return b;
    }
  });
  var note = el('p', { class: 'hint', style: { marginTop: '14px' } }, 'Discord markdown is rendered by Discord when you paste it: headings, bold, bullet lists and timestamp tags all work in normal messages. “Embed” sends the same content to the Embed Builder.');
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, el('div', { class: 'card card-pad' }, el('div', { class: 'results-head' }, el('h2', null, 'Your announcements'), ui.btn('Generate again', { icon: 'refresh', sm: true, onclick: run })), results.el, note)));

  function run() {
    var out = [], seen = {}, tries = 0;
    while (out.length < 4 && tries++ < 30) { var b = build(form); if (!seen[b.text]) { seen[b.text] = 1; out.push(b); } }
    results.set(out);
  }
  run();
});
