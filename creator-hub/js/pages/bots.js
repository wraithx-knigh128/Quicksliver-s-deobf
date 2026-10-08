/* Bot Directory — well-known bots plus the built-in Discord features that replace many of them.
   Descriptions are intentionally general: features and pricing change, so each card points to the source. */
CH.page('bots', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;

  var CATS = ['Moderation', 'Security', 'Utility', 'Leveling', 'Tickets', 'Logging', 'Giveaways', 'Events', 'Analytics', 'Fun', 'Creative'];
  var BOTS = [
    { n: 'Carl-bot', c: ['Moderation', 'Utility', 'Logging'], d: 'A popular all-rounder known for reaction roles and flexible automod.', f: ['Reaction and button roles', 'Auto-moderation filters', 'Logging of edits, deletes and joins', 'Custom commands and tags'], p: 'Free, with optional premium', s: 'https://carl.gg', k: '#5865F2', best: 'Role menus + moderation in one bot' },
    { n: 'Dyno', c: ['Moderation', 'Utility'], d: 'Moderation and server management from a web dashboard.', f: ['Moderation commands and automod', 'Auto-roles', 'Custom commands', 'Announcements'], p: 'Free, with optional premium', s: 'https://dyno.gg', k: '#3b82f6', best: 'Dashboard-driven server management' },
    { n: 'MEE6', c: ['Leveling', 'Moderation', 'Utility'], d: 'Leveling with role rewards, plus welcome messages and moderation tools.', f: ['XP, levels and role rewards', 'Welcome and goodbye messages', 'Moderation tools', 'Custom commands'], p: 'Free core, many features premium', s: 'https://mee6.xyz', k: '#2563eb', best: 'Communities that want XP and rewards' },
    { n: 'Arcane', c: ['Leveling'], d: 'A focused leveling bot with role rewards and leaderboards.', f: ['XP and leaderboards', 'Role rewards', 'Rank cards'], p: 'Free, with optional premium', s: 'https://arcane.bot', k: '#8b5cf6', best: 'Leveling without the extras' },
    { n: 'Tatsu', c: ['Leveling', 'Fun'], d: 'Levels, reputation and profile cards that members enjoy collecting.', f: ['XP and reputation', 'Profile cards', 'Server and global ranks'], p: 'Free, with optional premium', s: 'https://tatsu.gg', k: '#ec4899', best: 'Social, collectible profiles' },
    { n: 'Ticket Tool', c: ['Tickets'], d: 'Support tickets opened from a panel, with categories and transcripts.', f: ['Ticket panels with buttons', 'Categories and staff roles', 'Transcripts of closed tickets'], p: 'Free, with optional premium', s: 'https://tickettool.xyz', k: '#10b981', best: 'Support and application servers' },
    { n: 'Wick', c: ['Security', 'Moderation'], d: 'Security-focused protection against raids and malicious accounts.', f: ['Anti-raid controls', 'Anti-nuke protection', 'Auto-moderation'], p: 'Free and premium tiers', s: 'https://wickbot.com', k: '#ef4444', best: 'Large or frequently targeted servers' },
    { n: 'YAGPDB', c: ['Utility', 'Moderation'], d: 'Yet Another General Purpose Discord Bot — powerful custom commands with a templating language.', f: ['Custom commands with templates', 'Automod rules', 'Reputation and feeds', 'Role commands'], p: 'Free, with optional premium', s: 'https://yagpdb.xyz', k: '#f59e0b', best: 'Tinkerers who want programmable behavior' },
    { n: 'Statbot', c: ['Analytics'], d: 'Server analytics: message volume, activity and growth over time.', f: ['Message and voice activity stats', 'Member growth', 'Leaderboards'], p: 'Free, with optional premium', s: 'https://statbot.net', k: '#06b6d4', best: 'Understanding when and where your community is active' },
    { n: 'GiveawayBot', c: ['Giveaways'], d: 'Straightforward, reliable giveaways started with slash commands.', f: ['Timed giveaways', 'Winner re-rolls', 'Requirements such as a role'], p: 'Free, with optional premium', s: 'https://giveawaybot.party', k: '#f43f5e', best: 'Simple prize draws' },
    { n: 'Apollo', c: ['Events'], d: 'Event scheduling with RSVP and times that adapt to each member’s timezone.', f: ['Event posts with RSVP buttons', 'Timezone-aware times', 'Recurring events'], p: 'Check the bot’s page for current plans', s: '', k: '#a855f7', best: 'Game nights and meetups' },
    { n: 'Sesh', c: ['Events'], d: 'Calendar and scheduling bot for community sessions.', f: ['Create and RSVP to sessions', 'Recurring schedules', 'Timezone handling'], p: 'Check the bot’s page for current plans', s: '', k: '#14b8a6', best: 'Regular sessions and raids' },
    { n: 'Dank Memer', c: ['Fun'], d: 'Economy and meme minigames that keep casual chat lively.', f: ['Economy and minigames', 'Meme commands', 'Collectible items'], p: 'Free, with optional premium', s: 'https://dankmemer.lol', k: '#22c55e', best: 'Casual, meme-friendly communities' },
    { n: 'Mudae', c: ['Fun'], d: 'An anime-character claiming game that anime servers love.', f: ['Collectible character claims', 'Wishlists and trading', 'Daily rolls'], p: 'Free, with optional premium', s: '', k: '#e879f9', best: 'Anime communities' },
    { n: 'Midjourney', c: ['Creative'], d: 'AI image generation delivered through Discord. Requires its own account and follows its own terms.', f: ['Prompt-based image generation', 'Works in DMs or server channels'], p: 'Paid subscription', s: 'https://www.midjourney.com', k: '#64748b', best: 'Art and concept servers (check its usage rules)' }
  ];
  var NATIVE = [
    { t: 'AutoMod', d: 'Block keywords, spam and mention floods natively, with alerts to a staff channel.', w: 'Server Settings → Safety Setup / AutoMod', r: 'basic filter bots' },
    { t: 'Onboarding', d: 'Ask new members a few questions and assign roles and channels from their answers.', w: 'Server Settings → Onboarding (Community servers)', r: 'simple reaction-role bots' },
    { t: 'Scheduled Events', d: 'Create events with RSVPs, reminders and a place in the server’s event list.', w: 'Server → Create Event', r: 'basic calendar bots' },
    { t: 'Native polls', d: 'Post polls directly from the message box.', w: 'Message box → + → Create Poll', r: 'poll bots' },
    { t: 'Forum channels', d: 'Structured help posts with tags — one thread per question.', w: 'Create Channel → Forum (Community servers)', r: 'lightweight help-desk bots' },
    { t: 'Timeout', d: 'Silence a member for a set time without managing a Muted role.', w: 'Member profile → Timeout', r: '“Muted” role setups' },
    { t: 'Webhooks', d: 'Let other services post into a channel. For GitHub, add /github to the webhook URL.', w: 'Channel settings → Integrations → Webhooks', r: 'notification bots' },
    { t: 'Announcement channels', d: 'Let other servers follow a channel and get your posts automatically.', w: 'Channel type → Announcement', r: 'cross-posting bots' }
  ];
  var CHECK = [
    'Add bots only from their official website or an app listing you trust, and check the app’s profile in Discord for a verification badge.',
    'Read the permissions screen. Avoid giving Administrator; grant only what the bot needs, and restrict it to the channels it should see.',
    'Check the privacy policy. Bots that read message content can store it — know what’s kept and for how long.',
    'Keep each bot’s role below your staff roles but above any role it needs to assign.',
    'Never share a bot token, and be wary of “verification” bots or links that ask you to log in or paste codes.',
    'Audit under Server Settings → Integrations occasionally and remove bots you no longer use.',
    'Music bots built on streaming sites have repeatedly been shut down (Groovy and Rythm in 2021). Don’t build your community around one.'
  ];

  var cat = 'All', q = '';
  root.appendChild(ui.pageHead({ icon: 'bot', title: 'Bot Directory', desc: 'A starter list of well-known bots, and the built-in Discord features that can replace many of them.' }));
  root.appendChild(ui.callout('info', el('strong', null, 'Not an endorsement. '), 'Creator Hub isn’t affiliated with these bots. Features, pricing and availability change often — confirm on each bot’s own page before inviting it.'));

  var search = ui.field({ type: 'search', placeholder: 'Search bots…', onInput: function (v) { q = v.toLowerCase().trim(); paint(); } });
  search.input.setAttribute('aria-label', 'Search bots');
  var chips = ui.chips({ label: 'Category', sm: true, value: 'All', options: ['All'].concat(CATS), onChange: function (v) { cat = v; paint(); } });
  root.appendChild(el('div', { class: 'section', style: { marginTop: '22px' } }, el('div', { class: 'filter-bar' }, search.el), chips.el));

  var grid = el('div', { class: 'grid g-auto', style: { marginTop: '18px' } });
  var count = el('p', { class: 'hint', style: { marginTop: '12px' }, 'aria-live': 'polite' });
  root.appendChild(grid); root.appendChild(count);

  function card(b) {
    var logo = el('div', { class: 'logo-tile', style: { background: 'linear-gradient(135deg,' + b.k + ',' + b.k + '99)' }, 'aria-hidden': 'true' }, b.n.charAt(0));
    var save = el('button', { type: 'button', class: 'btn btn-sm btn-ghost' }, icon('bookmark'), el('span', null, 'Save'));
    save.addEventListener('click', function () { var r = CH.Saved.add({ type: 'bot', title: b.n, body: b.n + ' — ' + b.d + (b.s ? '\n' + b.s : '') }); CH.toast(r.dupe ? 'Already saved' : 'Saved ' + b.n); });
    return el('article', { class: 'card card-pad item-card tilt spot' },
      el('div', { class: 'row' }, logo, el('div', null, el('h3', null, b.n), el('div', { class: 'meta-line' }, b.p))),
      el('p', null, b.d),
      el('ul', null, b.f.map(function (x) { return el('li', null, x); })),
      el('div', { class: 'tags' }, b.c.map(function (c) { return el('span', { class: 'tag' }, c); })),
      el('div', { class: 'meta-line' }, 'Best for: ' + b.best),
      el('div', { class: 'foot' }, b.s ? el('a', { class: 'btn btn-sm', href: b.s, target: '_blank', rel: 'noopener noreferrer' }, icon('external'), el('span', null, 'Website')) : el('span', { class: 'meta-line' }, 'Search its name in Discord’s App Directory'), save));
  }
  function paint() {
    CH.clear(grid);
    var list = BOTS.filter(function (b) { return (cat === 'All' || b.c.indexOf(cat) >= 0) && (!q || (b.n + ' ' + b.d + ' ' + b.c.join(' ') + ' ' + b.f.join(' ')).toLowerCase().indexOf(q) >= 0); });
    list.forEach(function (b) { grid.appendChild(card(b)); });
    if (!list.length) grid.appendChild(el('div', { style: { gridColumn: '1/-1' } }, ui.empty('search', 'No bots match', 'Try another category, or check the built-in features below.')));
    count.textContent = list.length + ' of ' + BOTS.length + ' bots';
  }
  paint();

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('div', null, el('h2', null, 'Before you add a bot, check Discord’s built-ins'), el('p', null, 'Fewer bots means fewer permissions to trust and fewer things to break.'))),
    el('div', { class: 'grid g-auto' }, NATIVE.map(function (n) {
      return el('div', { class: 'card card-pad item-card' }, el('div', { class: 'row' }, el('span', { class: 'badge ok' }, 'Built in'), el('h3', null, n.t)), el('p', null, n.d), el('div', { class: 'meta-line' }, 'Where: ' + n.w), el('div', { class: 'meta-line' }, 'Can replace: ' + n.r));
    }))));

  root.appendChild(el('section', { class: 'section' },
    el('div', { class: 'section-head' }, el('h2', null, 'Bot safety checklist')),
    ui.acc('Seven checks before inviting any bot', el('ol', null, CHECK.map(function (c) { return el('li', null, c); })), { open: true })));
});
