/* Templates — ready-made messages as real webhook payloads. Replace placeholder channel IDs, links and times before posting. */
CH.page('templates', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var now = Math.floor(Date.now() / 1000), DAY = 86400;
  var CH1 = '<#1100000000000000001>', CH2 = '<#1100000000000000002>', CH3 = '<#1100000000000000003>';
  function link(label, url) { return { type: 2, style: 5, label: label, url: url || 'https://example.com' }; }
  function row() { return [{ type: 1, components: [].slice.call(arguments) }]; }

  var LIB = [
    { id: 'welcome', name: 'Welcome message', tag: 'Onboarding', desc: 'Greets new members and points them to rules, roles and introductions.', payload: { embeds: [{ title: '👋 Welcome to Nebula Lounge', description: 'We’re glad you’re here. Take a minute to get set up:\n\n**1.** Read the rules in ' + CH1 + '\n**2.** Pick your roles in ' + CH2 + '\n**3.** Introduce yourself in ' + CH3, color: 0x57F287, footer: { text: 'Enjoy your stay' } }], components: row(link('Rules'), link('Roles')) } },
    { id: 'verify', name: 'Verification panel', tag: 'Onboarding', bot: true, desc: 'A verify button that a bot turns into a role grant.', payload: { embeds: [{ title: '✅ Verify to unlock the server', description: 'Press the button below to confirm you’ve read the rules. You’ll get access to the rest of the channels straight away.', color: 0x5865F2 }], components: row({ type: 2, style: 3, label: 'Verify', custom_id: 'verify' }) } },
    { id: 'rules', name: 'Rules', tag: 'Onboarding', desc: 'A compact five-rule set. For a full set, use the Rules Generator.', payload: { embeds: [{ title: '📜 Server Rules', description: 'Keep it fun, keep it kind.', color: 0x5865F2, fields: [{ name: '1. Be respectful', value: 'No harassment, hate speech or personal attacks.' }, { name: '2. Keep it safe for work', value: 'No NSFW or graphic content.' }, { name: '3. No spam or ads', value: 'Ask staff before promoting anything.' }, { name: '4. Protect privacy', value: 'Never share personal information.' }, { name: '5. Listen to staff', value: 'Raise concerns privately, not in public chat.' }], footer: { text: 'Breaking the rules may lead to a timeout, kick or ban.' } }] } },
    { id: 'announcement', name: 'Announcement', tag: 'Announcements', desc: 'A clean, neutral announcement with a timestamp footer.', payload: { content: '', embeds: [{ title: '📢 Announcement', description: 'Write your news here. Keep the first line short — people skim.\n\n- Key point one\n- Key point two\n- Key point three', color: 0x7c6cff, footer: { text: 'Posted by the Nebula team' }, timestamp: new Date().toISOString() }] } },
    { id: 'changelog', name: 'Changelog', tag: 'Announcements', desc: 'Patch notes with an easy-to-scan diff block.', payload: { embeds: [{ title: 'Version 1.4.0 — Patch notes', description: '```diff\n+ Added dark mode\n+ New /profile command\n- Removed legacy commands\n! Fixed a bug where roles reset on rejoin\n```', color: 0x35d4ff, footer: { text: 'Released' }, timestamp: new Date().toISOString() }] } },
    { id: 'giveaway', name: 'Giveaway', tag: 'Events', desc: 'Prize, end time and host. Pair with a giveaway bot to draw winners.', payload: { embeds: [{ title: '🎁 Giveaway: $25 gift card', description: 'React with 🎉 to enter. Winners are picked at random.', color: 0xEB459E, fields: [{ name: 'Ends', value: '<t:' + (now + 3 * DAY) + ':R>', inline: true }, { name: 'Winners', value: '1', inline: true }, { name: 'Hosted by', value: 'The Nebula team', inline: true }], footer: { text: 'Must be a member to win' } }] } },
    { id: 'event', name: 'Event invite', tag: 'Events', desc: 'When, where and who — with times that adapt to every viewer’s timezone.', payload: { embeds: [{ title: '🎮 Game Night', description: 'Bring a friend and your best chaos energy. Custom lobbies, prizes and no pressure.', color: 0x7c6cff, fields: [{ name: 'When', value: '<t:' + (now + 7 * DAY) + ':F>\n(<t:' + (now + 7 * DAY) + ':R>)', inline: true }, { name: 'Where', value: CH1, inline: true }, { name: 'Hosts', value: 'Mods & friends', inline: true }] }], components: row(link('Add to calendar')) } },
    { id: 'poll', name: 'Community vote', tag: 'Events', desc: 'A reaction-style vote. Discord also has native polls built in.', payload: { embeds: [{ title: '🗳️ Community vote', description: 'What should we do next?\n\n1️⃣ Movie night\n2️⃣ Tournament weekend\n3️⃣ Karaoke\n\nReact below to vote. Results in <t:' + (now + 2 * DAY) + ':R>.', color: 0x35d4ff }] } },
    { id: 'ticket', name: 'Ticket panel', tag: 'Support', bot: true, desc: 'A “Need help?” panel for ticket bots such as Ticket Tool.', payload: { embeds: [{ title: '🎫 Need help?', description: 'Press the button to open a private ticket with our staff. Please describe your problem clearly and include screenshots if you can.', color: 0x5865F2, footer: { text: 'We usually reply within a day.' } }], components: row({ type: 2, style: 1, label: 'Open a ticket', custom_id: 'open_ticket' }) } },
    { id: 'faq', name: 'FAQ', tag: 'Support', desc: 'Four questions and answers in a tidy list.', payload: { embeds: [{ title: '❓ Frequently asked questions', color: 0xFEE75C, fields: [{ name: 'How do I get a role?', value: 'Head to ' + CH2 + ' and pick the roles you want.' }, { name: 'How do I report someone?', value: 'Open a ticket or message a moderator with screenshots.' }, { name: 'Can I advertise here?', value: 'Only in the promo channel, and only once a week.' }, { name: 'How do I become staff?', value: 'Applications open now and then — watch announcements.' }] }] } },
    { id: 'staff', name: 'Staff applications', tag: 'Community', desc: 'Requirements, deadline and an apply button.', payload: { embeds: [{ title: '🛡️ Staff applications are open', description: 'We’re looking for kind, active members to help keep Nebula Lounge welcoming.', color: 0x5865F2, fields: [{ name: 'Requirements', value: '- Active for 30+ days\n- Clean record\n- Good communication' }, { name: 'Closes', value: '<t:' + (now + 14 * DAY) + ':R>', inline: true }], footer: { text: 'No experience needed — we’ll train you.' } }], components: row(link('Apply now')) } },
    { id: 'partner', name: 'Partner spotlight', tag: 'Community', desc: 'Introduce a partner server with a join button.', payload: { embeds: [{ author: { name: 'Partner spotlight' }, title: 'Pixel Pals', description: 'A friendly community for pixel artists to share work, trade tips and run weekly challenges.', color: 0xEB459E, fields: [{ name: 'Focus', value: 'Pixel art', inline: true }, { name: 'Vibe', value: 'Supportive', inline: true }, { name: 'Language', value: 'English', inline: true }] }], components: row(link('Join Pixel Pals')) } },
    { id: 'serverinfo', name: 'Server info', tag: 'Community', desc: 'At-a-glance facts about your server.', payload: { embeds: [{ title: 'ℹ️ About Nebula Lounge', description: 'A chill community for people who like games, music and good company.', color: 0x7c6cff, fields: [{ name: 'Founded', value: '2024', inline: true }, { name: 'Language', value: 'English', inline: true }, { name: 'Age', value: '16+', inline: true }, { name: 'Channels to start with', value: CH1 + ' · ' + CH2 + ' · ' + CH3 }] }] } },
    { id: 'live', name: 'Live now', tag: 'Announcements', desc: 'A stream alert with a watch button.', payload: { content: '@everyone', embeds: [{ author: { name: 'NebulaStreams is live!' }, title: 'Chill co-op night — come hang out', url: 'https://example.com/live', color: 0x9146FF, fields: [{ name: 'Playing', value: 'Co-op game', inline: true }, { name: 'Starting', value: '<t:' + now + ':R>', inline: true }] }], components: row(link('Watch live', 'https://example.com/live')) } }
  ];
  var TAGS = ['All'].concat(Array.from(new Set(LIB.map(function (t) { return t.tag; }))));
  var tag = 'All', q = '';

  root.appendChild(ui.pageHead({ icon: 'layout', title: 'Templates', desc: 'Start from a proven layout. Open any template in the Embed Builder to make it yours.' }));
  root.appendChild(ui.callout('info', el('strong', null, 'Before posting: '), 'swap the placeholder channel mentions (<#…>), links and times for your own. Templates marked “Needs a bot” use buttons that only a bot can respond to.'));

  var search = ui.field({ type: 'search', placeholder: 'Search templates…', onInput: function (v) { q = v.toLowerCase().trim(); paint(); } }); search.input.setAttribute('aria-label', 'Search templates');
  var chips = ui.chips({ label: 'Category', sm: true, value: 'All', options: TAGS, onChange: function (v) { tag = v; paint(); } });
  root.appendChild(el('div', { class: 'section', style: { marginTop: '22px' } }, el('div', { class: 'filter-bar' }, search.el), chips.el));
  var grid = el('div', { class: 'grid g-auto', style: { marginTop: '18px', gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 380px), 1fr))' } });
  root.appendChild(grid);

  function card(t) {
    var json = JSON.stringify(t.payload, null, 2);
    var prev = el('div', { class: 'tpl-prev' }, CH.preview.message(Object.assign({ username: 'Nebula Bot' }, t.payload), { compact: true }));
    var use = ui.btn('Use in builder', { icon: 'embed', sm: true, kind: 'primary', onclick: function () { CH.handoff.set('embed', Object.assign({ username: 'Nebula Bot' }, t.payload)); location.hash = '#/embeds'; } });
    var cp = ui.btn('Copy JSON', { icon: 'copy', sm: true, onclick: function () { CH.copy(json); } });
    var sv = ui.btn('Save', { icon: 'bookmark', sm: true, kind: 'ghost', onclick: function () { var r = CH.Saved.add({ type: 'template', title: t.name, body: json, data: { payload: t.payload } }); CH.toast(r.dupe ? 'Already saved' : 'Saved to your library'); } });
    return el('article', { class: 'card card-pad item-card' },
      el('div', { class: 'row-between' }, el('h3', null, t.name), el('div', { class: 'row', style: { gap: '6px' } }, t.bot ? el('span', { class: 'badge warn' }, 'Needs a bot') : null, el('span', { class: 'tag' }, t.tag))),
      el('p', null, t.desc), prev, el('div', { class: 'foot' }, use, cp, sv));
  }
  function paint() {
    CH.clear(grid);
    var list = LIB.filter(function (t) { return (tag === 'All' || t.tag === tag) && (!q || (t.name + ' ' + t.desc + ' ' + t.tag).toLowerCase().indexOf(q) >= 0); });
    list.forEach(function (t) { grid.appendChild(card(t)); });
    if (!list.length) grid.appendChild(el('div', { style: { gridColumn: '1/-1' } }, ui.empty('search', 'No templates match', 'Try a different word or category.')));
  }
  paint();
});
