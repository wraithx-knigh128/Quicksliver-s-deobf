/* About */
CH.page('about', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var mac = /Mac|iPhone|iPad/.test(navigator.platform || '');

  root.appendChild(ui.pageHead({ icon: 'info', title: 'About CordX', desc: 'A small, fast toolkit for people who run Discord communities. Built to be useful, private and honest.' }));

  function pr(t, d) { return el('div', { class: 'card card-pad reveal' }, el('h3', { class: 'card-title' }, t), el('p', { class: 'card-sub', style: { marginTop: '6px', fontSize: '14px', lineHeight: '1.6' } }, d)); }
  root.appendChild(el('div', { class: 'grid g3' },
    pr('Local-first', 'There’s no backend. Generators run in your browser, and your saved items live in this browser’s storage. You can export them any time.'),
    pr('Accurate', 'Limits and behaviors are checked live in the tools and explained on the page. When Discord’s behavior is uncertain or changes, we say so instead of guessing.'),
    pr('Fast', 'Each tool loads on demand. Effects scale to your device, respect reduced-motion, and switch off automatically if your device struggles.')));

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('h2', null, 'How the generators work')),
    el('div', { class: 'prose' },
      el('p', null, 'Bios, usernames, rules, announcements, descriptions, roles and channel layouts are produced by composing small pieces — word banks, sentence frames, naming patterns and rule libraries — rather than by calling an AI service. Randomness comes from your browser’s cryptographic random source, and recently used lines are avoided so results don’t feel repetitive.'),
      el('p', null, 'Because nothing is sent anywhere, your names, keywords and server details never leave your device. The trade-off: output is varied but not “understanding” — always read and edit what you copy.'))));

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('h2', null, 'Discord: what’s supported and what isn’t')),
    el('div', { class: 'table-wrap' }, el('table', { class: 'tbl' },
      el('thead', null, el('tr', null, el('th', null, 'Topic'), el('th', null, 'What to know'))),
      el('tbody', null, [
        ['Who can send embeds', 'Only bots and webhooks. Regular accounts can’t, and automating one (“self-botting”) breaks Discord’s Terms of Service.'],
        ['Embed limits', '10 embeds per message; title 256, description 4,096, 25 fields, field value 1,024, footer 2,048, and 6,000 characters combined.'],
        ['Buttons', 'Appear under the message. Link buttons need no code; other styles need an application to handle the click. Plain channel webhooks have limited component support.'],
        ['Mentions', 'Mentions in embeds display but don’t notify. Pings only work in the message content.'],
        ['Bio length', 'The “About Me” field allows 190 characters.'],
        ['Usernames', 'Handles are 2–32 characters: lowercase letters, numbers, underscores and periods. Display names are more flexible. We can’t check if a handle is available.'],
        ['Roles & channels', 'Up to 250 roles and 500 channels per server, 50 channels per category. Role names go up to 100 characters.'],
        ['Server description', 'The Community server description is short (about 120 characters at the time of writing) — check Server Settings for the current limit.']
      ].map(function (r) { return el('tr', null, el('td', null, r[0]), el('td', null, r[1])); })))),
    el('p', { class: 'hint', style: { marginTop: '10px' } }, 'Discord changes its product often. Treat this page as a guide and verify critical details in Discord’s own documentation.')));

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('h2', null, 'Privacy')),
    el('div', { class: 'prose' },
      el('p', null, 'No accounts, analytics or cookies. CordX stores your settings, drafts and saved items in this browser’s localStorage. The network is used for: the web font stylesheet, images you paste into the embed preview (loaded directly from their hosts), custom emoji in the preview (loaded from Discord’s CDN), and a webhook post only when you press “Send message”.'),
      el('p', null, 'Webhook URLs typed into the builder are held in memory only and cleared when you leave the page.'))));

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('h2', null, 'Keyboard shortcuts')),
    el('div', { class: 'card card-pad' }, el('div', { class: 'stack-sm' },
      [[mac ? '⌘ K' : 'Ctrl K', 'Open search'], ['/', 'Open search (when not typing)'], ['↑ ↓ Enter', 'Navigate and open search results'], ['Esc', 'Close search or the mobile menu']].map(function (s) {
        return el('div', { class: 'row-between' }, el('span', null, s[1]), el('kbd', { class: 'kbd' }, s[0]));
      })))));

  root.appendChild(el('p', { class: 'hint', style: { marginTop: '34px' } }, 'CordX is an independent project and is not affiliated with, sponsored or endorsed by Discord Inc. “Discord” is a trademark of Discord Inc. Bot names belong to their owners.'));
});
