/* Channel Generator — category & channel layouts per server type, with topics and permission hints. */
CH.page('channels', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, chance = CH.chance;

  // C(key, type, minSize, topic, extras)  type: text | voice | forum | stage | news
  function C(n, t, s, topic, o) { return Object.assign({ n: n, t: t || 'text', s: s || 1, topic: topic || '' }, o || {}); }
  function cat(k, c) { return { k: k, c: c }; }
  var RO = { lock: 'read-only' }, STAFF = { lock: 'staff only' };

  var DATA = {
    gaming: [
      cat('General', [C('general', 'text', 1, 'Main hangout. Keep it friendly and on topic.', { alts: ['general', 'main-chat', 'lobby-chat'] }), C('memes', 'text', 2, 'Memes and clips. Keep it safe for work.', { alts: ['memes', 'meme-stash'] }), C('clips-and-screenshots', 'text', 2, 'Your best plays and funniest fails.'), C('off-topic', 'text', 2, 'Everything that isn’t gaming.')]),
      cat('Play together', [C('looking-for-group', 'text', 1, 'Find teammates. Say the game, mode and your rank.', { alts: ['looking-for-group', 'lfg', 'squad-up'] }), C('ranked-queue', 'text', 3, 'Serious players looking for ranked teammates.'), C('casual-games', 'text', 2, 'Relaxed games, no pressure.'), C('game-news', 'news', 3, 'Patch notes, updates and announcements.', RO)]),
      cat('Game hubs', [C('main-game', 'text', 3, 'Strategy, tips and discussion for our main game.'), C('side-games', 'text', 3, 'Everything else we play.'), C('guides', 'forum', 3, 'Share and request guides. One post per topic.')]),
      cat('Events', [C('events', 'text', 2, 'Game nights, tournaments and community events.', { alts: ['events', 'game-nights'] }), C('tournaments', 'text', 3, 'Brackets, sign-ups and results.'), C('scrim-voice', 'voice', 3, '')]),
      cat('Voice', [C('Lobby 1', 'voice', 1), C('Lobby 2', 'voice', 2), C('Squad 1', 'voice', 3), C('Squad 2', 'voice', 3), C('Chill Room', 'voice', 2), C('AFK', 'voice', 2, '', { lock: 'idle channel' })]),
      cat('Bots', [C('bot-commands', 'text', 1, 'Use bot commands here to keep other channels clean.', { alts: ['bot-commands', 'bots'] })])
    ],
    community: [
      cat('General', [C('general', 'text', 1, 'The main hangout. Be kind, stay on topic.', { alts: ['general', 'main-chat', 'lounge'] }), C('off-topic', 'text', 2, 'Anything goes (within the rules).'), C('media', 'text', 2, 'Photos, videos and links worth sharing.'), C('memes', 'text', 2, 'Memes, jokes and shenanigans.')]),
      cat('Interests', [C('gaming', 'text', 2, 'What are you playing?'), C('music', 'text', 2, 'Share what you’re listening to.'), C('art-and-creative', 'text', 2, 'Showcase your creative work.'), C('pets', 'text', 3, 'Pet photos are mandatory.'), C('food', 'text', 3, 'Recipes, restaurants and snack opinions.', { o: true })]),
      cat('Community', [C('events', 'text', 2, 'Upcoming events and hangouts.', { alts: ['events', 'community-events'] }), C('polls', 'text', 2, 'Vote on things that matter (and things that don’t).'), C('suggestions', 'forum', 1, 'Share ideas to improve the server. One idea per post.', { alts: ['suggestions', 'ideas'] })]),
      cat('Voice', [C('Lounge', 'voice', 1), C('Hangout 1', 'voice', 2), C('Hangout 2', 'voice', 3), C('Community Stage', 'stage', 3), C('AFK', 'voice', 2, '', { lock: 'idle channel' })]),
      cat('Bots', [C('bot-commands', 'text', 1, 'Bot commands live here.'), C('counting', 'text', 3, 'Count together, one number at a time.', { o: true })])
    ],
    friends: [
      cat('Chat', [C('general', 'text', 1, 'Day-to-day chatter.', { alts: ['general', 'the-group-chat', 'hangout'] }), C('banter', 'text', 1, 'Inside jokes and bad takes.'), C('pics-and-memes', 'text', 2, 'Photos, memes and general chaos.'), C('plans', 'text', 2, 'Who’s free? Trips, meetups, movie nights.'), C('venting', 'text', 3, 'A safe place to let it out. Be kind.', { o: true })]),
      cat('Play', [C('gaming', 'text', 2, 'What are we playing tonight?'), C('looking-for-group', 'text', 2, 'Round up the squad.')]),
      cat('Voice', [C('Hangout', 'voice', 1), C('Movie Night', 'voice', 2), C('Gaming 1', 'voice', 3), C('Gaming 2', 'voice', 3), C('AFK', 'voice', 2, '', { lock: 'idle channel' })]),
      cat('Misc', [C('bot-commands', 'text', 2, 'Bots go here.'), C('music-requests', 'text', 3, 'Queue up the vibes.', { o: true })])
    ],
    anime: [
      cat('Anime & manga', [C('anime-chat', 'text', 1, 'Discuss what you’re watching. Tag spoilers!'), C('manga-chat', 'text', 1, 'Chapters, volumes and scanlation-free discussion.'), C('recommendations', 'forum', 2, 'Ask for or share recs. Include genres and what you’ve already seen.'), C('spoilers', 'text', 2, 'Spoilers allowed here — and only here.', { alts: ['spoilers', 'spoiler-zone'] }), C('seasonal-anime', 'text', 3, 'Airing this season: weekly episode threads.')]),
      cat('Creative', [C('fanart', 'text', 2, 'Show off your art. Credit original artists when reposting.'), C('amv-and-edits', 'text', 3, 'Edits, AMVs and clips.'), C('cosplay', 'text', 3, 'Costumes and works in progress.', { o: true }), C('memes', 'text', 2, 'Weeb humor. Keep it safe for work.')]),
      cat('Community', [C('general', 'text', 1, 'General chat.', { alts: ['general', 'main-chat'] }), C('events', 'text', 2, 'Watch parties, quizzes and tournaments.'), C('polls', 'text', 3, 'Tier lists, rankings and arguments.'), C('off-topic', 'text', 2, 'Non-anime chat.')]),
      cat('Voice', [C('Lounge', 'voice', 1), C('Watch Party', 'voice', 2), C('Karaoke', 'voice', 3), C('AFK', 'voice', 2, '', { lock: 'idle channel' })]),
      cat('Bots', [C('bot-commands', 'text', 1, 'Gacha, quizzes and bot spam go here.')])
    ],
    creator: [
      cat('Creator', [C('new-uploads', 'news', 1, 'New videos, streams and posts as they drop.', RO), C('social-links', 'text', 1, 'Where to find me everywhere else.', RO), C('behind-the-scenes', 'text', 3, 'Works in progress and sneak peeks.')]),
      cat('Community', [C('general', 'text', 1, 'Chat with the community.', { alts: ['general', 'community-chat'] }), C('chat-with-the-creator', 'text', 2, 'Questions and conversation with the team.'), C('fan-content', 'text', 2, 'Fan art, edits and clips. Credit your sources.'), C('memes', 'text', 2, 'Community memes.'), C('clips', 'text', 3, 'Best moments from streams.')]),
      cat('Showcase', [C('self-promo', 'text', 1, 'Share your own work here — and only here.', { alts: ['self-promo', 'showcase'] }), C('feedback', 'forum', 2, 'Post work for constructive feedback. Give some, get some.'), C('collabs', 'text', 3, 'Find collaborators and projects.')]),
      cat('Live & events', [C('live-chat', 'text', 2, 'Chat during live streams.'), C('q-and-a', 'text', 2, 'Ask your questions for the next Q&A.'), C('giveaways', 'text', 2, 'Giveaways and contests.'), C('Live Stage', 'stage', 2), C('Hangout', 'voice', 1)]),
      cat('Supporters', [C('supporters-chat', 'text', 3, 'For paid members and subscribers.', { lock: 'role-gated' }), C('early-access', 'text', 3, 'First look at new content.', { lock: 'role-gated' })])
    ],
    education: [
      cat('Info', [C('resources', 'text', 1, 'Pinned links, notes and reading lists.', RO), C('schedule', 'text', 2, 'Class times, deadlines and events.', RO)]),
      cat('Study', [C('general-study', 'text', 1, 'Talk through whatever you’re studying.', { alts: ['general-study', 'study-chat'] }), C('homework-help', 'forum', 1, 'One question per post. Show what you’ve tried.'), C('study-resources', 'text', 2, 'Share notes, cheat sheets and tools.'), C('accountability', 'text', 3, 'Set goals and check in daily.', { o: true })]),
      cat('Subjects', [C('math', 'text', 2, 'Algebra to analysis.'), C('science', 'text', 2, 'Physics, chemistry and biology.'), C('programming', 'text', 2, 'Code questions, projects and debugging.'), C('languages', 'text', 3, 'Practice and ask about languages.'), C('writing', 'text', 3, 'Essays, feedback and structure.')]),
      cat('Voice', [C('Study Room 1', 'voice', 1), C('Study Room 2', 'voice', 2), C('Focus Room', 'voice', 3, '', { lock: 'quiet — mic off' }), C('Office Hours', 'stage', 3)]),
      cat('Off topic', [C('off-topic', 'text', 2, 'Take a break from studying.'), C('wins', 'text', 2, 'Passed an exam? Finished a project? Celebrate here.')])
    ],
    support: [
      cat('Info', [C('faq', 'text', 1, 'Answers to the most common questions.', RO), C('status', 'news', 2, 'Service status and known issues.', RO)]),
      cat('Get help', [C('open-a-ticket', 'text', 1, 'Click the button to open a private ticket.', RO), C('help', 'forum', 1, 'Describe your problem, what you tried and any errors. One post per issue.', { alts: ['help', 'support-forum'] }), C('common-issues', 'text', 2, 'Quick fixes for common problems.', RO), C('bug-reports', 'forum', 2, 'Report bugs with steps to reproduce.'), C('feature-requests', 'forum', 2, 'Suggest improvements and vote on ideas.')]),
      cat('Community', [C('general-chat', 'text', 1, 'Chat with other members.', { alts: ['general-chat', 'community'] }), C('show-and-tell', 'text', 3, 'Show what you built or fixed.')]),
      cat('Voice', [C('Help Desk', 'voice', 2, '', { lock: 'staff may move you' }), C('Community Voice', 'voice', 3)])
    ],
    professional: [
      cat('Info', [C('resources', 'text', 1, 'Curated tools, templates and learning material.', RO)]),
      cat('Network', [C('general', 'text', 1, 'Professional conversation.', { alts: ['general', 'lounge'] }), C('job-board', 'text', 2, 'Openings and opportunities. Use the template.'), C('freelance-requests', 'text', 2, 'Looking for talent, or offering services.'), C('collabs', 'text', 3, 'Find partners for projects.')]),
      cat('Topics', [C('industry-news', 'text', 2, 'What’s moving in the industry.'), C('tools-and-tips', 'text', 2, 'Workflows, software and shortcuts.'), C('portfolio-feedback', 'forum', 3, 'Share work for constructive critique.')]),
      cat('Voice', [C('Coworking', 'voice', 1), C('Meeting Room', 'voice', 2), C('Town Hall', 'stage', 3)])
    ],
    marketplace: [
      cat('Info', [C('how-to-trade', 'text', 1, 'Read this before your first trade.', RO), C('trusted-sellers', 'text', 2, 'Vetted sellers with proven track records.', RO)]),
      cat('Trading', [C('selling', 'text', 1, 'Post one listing per item using the template.'), C('buying', 'text', 1, 'Looking to buy? Post what you need and your budget.'), C('services', 'text', 2, 'Commissions and services.'), C('price-checks', 'text', 2, 'Ask what something’s worth.'), C('swaps', 'text', 3, 'Item-for-item trades.')]),
      cat('Safety', [C('vouches', 'text', 1, 'Vouch for people you’ve traded with successfully.'), C('middleman-requests', 'text', 2, 'Request a middleman for high-value trades.'), C('scam-reports', 'text', 2, 'Report scams with evidence — staff only reply.')]),
      cat('Community', [C('general', 'text', 1, 'Chat that isn’t about a trade.', { alts: ['general', 'lounge'] }), C('off-topic', 'text', 2, 'Everything else.'), C('Lounge', 'voice', 2)]),
      cat('Tickets', [C('open-a-ticket', 'text', 1, 'Open a ticket for disputes or questions.', RO)])
    ],
    other: null
  };
  var CORE = [
    function (name) { return cat('Start here', [C('welcome', 'text', 1, 'Welcome to ' + name + '! Start here to get oriented.', RO), C('rules', 'text', 1, 'Server rules — read these before posting.', RO), C('announcements', 'news', 1, 'Official news. Follow this channel to get updates in your own server.', RO), C('roles', 'text', 2, 'Pick your roles and notification preferences.', RO), C('introductions', 'text', 2, 'Say hi and tell us what brings you here.')]); }
  ];
  var STAFF_CAT = cat('Staff', [C('staff-chat', 'text', 1, 'Private staff discussion.', STAFF), C('mod-log', 'text', 1, 'Automated moderation logs.', STAFF), C('reports', 'text', 2, 'Member reports waiting for review.', STAFF), C('staff-announcements', 'text', 3, 'Internal notices and shift changes.', STAFF), C('bot-testing', 'text', 3, 'Test bot commands and embeds safely.', STAFF), C('Staff Voice', 'voice', 2, '', STAFF)]);
  var EMOJI = { welcome: '👋', rules: '📜', announcements: '📢', roles: '🎭', introductions: '🙋', general: '💬', 'main-chat': '💬', lounge: '🛋️', memes: '😂', 'meme-stash': '😂', 'off-topic': '🎲', media: '📸', events: '🎉', polls: '📊', suggestions: '💡', ideas: '💡', 'bot-commands': '🤖', bots: '🤖', 'staff-chat': '🛡️', 'mod-log': '🧾', reports: '🚨', faq: '❓', help: '🛟', 'open-a-ticket': '🎫', 'looking-for-group': '🎮', lfg: '🎮', 'squad-up': '🎮', 'new-uploads': '🎬', 'social-links': '🔗', 'self-promo': '📣', feedback: '📝', giveaways: '🎁', resources: '📚', schedule: '🗓️', selling: '🏷️', buying: '🛒', vouches: '✅', 'scam-reports': '⚠️', 'job-board': '💼', fanart: '🎨', 'anime-chat': '🌸', 'manga-chat': '📖', spoilers: '🙈', status: '🟢', counting: '🔢' };
  var TYPE_EMOJI = { text: '💬', voice: '🔊', forum: '🗂️', stage: '🎤', news: '📢' };
  var TYPE_GLYPH = { text: '#', voice: '🔊', forum: '▤', stage: '🎙', news: '📣' };
  var TYPES = [['gaming', 'Gaming'], ['community', 'Community'], ['friends', 'Friends'], ['anime', 'Anime'], ['creator', 'Creator'], ['education', 'Education'], ['support', 'Support'], ['professional', 'Professional'], ['marketplace', 'Marketplace'], ['other', 'Other']];
  var SIZES = { 1: 'Starter (~10)', 2: 'Standard (~20)', 3: 'Large (~30)' };

  function chName(c, style) {
    var base = c.name;
    if (c.t === 'voice' || c.t === 'stage') {
      var vn = base.replace(/-/g, ' ').replace(/\b\w/g, function (m) { return m.toUpperCase(); });
      return style === 'emoji' ? '🔊 ' + vn : style === 'dot' ? '・' + vn : style === 'bar' ? '〢' + vn : style === 'arrow' ? '» ' + vn : vn;
    }
    var slug = base.toLowerCase().replace(/[^a-z0-9À-￿-]+/g, '-').replace(/^-+|-+$/g, '');
    var e = EMOJI[slug] || TYPE_EMOJI[c.t];
    return style === 'emoji' ? e + '┃' + slug : style === 'dot' ? '・' + slug : style === 'bar' ? '〢' + slug : style === 'arrow' ? '»' + slug : slug;
  }
  function catName(k, style) {
    var up = k.toUpperCase();
    return style === 'caps' ? up : style === 'title' ? k.replace(/\b\w/g, function (m) { return m.toUpperCase(); }) : style === 'deco' ? '━━ ' + up + ' ━━' : '📁 ' + up;
  }

  function build(f) {
    var name = f.name.trim() || 'the server', base = (DATA[f.type] || DATA.community).slice();
    var cats = CORE.map(function (fn) { return fn(name); }).concat(base);
    if (f.staff) cats.push(STAFF_CAT);
    var out = [];
    cats.forEach(function (ca) {
      var chans = ca.c.filter(function (c) {
        if (c.s > f.size) return false;
        if (c.o && !chance(.6)) return false;
        if (!f.voice && (c.t === 'voice' || c.t === 'stage')) return false;
        if (!f.stage && c.t === 'stage') return false;
        return true;
      }).map(function (c) {
        var t = c.t; if (!f.forum && t === 'forum') t = 'text';
        var raw = c.alts ? pick(c.alts) : c.n;
        return { name: raw, t: t, topic: c.topic, lock: c.lock || '', raw: raw };
      });
      if (chans.length) out.push({ name: ca.k, chans: chans });
    });
    // voice-only categories vanish if voice is off; apply style
    out.forEach(function (ca) { ca.display = catName(ca.name, f.catStyle); ca.chans.forEach(function (c) { c.display = chName(c, f.style); }); });
    return out;
  }
  function count(o) { return o.reduce(function (a, c) { return a + c.chans.length; }, 0); }

  function asText(o, topics) { return o.map(function (ca) { return ca.display + '\n' + ca.chans.map(function (c) { return '  ' + (c.t === 'voice' || c.t === 'stage' ? TYPE_GLYPH[c.t] + ' ' : c.t === 'forum' ? '▤ ' : c.t === 'news' ? '📣 ' : '# ') + c.display + (c.lock ? '  [' + c.lock + ']' : '') + (topics && c.topic ? '\n      ' + c.topic : ''); }).join('\n'); }).join('\n\n'); }
  function asJson(o) { return JSON.stringify(o.map(function (ca) { return { category: ca.display, channels: ca.chans.map(function (c) { var x = { name: c.display, type: { text: 'GUILD_TEXT', voice: 'GUILD_VOICE', forum: 'GUILD_FORUM', stage: 'GUILD_STAGE_VOICE', news: 'GUILD_ANNOUNCEMENT' }[c.t] }; if (c.topic && c.t !== 'voice' && c.t !== 'stage') x.topic = c.topic; if (c.lock) x.permissions_hint = c.lock; return x; }) }; }), null, 2); }

  /* ---------------- UI ---------------- */
  var form = Object.assign({ type: 'community', name: '', size: 2, style: 'emoji', catStyle: 'caps', voice: true, stage: true, forum: true, staff: true, topics: true }, CH.Store.get('form:channels', {}));
  function persist() { CH.Store.set('form:channels', form); }
  var layout = [], tab = 'tree';

  root.appendChild(ui.pageHead({ icon: 'hash', title: 'Channel Generator', desc: 'Get a ready-to-build category and channel layout for your server type, with topics and permission hints.' }));

  var typeChips = ui.chips({ label: 'Server type', sm: true, value: form.type, options: TYPES.map(function (t) { return { value: t[0], label: t[1] }; }), onChange: function (v) { form.type = v; persist(); } });
  var nameF = ui.field({ label: 'Server name', value: form.name, placeholder: 'Nebula Lounge', onInput: function (v) { form.name = v; persist(); } });
  var sizeSeg = ui.seg({ label: 'Size', value: String(form.size), options: [{ value: '1', label: SIZES[1] }, { value: '2', label: SIZES[2] }, { value: '3', label: SIZES[3] }], onChange: function (v) { form.size = +v; persist(); } });
  var styleF = ui.field({ label: 'Channel naming', type: 'select', value: form.style, options: [{ value: 'plain', label: 'plain-names' }, { value: 'emoji', label: '💬┃emoji-bar' }, { value: 'dot', label: '・dot-prefix' }, { value: 'bar', label: '〢fancy-bar' }, { value: 'arrow', label: '»arrow-prefix' }], onInput: function (v) { form.style = v; persist(); if (layout.length) { restyle(); } } });
  var catF = ui.field({ label: 'Category style', type: 'select', value: form.catStyle, options: [{ value: 'caps', label: 'UPPERCASE' }, { value: 'title', label: 'Title Case' }, { value: 'deco', label: '━━ DECORATED ━━' }, { value: 'emoji', label: '📁 EMOJI' }], onInput: function (v) { form.catStyle = v; persist(); if (layout.length) restyle(); } });
  function sw(key, label) { return ui.switch({ label: label, checked: form[key], onChange: function (v) { form[key] = v; persist(); } }); }
  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'Server'), typeChips.el, nameF.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Size'), sizeSeg.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Naming'), el('div', { class: 'form-grid' }, styleF.el, catF.el)),
    el('div', { class: 'form-section' }, el('h3', null, 'Include'), el('div', { class: 'stack-sm' }, sw('voice', 'Voice channels').el, sw('stage', 'Stage channels').el, sw('forum', 'Forum channels').el, sw('staff', 'Private staff area').el, sw('topics', 'Channel topics').el)),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate layout', { kind: 'primary', icon: 'sparkle', onclick: run })));

  var treeBox = el('div', { class: 'tree', role: 'tree', 'aria-label': 'Channel layout' });
  var code = el('pre', { class: 'out-box tall', tabindex: '0' });
  var guide = el('div', { class: 'prose' });
  var stats = el('div', { class: 'hint', 'aria-live': 'polite' });
  var tabs = ui.tabs({ label: 'View', value: tab, items: [{ id: 'tree', label: 'Layout' }, { id: 'text', label: 'Text outline' }, { id: 'json', label: 'JSON' }, { id: 'setup', label: 'Setup guide' }], onChange: function (v) { tab = v; paint(); } });
  var head = el('div', { class: 'results-head' }, el('h2', null, 'Your layout'), el('div', { class: 'row' },
    ui.btn('Copy', { icon: 'copy', sm: true, kind: 'primary', onclick: function () { CH.copy(tab === 'json' ? asJson(layout) : asText(layout, form.topics)); } }),
    ui.btn('Save', { icon: 'save', sm: true, onclick: function () { var r = CH.Saved.add({ type: 'channels', title: TYPES.filter(function (t) { return t[0] === form.type; })[0][1] + ' layout (' + count(layout) + ' channels)', body: asText(layout, form.topics), data: { layout: layout } }); CH.toast(r.dupe ? 'Already saved' : 'Saved to your library'); } }),
    ui.btn('Regenerate', { icon: 'refresh', sm: true, onclick: run })));
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, el('div', { class: 'card card-pad stack' }, head, tabs.el, stats, treeBox, code, guide)));

  function restyle() { layout.forEach(function (ca) { ca.display = catName(ca.name, form.catStyle); ca.chans.forEach(function (c) { c.display = chName(c, form.style); }); }); paint(); }
  function paint() {
    treeBox.hidden = tab !== 'tree'; code.hidden = tab !== 'text' && tab !== 'json'; guide.hidden = tab !== 'setup';
    var n = count(layout); stats.textContent = layout.length + ' categories · ' + n + ' channels' + (n > 450 ? ' (Discord’s limit is 500)' : '') + ' — Discord allows up to 50 channels per category.';
    if (tab === 'tree') {
      CH.clear(treeBox);
      layout.forEach(function (ca) {
        treeBox.appendChild(el('div', { class: 'tree-cat', role: 'treeitem' }, icon('chevronDown'), ca.display));
        ca.chans.forEach(function (c) {
          treeBox.appendChild(el('div', { class: 'tree-ch', role: 'treeitem' }, el('span', { class: 'ty', title: c.t }, TYPE_GLYPH[c.t]), el('span', null, c.display),
            c.lock ? el('span', { class: 'lock' }, '🔒 ' + c.lock) : null,
            form.topics && c.topic && c.t !== 'voice' && c.t !== 'stage' ? el('span', { class: 'tp' }, '— ' + c.topic) : null));
        });
      });
    } else if (tab === 'text') code.textContent = asText(layout, form.topics);
    else if (tab === 'json') code.textContent = asJson(layout);
    else {
      CH.clear(guide);
      guide.appendChild(el('h3', null, 'Setting it up in Discord'));
      var steps = [
        ['Create the categories first.', 'Server Settings → right-click the channel list → Create Category. Then add channels inside each.'],
        ['Lock the read-only channels.', 'For channels marked read-only (rules, announcements, roles): deny “Send Messages” for @everyone and allow it for staff.'],
        ['Hide the staff area.', 'On the Staff category, turn off “View Channel” for @everyone and allow it for your staff roles. Channels inside inherit this.'],
        ['Turn on Community features (optional).', 'Server Settings → Enable Community. It asks for a rules channel and an updates channel, and unlocks announcement channels, forums, stages and Onboarding.'],
        ['Make announcements followable.', 'Announcement (news) channels can be followed by other servers, so people can get your updates in their own servers.'],
        ['Add safety nets.', 'Enable AutoMod and a verification level in Server Settings, and give new members a sensible default role.']
      ];
      guide.appendChild(el('ol', null, steps.map(function (s) { return el('li', null, el('strong', null, s[0] + ' '), s[1]); })));
      guide.appendChild(el('p', { class: 'hint' }, 'Limits: channel names up to 100 characters, text channel topics up to 1,024 characters, 500 channels per server, 50 per category. Discord lower-cases text channel names and swaps spaces for hyphens; emoji and symbols are allowed. Voice channel names keep capitals and spaces.'));
    }
  }
  function run() { layout = build(form); paint(); }
  run();
});
