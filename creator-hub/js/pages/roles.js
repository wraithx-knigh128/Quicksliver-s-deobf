/* Role Generator — themed role hierarchy with colours and least-privilege permission suggestions. */
CH.page('roles', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, chance = CH.chance;
  var W = function (s) { return s.split('|'); };

  var THEMES = {
    fantasy: { label: 'Fantasy', staff: W('Archmage|High Warden|Sentinel|Squire|Initiate'), levels: W('Wanderer|Adventurer|Knight|Champion|Legend'), cosmetic: W('Ember|Moonlit|Verdant|Azure|Crimson|Gilded'), special: W('Dragonblood|Royal Patron|Guild Ally|Bard|Honored Guest'), pings: W('Quest Board|Tavern Nights|Scroll Updates|Treasure Hunters|Council Votes'), bots: W('Familiar|Automaton'), util: W('Silenced|Sworn In|Newcomer'), palette: W('#c9a227|#8e44ad|#2e8b57|#b03a2e|#2874a6|#d4ac0d') },
    scifi: { label: 'Sci-fi', staff: W('Fleet Admiral|Commander|Officer|Ensign|Cadet'), levels: W('Recruit|Pilot|Navigator|Captain|Vanguard'), cosmetic: W('Nebula|Pulsar|Aurora|Solar|Void|Ion'), special: W('Quantum Booster|Patron|Allied Fleet|Broadcaster|Envoy'), pings: W('Mission Alerts|Launch Events|Log Updates|Supply Drops|Council Polls'), bots: W('Droid|Mainframe'), util: W('Comms Cut|Cleared|Boarding'), palette: W('#35d4ff|#7c6cff|#2ee6a6|#ff7a59|#c084fc|#e2e8f0') },
    cozy: { label: 'Cozy', staff: W('Head Gardener|Caretaker|Host|Helper|Trainee'), levels: W('Newcomer|Regular|Familiar Face|Cozy Resident|Heart of the Place'), cosmetic: W('Peach|Lavender|Sage|Honey|Cloud|Rosewater'), special: W('Sunbeam|Friend of the House|Neighbor|Storyteller|Guest of Honor'), pings: W('Movie Night|Chat Time|News|Giveaways|Votes'), bots: W('Helper Bot|Little Robot'), util: W('Quiet Corner|Settled In|Just Arrived'), palette: W('#f4a6a6|#c4b5fd|#a7c4a0|#f2c14e|#b8d8ea|#f7cac9') },
    corporate: { label: 'Corporate', staff: W('Director|Operations Lead|Moderator|Support Agent|Intern'), levels: W('Member|Contributor|Associate|Senior|Principal'), cosmetic: W('Slate|Navy|Teal|Graphite|Indigo|Copper'), special: W('Sponsor|Premium Member|Partner|Speaker|Guest'), pings: W('Announcements|Events|Updates|Jobs|Surveys'), bots: W('Integration|Automation'), util: W('Restricted|Verified|Guest'), palette: W('#4f6d8f|#1f3a5f|#2a9d8f|#6b7280|#4338ca|#b87333') },
    military: { label: 'Military', staff: W('Commander|Colonel|Sergeant|Corporal|Private'), levels: W('Recruit|Soldier|Specialist|Veteran|Elite'), cosmetic: W('Olive|Desert|Steel|Midnight|Crimson|Forest'), special: W('Quartermaster|Patron|Allied Squad|Broadcaster|Guest'), pings: W('Briefings|Operations|Intel|Supply Drops|Polls'), bots: W('Drone|Command Bot'), util: W('Detained|Cleared|Boot Camp'), palette: W('#6b7a3a|#c2a878|#7c8794|#334155|#a52a2a|#2f5d3a') },
    cyber: { label: 'Cyber', staff: W('Sysadmin|Net Warden|Mod.exe|Helper.sys|Trainee.bin'), levels: W('Script Kiddie|Runner|Operator|Netrunner|Architect'), cosmetic: W('Neon Pink|Cyan Line|Toxic Green|Chrome|Violet Grid|Amber CRT'), special: W('Overclock|Patron|Allied Node|Streamer|VIP'), pings: W('Alerts|Events|Patch Notes|Drops|Votes'), bots: W('Daemon|AI Core'), util: W('Timeout|Authenticated|Guest'), palette: W('#ff2a8a|#22d3ee|#84cc16|#9ca3af|#8b5cf6|#f59e0b') },
    anime: { label: 'Anime', staff: W('Guild Master|Ace Captain|Vice Captain|Senpai|Kouhai'), levels: W('Rookie|Adventurer|Ace|Prodigy|Legend'), cosmetic: W('Sakura|Sora|Matcha|Sunset|Starlight|Midnight'), special: W('Lucky Star|Patron|Allied Guild|Artist|Honored Guest'), pings: W('Episode Night|Events|News|Giveaways|Polls'), bots: W('Familiar|Mascot'), util: W('Detention|Enrolled|Transfer Student'), palette: W('#ff9ebb|#6ec1e4|#9ccc65|#ff8a65|#b39ddb|#8195c9') },
    minimal: { label: 'Minimal', staff: W('Owner|Admin|Moderator|Helper|Trial Mod'), levels: W('Member|Active|Regular|Veteran|Elite'), cosmetic: W('Red|Orange|Yellow|Green|Blue|Purple'), special: W('Booster|Supporter|Partner|Creator|VIP'), pings: W('Announcements|Events|Updates|Giveaways|Polls'), bots: W('Bot|Integration'), util: W('Muted|Verified|New'), palette: W('#ef4444|#f97316|#eab308|#22c55e|#3b82f6|#a855f7') }
  };
  // extra roles that make sense for a given server type (always considered "special")
  var TYPE_ROLES = {
    gaming: [{ n: 'LFG', p: [], ping: true }, { n: 'Tournament Player', p: ['Create Invite'] }, { n: 'Streamer', p: ['Embed Links', 'Attach Files'] }],
    community: [{ n: 'Event Host', p: ['Manage Events', 'Create Public Threads'] }, { n: 'Greeter', p: ['Manage Nicknames'] }],
    friends: [{ n: 'Inner Circle', p: ['Use External Emojis'] }, { n: 'Plus One', p: [] }],
    anime: [{ n: 'Artist', p: ['Embed Links', 'Attach Files'] }, { n: 'Watch Party', p: [], ping: true }, { n: 'Translator', p: ['Create Public Threads'] }],
    creator: [{ n: 'Subscriber', p: ['Use External Emojis'] }, { n: 'Collaborator', p: ['Embed Links', 'Attach Files'] }, { n: 'Live Alerts', p: [], ping: true }],
    education: [{ n: 'Teacher', p: ['Manage Messages', 'Manage Threads', 'Mute Members'] }, { n: 'Student', p: [] }, { n: 'Study Group', p: [], ping: true }],
    support: [{ n: 'Verified Helper', p: ['Manage Messages', 'Manage Threads'] }, { n: 'Customer', p: [] }],
    professional: [{ n: 'Client', p: [] }, { n: 'Freelancer', p: ['Embed Links', 'Attach Files'] }, { n: 'Recruiter', p: ['Create Public Threads'] }],
    marketplace: [{ n: 'Verified Seller', p: ['Embed Links', 'Attach Files'] }, { n: 'Verified Buyer', p: [] }, { n: 'Middleman', p: ['Manage Messages', 'Manage Threads'] }],
    other: []
  };
  var TYPES = [['gaming', 'Gaming'], ['community', 'Community'], ['friends', 'Friends'], ['anime', 'Anime'], ['creator', 'Creator'], ['education', 'Education'], ['support', 'Support'], ['professional', 'Professional'], ['marketplace', 'Marketplace'], ['other', 'Other']];
  var DANGER = ['Administrator', 'Manage Server', 'Manage Roles', 'Manage Channels', 'Ban Members', 'Kick Members', 'Manage Webhooks', 'Mention Everyone'];
  var FLAG = { 'Administrator': 'Administrator', 'Manage Server': 'ManageGuild', 'Manage Roles': 'ManageRoles', 'Manage Channels': 'ManageChannels', 'Kick Members': 'KickMembers', 'Ban Members': 'BanMembers', 'Timeout Members': 'ModerateMembers', 'Manage Messages': 'ManageMessages', 'Manage Threads': 'ManageThreads', 'Manage Nicknames': 'ManageNicknames', 'Mute Members': 'MuteMembers', 'Move Members': 'MoveMembers', 'View Audit Log': 'ViewAuditLog', 'Mention Everyone': 'MentionEveryone', 'Embed Links': 'EmbedLinks', 'Attach Files': 'AttachFiles', 'Use External Emojis': 'UseExternalEmojis', 'Use External Stickers': 'UseExternalStickers', 'Create Public Threads': 'CreatePublicThreads', 'Change Nickname': 'ChangeNickname', 'Create Invite': 'CreateInstantInvite', 'Manage Webhooks': 'ManageWebhooks', 'Manage Events': 'ManageEvents', 'Add Reactions': 'AddReactions' };
  var STAFF_PERMS = [
    { p: ['Administrator'], note: 'Owner-level. Give to the owner or a tiny, fully trusted group — it bypasses every channel permission.' },
    { p: ['Manage Server', 'Manage Roles', 'Manage Channels', 'Kick Members', 'Ban Members', 'Timeout Members', 'Manage Messages', 'View Audit Log', 'Mention Everyone'], note: 'Run the server day to day without the all-powerful Administrator permission.' },
    { p: ['Kick Members', 'Ban Members', 'Timeout Members', 'Manage Messages', 'Manage Threads', 'Manage Nicknames', 'Mute Members', 'Move Members', 'View Audit Log'], note: 'Enforce the rules. Review what each moderator really needs.' },
    { p: ['Timeout Members', 'Manage Messages', 'Manage Threads', 'Mute Members'], note: 'First responders: calm things down and escalate to moderators.' },
    { p: ['Timeout Members', 'Manage Messages'], note: 'A probation role — limited tools while trust is built.' }
  ];
  var LEVEL_PERMS = [[], ['Embed Links', 'Attach Files'], ['Use External Emojis', 'Create Public Threads'], ['Use External Stickers', 'Change Nickname'], ['Create Invite']];
  var EMOJI = { staff: '🛡️', bots: '🤖', special: '💎', levels: '⭐', util: '✅', cosmetic: '🎨', pings: '🔔' };
  var SYMS = ['✦', '・', '〢', '»', '◈', '❖'];
  var CATS = [['staff', 'Staff'], ['bots', 'Bots'], ['special', 'Special & supporters'], ['levels', 'Member levels'], ['util', 'Verification & utility'], ['cosmetic', 'Colour roles'], ['pings', 'Ping roles']];

  function hsl(h, s, l) { s /= 100; l /= 100; var a = s * Math.min(l, 1 - l), f = function (n) { var k = (n + h / 30) % 12, c = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1); return Math.round(255 * c).toString(16).padStart(2, '0'); }; return '#' + f(0) + f(8) + f(4); }

  function build(f) {
    var th = THEMES[f.theme], N = f.count, cats = f.cats.length ? f.cats : ['staff', 'levels'], roles = [];
    var share = { staff: .22, bots: .06, special: .14, levels: .22, util: .08, cosmetic: .16, pings: .12 }, cap = { staff: 5, bots: 2, special: 5 + (TYPE_ROLES[f.type] || []).length, levels: 5, util: 3, cosmetic: 6, pings: 5 + 1 };
    var alloc = {}, total = 0;
    cats.forEach(function (c) { alloc[c] = Math.min(cap[c], Math.max(1, Math.round(N * share[c] / cats.reduce(function (a, k) { return a + share[k]; }, 0) * 1))); total += alloc[c]; });
    var order = ['levels', 'cosmetic', 'pings', 'special', 'staff', 'util', 'bots'], g = 0;
    while (total < N && g++ < 80) { var c = order.filter(function (k) { return alloc[k] != null && alloc[k] < cap[k]; })[0]; if (!c) break; alloc[c]++; total++; order.push(order.shift()); }
    g = 0; var shrink = ['cosmetic', 'pings', 'levels', 'util', 'special', 'bots', 'staff'];
    while (total > N && g++ < 80) { var s = shrink.filter(function (k) { return alloc[k] > 1; })[0]; if (!s) break; alloc[s]--; total--; shrink.push(shrink.shift()); }

    var pal = th.palette, n = pal.length, rainbowN = Math.max(1, N);
    function colour(cat, i) {
      if (f.colors === 'rainbow') return hsl(Math.round((roles.length * 360 / rainbowN) % 360), 70, 62);
      if (f.colors === 'mono') return hsl(262, 55, 45 + Math.min(40, i * 9));
      if (cat === 'staff') return [pal[0], pal[1], pal[2], pal[3 % n], pal[4 % n]][i % 5];
      if (cat === 'levels') return ['#99aab5', pal[2 % n], pal[4 % n], pal[1 % n], pal[0]][i % 5];
      if (cat === 'special') return pal[(5 + i) % n];
      if (cat === 'cosmetic') return pal[i % n];
      if (cat === 'bots') return '#5865F2';
      return null;
    }
    function add(cat, name, o) { roles.push(Object.assign({ cat: cat, name: name, color: null, hoist: false, mentionable: false, perms: [], note: '' }, o)); }

    // top → bottom hierarchy
    if (alloc.staff) {
      var staffIdx = alloc.staff >= 5 ? [0, 1, 2, 3, 4] : alloc.staff === 4 ? [0, 1, 2, 3] : alloc.staff === 3 ? [1, 2, 3] : alloc.staff === 2 ? [1, 2] : [2];
      staffIdx.forEach(function (idx, i) { add('staff', th.staff[idx], { color: colour('staff', idx), hoist: true, perms: STAFF_PERMS[idx].p, note: STAFF_PERMS[idx].note }); });
    }
    if (alloc.bots) for (var b = 0; b < alloc.bots; b++) add('bots', th.bots[b], { color: colour('bots', b), hoist: b === 0, perms: [], note: b === 0 ? 'Give each bot only the permissions it needs. Keep this role above any role the bot has to assign.' : 'Optional second bot role, e.g. for a music or utility bot.' });
    if (alloc.special) {
      var tr = (TYPE_ROLES[f.type] || []).filter(function (x) { return !x.ping; }), sp = [];
      tr.forEach(function (x) { sp.push({ n: x.n, p: x.p, note: 'Fits a ' + f.type + ' server.' }); });
      th.special.forEach(function (x, i) { sp.push({ n: x, p: ['Use External Emojis', 'Embed Links', 'Attach Files'].slice(0, 1 + (i % 3)), note: i === 0 ? 'Often tied to Server Boosts — Discord’s native Booster role is assigned automatically.' : 'Perks for people who support the server.' }); });
      sp.slice(0, alloc.special).forEach(function (x, i) { add('special', x.n, { color: colour('special', i), hoist: true, perms: x.p, note: x.note }); });
    }
    if (alloc.levels) { var lv = th.levels.slice(0, alloc.levels).reverse(); lv.forEach(function (nm, i) { var li = alloc.levels - 1 - i; add('levels', nm, { color: colour('levels', li), hoist: i < 2, perms: LEVEL_PERMS[Math.min(li, 4)], note: li === 0 ? 'Entry level — inherits @everyone. Pair with a leveling bot.' : 'Unlocked by activity or time in the server.' }); }); }
    if (alloc.util) { var ut = [th.util[1], th.util[2], th.util[0]].slice(0, alloc.util); ut.forEach(function (nm, i) { var isMute = nm === th.util[0]; add('util', nm, { perms: [], note: isMute ? 'Discord’s built-in Timeout usually replaces a Muted role — only create this if you need channel-level mutes.' : i === 0 ? 'Granted after verification or onboarding; use it to unlock channels.' : 'Applied to new joiners until they verify.' }); }); }
    if (alloc.cosmetic) th.cosmetic.slice(0, alloc.cosmetic).forEach(function (nm, i) { add('cosmetic', nm, { color: colour('cosmetic', i), perms: [], note: 'Cosmetic only — members pick a name colour. No permissions needed.' }); });
    if (alloc.pings) {
      var pg = th.pings.slice(); (TYPE_ROLES[f.type] || []).filter(function (x) { return x.ping; }).forEach(function (x) { pg.unshift(x.n); });
      pg.slice(0, alloc.pings).forEach(function (nm) { add('pings', nm, { mentionable: true, perms: [], note: 'Opt-in notification role. Make it mentionable and let members self-assign.' }); });
    }
    var seen = {}; roles = roles.filter(function (r) { var k = r.name.toLowerCase(); if (seen[k]) return false; seen[k] = 1; return true; });
    // naming style
    roles.forEach(function (r, i) {
      var nm = r.name;
      if (f.style === 'emoji') nm = EMOJI[r.cat] + ' ' + nm;
      else if (f.style === 'upper') nm = nm.toUpperCase();
      else if (f.style === 'bracket') nm = '「' + nm + '」';
      r.display = nm.slice(0, 100);
    });
    if (f.style === 'symbol') { var sym = pick(SYMS); roles.forEach(function (r) { r.display = (sym === '・' || sym === '〢' ? sym : sym + ' ') + r.name; }); }
    return roles;
  }

  /* ---------------- exports ---------------- */
  function asText(roles) { return roles.map(function (r, i) { return (i + 1) + '. ' + r.display + (r.color ? '  (' + r.color + ')' : '') + (r.perms.length ? '\n   Permissions: ' + r.perms.join(', ') : ''); }).join('\n'); }
  function asJson(roles) { return JSON.stringify(roles.map(function (r) { return { name: r.display, color: r.color, hoist: r.hoist, mentionable: r.mentionable, permissions: r.perms }; }), null, 2); }
  function asCode(roles) {
    var out = ["const { PermissionFlagsBits } = require('discord.js');", '', '// Run once with a bot that has Manage Roles. Roles are created bottom → top so the', '// first one you create ends up lowest; drag them into order in Server Settings → Roles.', 'async function createRoles(guild) {'];
    roles.slice().reverse().forEach(function (r) {
      var flags = r.perms.map(function (p) { return FLAG[p] ? 'PermissionFlagsBits.' + FLAG[p] : null; }).filter(Boolean);
      out.push('  await guild.roles.create({ name: ' + JSON.stringify(r.display) + (r.color ? ', color: ' + JSON.stringify(r.color) : '') + ', hoist: ' + r.hoist + ', mentionable: ' + r.mentionable + (flags.length ? ', permissions: [' + flags.join(', ') + ']' : '') + ' });');
    });
    out.push('}'); return out.join('\n');
  }

  /* ---------------- UI ---------------- */
  var form = Object.assign({ type: 'community', theme: 'minimal', cats: ['staff', 'special', 'levels', 'cosmetic', 'pings'], count: 16, style: 'plain', colors: 'themed' }, CH.Store.get('form:roles', {}));
  function persist() { CH.Store.set('form:roles', form); }
  var roles = [], tab = 'list'; form.count = Math.min(form.count, 26);

  root.appendChild(ui.pageHead({ icon: 'tag', title: 'Role Generator', desc: 'A themed role hierarchy — names, colours and the least permissions each role needs.' }));

  var typeChips = ui.chips({ label: 'Server type', sm: true, value: form.type, options: TYPES.map(function (t) { return { value: t[0], label: t[1] }; }), onChange: function (v) { form.type = v; persist(); } });
  var themeChips = ui.chips({ label: 'Theme', sm: true, value: form.theme, options: Object.keys(THEMES).map(function (k) { return { value: k, label: THEMES[k].label }; }), onChange: function (v) { form.theme = v; persist(); } });
  var catChips = ui.chips({ label: 'Role groups', multi: true, sm: true, value: form.cats, options: CATS.map(function (c) { return { value: c[0], label: c[1] }; }), onChange: function (v) { form.cats = v; persist(); } });
  var countR = ui.range({ label: 'Number of roles', min: 6, max: 26, value: form.count, onInput: function (v) { form.count = v; persist(); } });
  var styleF = ui.field({ label: 'Name style', type: 'select', value: form.style, options: [{ value: 'plain', label: 'Plain' }, { value: 'emoji', label: 'Emoji prefix' }, { value: 'symbol', label: 'Symbol prefix (✦ Name)' }, { value: 'upper', label: 'UPPERCASE' }, { value: 'bracket', label: '「 Bracketed 」' }], onInput: function (v) { form.style = v; persist(); } });
  var colorF = ui.field({ label: 'Colours', type: 'select', value: form.colors, options: [{ value: 'themed', label: 'Themed palette' }, { value: 'mono', label: 'Single hue' }, { value: 'rainbow', label: 'Rainbow' }], onInput: function (v) { form.colors = v; persist(); } });

  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'Server'), typeChips.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Theme'), themeChips.el),
    el('div', { class: 'form-section' }, el('h3', null, 'What to include'), catChips.el, countR.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Look'), el('div', { class: 'form-grid' }, styleF.el, colorF.el)),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate roles', { kind: 'primary', icon: 'sparkle', onclick: run })));

  var list = el('div', { class: 'results' });
  var code = el('pre', { class: 'out-box tall', tabindex: '0' });
  var tabs = ui.tabs({ label: 'View', value: tab, items: [{ id: 'list', label: 'Hierarchy' }, { id: 'text', label: 'Text' }, { id: 'json', label: 'JSON' }, { id: 'djs', label: 'discord.js' }], onChange: function (v) { tab = v; paint(); } });
  var head = el('div', { class: 'results-head' }, el('h2', null, 'Role hierarchy'),
    el('div', { class: 'row' },
      ui.btn('Copy', { icon: 'copy', sm: true, kind: 'primary', onclick: function () { CH.copy(tab === 'json' ? asJson(roles) : tab === 'djs' ? asCode(roles) : asText(roles)); } }),
      ui.btn('Save', { icon: 'save', sm: true, onclick: function () { var r = CH.Saved.add({ type: 'roles', title: THEMES[form.theme].label + ' roles (' + roles.length + ')', body: asText(roles), data: { roles: roles } }); CH.toast(r.dupe ? 'Already saved' : 'Saved to your library'); } }),
      ui.btn('Regenerate', { icon: 'refresh', sm: true, onclick: run })));
  var tip = ui.callout('info', el('strong', null, 'How hierarchy works: '), 'a role can only manage roles below it, so order matters. Drag them into place in Server Settings → Roles — top of this list goes at the top. A server can have up to 250 roles, and bot roles must sit above any role the bot assigns.');
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, el('div', { class: 'card card-pad stack' }, head, tabs.el, list, code, tip)));

  function card(r, i) {
    var cp = el('button', { type: 'button', class: 'act', 'aria-label': 'Copy role name' }, icon('copy'), el('span', null, 'Copy name'));
    cp.addEventListener('click', function () { CH.copy(r.display); });
    return el('article', { class: 'result role-card', style: { '--i': Math.min(i, 12) } },
      el('div', { class: 'role-swatch', style: { background: r.color || '#99aab5', color: r.color || '#99aab5' } }),
      el('div', { style: { flex: 1, minWidth: 0 } },
        el('div', { class: 'row-between' }, el('div', { class: 'role-name', style: { color: r.color || 'var(--text)' } }, r.display), el('span', { class: 'tag' }, (CATS.filter(function (c) { return c[0] === r.cat; })[0] || [0, r.cat])[1])),
        el('div', { class: 'result-meta', style: { marginTop: '4px', marginRight: 0 } }, r.color ? el('span', { class: 'mono' }, r.color) : el('span', null, 'default colour'), r.hoist ? el('span', null, '· shown separately') : null, r.mentionable ? el('span', null, '· mentionable') : null),
        r.perms.length ? el('div', { class: 'perm-chips' }, r.perms.map(function (p) { return el('span', { class: 'perm' + (DANGER.indexOf(p) >= 0 ? ' danger' : '') }, p); })) : null,
        el('p', { class: 'hint', style: { marginTop: '8px' } }, r.note),
        el('div', { class: 'result-foot', style: { marginTop: '6px' } }, el('div', { class: 'result-actions' }, cp))));
  }
  function paint() {
    list.hidden = tab !== 'list'; code.hidden = tab === 'list';
    if (tab === 'list') { CH.clear(list); roles.forEach(function (r, i) { list.appendChild(card(r, i)); }); }
    else code.textContent = tab === 'text' ? asText(roles) : tab === 'json' ? asJson(roles) : asCode(roles);
  }
  function run() { roles = build(form); paint(); }
  run();
});
