/* Pricing / Pro — honest about what exists today. No payments are processed anywhere on this site. */
CH.page('pro', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  function li(text, soon) { return el('li', { class: soon ? 'soon' : '' }, icon(soon ? 'sparkle' : 'check'), el('span', null, text)); }

  root.appendChild(ui.pageHead({ icon: 'crown', title: 'Pricing & Pro', badge: 'Pro is planned', badgeKind: 'warn', desc: 'Everything on Creator Hub is free today. Pro is an idea for people who want sync and team features — it isn’t on sale yet.' }));
  root.appendChild(ui.callout('info', el('strong', null, 'No payments here. '), 'This site has no checkout, no accounts and no way to charge you. If Pro launches, it will be announced clearly and the free tools will stay free.'));
  root.appendChild(el('div', { style: { height: '20px' } }));

  var interested = CH.Store.get('pro:interest', false);
  var btn = ui.btn(interested ? 'Interest noted on this device' : 'I’d like Pro', { icon: interested ? 'check' : 'bell', kind: interested ? '' : 'primary', onclick: function () {
    var on = !CH.Store.get('pro:interest', false); CH.Store.set('pro:interest', on);
    CH.clear(btn); btn.appendChild(icon(on ? 'check' : 'bell')); btn.appendChild(el('span', null, on ? 'Interest noted on this device' : 'I’d like Pro')); btn.classList.toggle('btn-primary', !on);
    CH.toast(on ? 'Noted — stored only in this browser' : 'Removed');
  } });

  root.appendChild(el('div', { class: 'plans' },
    el('article', { class: 'card plan reveal' },
      el('div', null, el('h3', null, 'Free'), el('p', { class: 'card-sub' }, 'Everything you see here')),
      el('div', { class: 'price' }, '$0', el('small', null, ' forever')),
      el('ul', null, li('Embed builder with webhook, discord.js, discord.py and cURL export'), li('Bio, username, rules, announcement, description, role and channel generators'), li('Templates, bot directory and server ideas'), li('Saved Creations stored on your device, with export and import'), li('No sign-up, no ads, no tracking')),
      ui.btn('Start creating', { href: '#/tools', kind: 'primary', icon: 'arrowRight' })),
    el('article', { class: 'card plan featured reveal' },
      el('div', { class: 'row-between' }, el('div', null, el('h3', null, 'Pro'), el('p', { class: 'card-sub' }, 'For teams and power users')), el('span', { class: 'badge warn' }, 'Planned')),
      el('div', { class: 'price' }, 'TBA', el('small', null, ' price not set')),
      el('ul', null, li('Optional cloud sync of your library across devices', true), li('Shared team libraries for templates and rule sets', true), li('Saved webhook profiles for one-click posting', true), li('Version history for embeds and announcements', true), li('Everything in Free, always', false)),
      btn)));

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('h2', null, 'Questions')),
    ui.acc('Is anything paid today?', el('p', null, 'No. Every tool is free and runs in your browser. There’s no payment form on this site.'), { open: true }),
    ui.acc('What does “interest noted” do?', el('p', null, 'It saves a flag in your browser’s local storage so the button remembers your choice. Nothing is sent to a server — there’s no list to join yet.')),
    ui.acc('Will free tools become paid?', el('p', null, 'That’s not the plan. Pro is meant to add things that need servers (sync, sharing) rather than lock the generators.')),
    ui.acc('How is my data handled?', el('p', null, 'Saved items, settings and drafts live in this browser’s localStorage. Clearing site data removes them. The only network requests are the font stylesheet, images you choose to preview, and a webhook post if you explicitly send one.')),
    ui.acc('Is this affiliated with Discord?', el('p', null, 'No. Creator Hub is an independent project. Discord is a trademark of Discord Inc.'))));
});
